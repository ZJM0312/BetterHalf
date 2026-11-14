import CloudKit
import Observation
import UIKit

/// Long-distance sync through the couple's own iCloud: one person creates a private shared zone and
/// invites the other. Each phone writes only its own snapshot record (so writes never conflict) and
/// merges the partner's snapshot with the same rules as nearby sync. Silent pushes from a CloudKit
/// subscription wake the app when the partner changes something, so it can notify right away.
///
/// Only in-app data is uploaded (see `PrivacyGuard`): this phone's `SpaceState` and the media files it references.
///
/// Needs the paid developer program (iCloud + push). Builds with `BH_CLOUDKIT = NO` compile this
/// but never touch CloudKit; the UI explains instead.
@MainActor
@Observable
final class CloudSync {
    static var isEnabled: Bool { Bundle.main.object(forInfoDictionaryKey: "BHCloudKit") as? String == "YES" }
    static let containerID = "iCloud.com.betterhalf.hxiz1q"
    private static let zoneName = "BetterHalf"
    private(set) static weak var shared: CloudSync?

    enum Role: String { case owner, participant }
    enum Status: Equatable {
        case disabled          // this build has no iCloud entitlement
        case noAccount         // not signed in to iCloud
        case notPaired
        case waitingForPartner // owner: share created, partner hasn't accepted yet
        case paired
    }

    private(set) var status: Status = .disabled
    private(set) var busy = false
    private(set) var lastSyncedAt: Date?
    var lastError: String?

    @ObservationIgnored weak var store: SpaceStore?
    @ObservationIgnored private var pushTask: Task<Void, Never>?
    @ObservationIgnored private var lastPushed: Data?
    @ObservationIgnored private var myRecordName: String?
    @ObservationIgnored private lazy var container = CKContainer(identifier: Self.containerID)

