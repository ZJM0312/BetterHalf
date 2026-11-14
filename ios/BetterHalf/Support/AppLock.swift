import LocalAuthentication
import Observation
import SwiftUI

/// Optional Face ID / passcode lock, re-engaged whenever the app goes to the background.
@Observable
final class AppLock {
    private static let key = "appLockEnabled"

    private(set) var isEnabled = UserDefaults.standard.bool(forKey: AppLock.key)
    private(set) var isLocked: Bool
    var error: String?

    init() { isLocked = UserDefaults.standard.bool(forKey: AppLock.key) }

    var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "面容 ID"
        case .touchID: return "触控 ID"
        case .opticID: return "视控 ID"
        default: return "设备密码"
        }
    }

    func setEnabled(_ on: Bool) async -> Bool {
        if on {
            guard await authenticate(reason: "开启后，打开 BetterHalf 需要验证身份") else { return false }
        }
        isEnabled = on
        UserDefaults.standard.set(on, forKey: AppLock.key)
        return true
    }

    func lockIfNeeded() { if isEnabled { isLocked = true } }

    func unlock() async {
        if await authenticate(reason: "解锁你们的小宇宙") { isLocked = false }
    }

    private func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            error = "这台设备没有设置面容 ID 或锁屏密码"
            return false
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            error = nil
            return ok
        } catch {
            return false
        }
    }
}

struct LockScreen: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        ZStack {
            Theme.gradient.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.heart.fill").font(.system(size: 64))
                Text("BetterHalf 已上锁").font(.title2.bold())
                Text("只属于你们两个人的空间").font(.subheadline).opacity(0.85)
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("使用\(lock.biometryName)解锁", systemImage: "faceid")
                        .font(.headline).padding(.horizontal, 24).padding(.vertical, 12)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                .padding(.top, 10)
                if let e = lock.error { Text(e).font(.footnote).opacity(0.9) }
            }
            .foregroundStyle(.white)
        }
        .task { await lock.unlock() }
    }
}
