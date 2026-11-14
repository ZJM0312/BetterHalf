import MultipeerConnectivity
import Observation
import UIKit

/// Peer-to-peer sync between the two partners' phones over Wi-Fi / Bluetooth (MultipeerConnectivity).
/// Data is end-to-end encrypted by the session and never touches a server.
@Observable
final class SyncService: NSObject {
    static let serviceType = "betterhalf"
    private static let secretKey = "pairSecret"

    enum Phase: Equatable {
        case idle, searching, connecting(String), connected(String), failed(String)
    }

    struct Invite: Identifiable {
        let id = UUID()
        let peerName: String
        let respond: (Bool) -> Void
    }

    private(set) var phase: Phase = .idle
    private(set) var peers: [MCPeerID] = []
    var pendingInvite: Invite?
    private(set) var lastSyncedAt: Date?
    private(set) var filesReceived = 0
    private(set) var filesExpected = 0
    /// Bumped when the partner sends a "想你了"; the UI animates on change.
    private(set) var nudgeCount = 0
    private(set) var nudgeFrom = ""

    @ObservationIgnored weak var store: SpaceStore?
    @ObservationIgnored private var myPeer: MCPeerID?
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?

    private var secret: String? {
        get { UserDefaults.standard.string(forKey: Self.secretKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.secretKey) }
    }
    var isPaired: Bool { secret != nil }

    // MARK: control

    func start(displayName: String) {
        stop()
        let peer = MCPeerID(displayName: String("\(displayName) 的 iPhone".prefix(60)))
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        let adv = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: ["v": "1"], serviceType: Self.serviceType)
        adv.delegate = self
        let br = MCNearbyServiceBrowser(peer: peer, serviceType: Self.serviceType)
        br.delegate = self
        myPeer = peer
        self.session = session
        advertiser = adv
        browser = br
        adv.startAdvertisingPeer()
        br.startBrowsingForPeers()
        phase = .searching
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        peers = []
        phase = .idle
    }

    func connect(to peer: MCPeerID) {
        guard let browser, let session else { return }
        phase = .connecting(peer.displayName)
        browser.invitePeer(peer, to: session, withContext: secret?.data(using: .utf8), timeout: 30)
    }

    func syncAgain() {
        guard let session, let peer = session.connectedPeers.first else { return }
        sendHello(to: peer)
    }

    func sendNudge() {
        guard let session, !session.connectedPeers.isEmpty else { return }
        send(.nudge(from: store?.state?.me ?? "TA"), to: session.connectedPeers)
    }

    func forgetPairing() { secret = nil }

    // MARK: protocol

    private enum Message: Codable {
        case hello(state: SpaceState?, secret: String)
        case request(files: [String])
        case nudge(from: String)
    }

    private func send(_ msg: Message, to peers: [MCPeerID]) {
        guard let session, let data = try? JSONEncoder().encode(msg) else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }

    /// Safe from any thread: reads the store on the main queue, then sends.
    private func sendHello(to peer: MCPeerID) {
        DispatchQueue.main.async {
            if self.secret == nil { self.secret = UUID().uuidString }
            self.send(.hello(state: self.store?.state, secret: self.secret!), to: [peer])
        }
    }

    private func handle(_ msg: Message, from peer: MCPeerID) {
        switch msg {
        case let .hello(state, theirSecret):
            if secret == nil { secret = theirSecret }
            guard let state else {
                // A fresh phone joined and only received our data.
                DispatchQueue.main.async { self.lastSyncedAt = Date() }
                return
            }
            let missing = state.referencedFiles.filter { !SharedContainer.hasMedia($0) }
            DispatchQueue.main.async {
                self.store?.mergeFromPartner(state)
                self.lastSyncedAt = Date()
                self.filesExpected = missing.count
                self.filesReceived = 0
            }
            if !missing.isEmpty { send(.request(files: missing), to: [peer]) }
        case let .request(files):
            guard let session else { return }
            for name in files where !name.contains("/") && SharedContainer.hasMedia(name) {
                session.sendResource(at: SharedContainer.mediaURL(name), withName: name, toPeer: peer, withCompletionHandler: nil)
            }
        case let .nudge(from):
            DispatchQueue.main.async {
                self.nudgeFrom = from
                self.nudgeCount += 1
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

extension SyncService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected: self.phase = .connected(peerID.displayName)
            case .connecting: self.phase = .connecting(peerID.displayName)
            case .notConnected:
                if case .connected = self.phase { self.phase = .searching }
                else if case .connecting = self.phase { self.phase = .failed("没有连上 \(peerID.displayName)，请让 TA 也打开同步页面后重试") }
            @unknown default: break
            }
        }
        if state == .connected { sendHello(to: peerID) }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let msg = try? JSONDecoder().decode(Message.self, from: data) else { return }
        handle(msg, from: peerID)
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID,
                 at localURL: URL?, withError error: Error?) {
        guard error == nil, let localURL, !resourceName.contains("/") else { return }
        let dst = SharedContainer.mediaURL(resourceName)
        try? FileManager.default.removeItem(at: dst)
        try? FileManager.default.moveItem(at: localURL, to: dst)
        DispatchQueue.main.async {
            self.filesReceived += 1
            self.store?.reloadFromDisk()
        }
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
}

extension SyncService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Already-paired partner: accept silently. Anyone else: ask the user first.
        if let secret, let ctx = context, String(data: ctx, encoding: .utf8) == secret {
            invitationHandler(true, session)
            return
        }
        DispatchQueue.main.async {
            self.pendingInvite = Invite(peerName: peerID.displayName) { [weak self] accept in
                invitationHandler(accept, accept ? self?.session : nil)
                if accept { self?.phase = .connecting(peerID.displayName) }
            }
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { self.phase = .failed("无法开启附近发现：\(error.localizedDescription)") }
    }
}

extension SyncService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { if !self.peers.contains(peerID) { self.peers.append(peerID) } }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { self.peers.removeAll { $0 == peerID } }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { self.phase = .failed("无法搜索附近设备：\(error.localizedDescription)") }
    }
}