    private let defaults = UserDefaults.standard
    private var role: Role? {
        get { defaults.string(forKey: "cloud.role").flatMap(Role.init) }
        set { defaults.set(newValue?.rawValue, forKey: "cloud.role") }
    }
    private var zoneOwner: String? {
        get { defaults.string(forKey: "cloud.zoneOwner") }
        set { defaults.set(newValue, forKey: "cloud.zoneOwner") }
    }
    private var uploaded: Set<String> {
        get { Set(defaults.stringArray(forKey: "cloud.uploaded") ?? []) }
        set { defaults.set(Array(newValue), forKey: "cloud.uploaded") }
    }
    private var changeToken: CKServerChangeToken? {
        get {
            defaults.data(forKey: "cloud.token").flatMap {
                try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0)
            }
        }
        set {
            defaults.set(newValue.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) },
                         forKey: "cloud.token")
        }
    }

    var isPaired: Bool { status == .paired }
    var isActive: Bool { status == .paired || status == .waitingForPartner }

    init() { Self.shared = self }

    private var database: CKDatabase { role == .participant ? container.sharedCloudDatabase : container.privateCloudDatabase }
    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: role == .participant ? (zoneOwner ?? CKCurrentUserDefaultName) : CKCurrentUserDefaultName)
    }

    // MARK: lifecycle

    func start() {
        guard Self.isEnabled else { status = .disabled; return }
        Task { await refresh() }
    }

    /// Re-check account + pairing and pull changes. Called on launch, on foreground and periodically.
    func refresh() async {
        guard Self.isEnabled else { return }
        do {
            guard try await container.accountStatus() == .available else { status = .noAccount; return }
            if myRecordName == nil { myRecordName = try await container.userRecordID().recordName }
            guard let role else { status = .notPaired; return }
            if role == .owner { status = try await partnerHasJoined() ? .paired : .waitingForPartner }
            else { status = .paired }
            await ensureSubscription()
            await fetch()
            schedulePush(delay: 0)
        } catch {
            report(error)
        }
    }

    // MARK: pairing

    /// Owner side: create the zone + zone-wide share. The returned share is handed to the system sharing sheet.
    func prepareShare() async throws -> CKShare {
        guard let s = store?.state else { throw CKError(.internalError) }
        role = .owner
        let zone = CKRecordZone(zoneName: Self.zoneName)
        _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [zone], deleting: [])
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone.zoneID)
        if let existing = try? await container.privateCloudDatabase.record(for: shareID) as? CKShare {
            status = .waitingForPartner
            return existing
        }
        let share = CKShare(recordZoneID: zone.zoneID)
        share[CKShare.SystemFieldKey.title] = "\(s.me) 和 \(s.partner) 的 BetterHalf" as CKRecordValue
        share.publicPermission = .none
        _ = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
        status = .waitingForPartner
        lastPushed = nil
        await ensureSubscription()
        schedulePush(delay: 0)
        return share
    }

    var cloudContainer: CKContainer { container }

    /// Participant side: the partner's invite link was opened.
    func accept(_ metadata: CKShare.Metadata) async {
        guard Self.isEnabled else { return }
        do {
            _ = try await container.accept(metadata)
            role = .participant
            zoneOwner = metadata.share.recordID.zoneID.ownerName
            changeToken = nil
            uploaded = []
            lastPushed = nil
            status = .paired
            await ensureSubscription(force: true)
            await fetch()
            schedulePush(delay: 0)
        } catch {
            report(error)
        }
    }

    /// Stop syncing. The owner deletes the shared zone (removing the cloud copy for both);
    /// the participant just leaves. Data on both phones stays.
    func stopSharing() async {
        guard role != nil else { return }
        do {
            _ = try await database.modifyRecordZones(saving: [], deleting: [zoneID])
        } catch {
            report(error)
        }
        self.role = nil
        zoneOwner = nil
        changeToken = nil
        uploaded = []
        defaults.removeObject(forKey: "cloud.subscribed")
        status = .notPaired
    }

    private func partnerHasJoined() async throws -> Bool {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        guard let share = try? await database.record(for: shareID) as? CKShare else {
            role = nil // share was deleted elsewhere
            throw CKError(.zoneNotFound)
        }
        return share.participants.contains { $0.role != .owner && $0.acceptanceStatus == .accepted }
    }

    private func ensureSubscription(force: Bool = false) async {
        let key = "cloud.subscribed"
        guard force || defaults.string(forKey: key) != role?.rawValue else { return }
        let sub = CKDatabaseSubscription(subscriptionID: "bh-\(role?.rawValue ?? "x")")
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true // silent: the app fetches, then posts a specific notification
        sub.notificationInfo = info
        do {
            _ = try await database.save(sub)
            defaults.set(role?.rawValue, forKey: key)
        } catch {
            report(error)
        }
    }

    // MARK: upload

    /// Debounced upload of this phone's snapshot + any new media.
    func schedulePush(delay: Double = 2) {
        guard Self.isEnabled, role != nil else { return }
        pushTask?.cancel()
        pushTask = Task {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled else { return }
            await push()
        }
    }

    private func push() async {
        guard let state = store?.state, let me = myRecordName, let payload = try? JSONEncoder().encode(state) else { return }
        do {
            if payload != lastPushed {
                let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-\(UUID().uuidString).json")
                try payload.write(to: tmp)
                defer { try? FileManager.default.removeItem(at: tmp) }
                let rec = CKRecord(recordType: "Snapshot", recordID: CKRecord.ID(recordName: "snap-\(me)", zoneID: zoneID))
                rec["payload"] = CKAsset(fileURL: tmp)
                rec["author"] = state.me as CKRecordValue
                _ = try await database.modifyRecords(saving: [rec], deleting: [], savePolicy: .allKeys)
                lastPushed = payload
            }
            try await uploadMedia(state.referencedFiles)
            lastSyncedAt = Date()
            lastError = nil
        } catch {
            report(error)
        }
    }

    private func uploadMedia(_ files: [String]) async throws {
        var done = uploaded
        let todo = files.filter { PrivacyGuard.isSafeMediaName($0) && !done.contains($0) && SharedContainer.hasMedia($0) }
        for batch in stride(from: 0, to: todo.count, by: 8).map({ Array(todo[$0..<min($0 + 8, todo.count)]) }) {
            let records = batch.map { name -> CKRecord in
                let r = CKRecord(recordType: "Media", recordID: CKRecord.ID(recordName: "media-\(name)", zoneID: zoneID))
                r["name"] = name as CKRecordValue
                r["file"] = CKAsset(fileURL: SharedContainer.mediaURL(name))
                return r
            }
            let (results, _) = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
            for (id, r) in results { if case .success = r { done.insert(String(id.recordName.dropFirst("media-".count))) } }
            uploaded = done
        }
    }

    // MARK: download

    /// Pull the partner's changes. Returns true if anything new arrived.
    @discardableResult
    func fetch() async -> Bool {
        guard Self.isEnabled, role != nil, !busy else { return false }
        busy = true
        defer { busy = false }
        var changed = false
        do {
            var more = true
            while more {
                let r = try await database.recordZoneChanges(inZoneWith: zoneID, since: changeToken)
                var snapshots: [CKRecord] = []
                for (_, result) in r.modificationResultsByID {
                    guard case let .success(mod) = result else { continue }
                    let rec = mod.record
                    if rec.recordType == "Media" { changed = saveMedia(rec) || changed }
                    else if rec.recordType == "Snapshot" { snapshots.append(rec) }
                }
                for rec in snapshots { changed = apply(rec) || changed }
                changeToken = r.changeToken
                more = r.moreComing
            }
            if role == .owner, status == .waitingForPartner, (try? await partnerHasJoined()) == true { status = .paired }
            lastSyncedAt = Date()
            lastError = nil
        } catch let e as CKError where e.code == .changeTokenExpired {
            changeToken = nil
        } catch let e as CKError where e.code == .zoneNotFound || e.code == .userDeletedZone {
            // The partner stopped sharing.
            role = nil
            changeToken = nil
            status = .notPaired
            lastError = "TA 已停止异地同步"
        } catch {
            report(error)
        }
        if changed { store?.reloadFromDisk() }
        return changed
    }

    private func saveMedia(_ rec: CKRecord) -> Bool {
        guard let name = rec["name"] as? String, PrivacyGuard.isSafeMediaName(name),
              rec.recordID.recordName == "media-\(name)", let url = (rec["file"] as? CKAsset)?.fileURL else { return false }
        var u = uploaded
        u.insert(name)
        uploaded = u
        guard !SharedContainer.hasMedia(name) else { return false }
        return (try? FileManager.default.copyItem(at: url, to: SharedContainer.mediaURL(name))) != nil
    }

    private func apply(_ rec: CKRecord) -> Bool {
        guard let url = (rec["payload"] as? CKAsset)?.fileURL, let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(SpaceState.self, from: data), let store else { return false }
        let before = store.state
        if rec.recordID.recordName == "snap-\(myRecordName ?? "")" {
            store.mergeOwnSnapshot(snap) // e.g. restoring after a reinstall
        } else {
            store.mergeFromPartner(snap)
        }
        return store.state != before
    }

    private func report(_ error: Error) {
        let ck = error as? CKError
        switch ck?.code {
        case .notAuthenticated: status = .noAccount
        case .networkUnavailable, .networkFailure: lastError = "网络不可用，稍后会自动重试"
        case .quotaExceeded: lastError = "iCloud 空间已满，照片视频暂时无法同步"
        default: lastError = "同步出错：\(error.localizedDescription)"
        }
    }
}
