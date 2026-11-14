import Foundation
import Observation
import Security

/// Wire format a provider speaks.
enum AIChatFormat: String, Codable { case openAI, anthropic }
enum AIImageFormat: String, Codable { case openAI, siliconFlow }

struct AIPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let baseURL: String
    let model: String
    let format: String // AIChatFormat / AIImageFormat raw value
    let keyHint: String
}

enum AIPresets {
    /// Text chat. Anything that speaks the OpenAI `/chat/completions` format works via "自定义".
    static let chat: [AIPreset] = [
        AIPreset(id: "deepseek", name: "DeepSeek", baseURL: "https://api.deepseek.com", model: "deepseek-chat",
                 format: AIChatFormat.openAI.rawValue, keyHint: "在 platform.deepseek.com 创建 API Key"),
        AIPreset(id: "openai", name: "OpenAI", baseURL: "https://api.openai.com/v1", model: "gpt-4o-mini",
                 format: AIChatFormat.openAI.rawValue, keyHint: "在 platform.openai.com 创建 API Key"),
        AIPreset(id: "claude", name: "Claude (Anthropic)", baseURL: "https://api.anthropic.com", model: "claude-opus-5-5",
                 format: AIChatFormat.anthropic.rawValue, keyHint: "在 console.anthropic.com 创建 API Key"),
        AIPreset(id: "qwen", name: "通义千问", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", model: "qwen-plus",
                 format: AIChatFormat.openAI.rawValue, keyHint: "在阿里云百炼控制台创建 API Key"),
        AIPreset(id: "kimi", name: "Kimi (Moonshot)", baseURL: "https://api.moonshot.cn/v1", model: "moonshot-v1-8k",
                 format: AIChatFormat.openAI.rawValue, keyHint: "在 platform.moonshot.cn 创建 API Key"),
        AIPreset(id: "glm", name: "智谱 GLM", baseURL: "https://open.bigmodel.cn/api/paas/v4", model: "glm-4-flash",
                 format: AIChatFormat.openAI.rawValue, keyHint: "在 open.bigmodel.cn 创建 API Key"),
        AIPreset(id: "custom", name: "自定义（OpenAI 兼容）", baseURL: "", model: "",
                 format: AIChatFormat.openAI.rawValue, keyHint: "OpenRouter、本地 Ollama 等任何兼容接口；本地服务可不填 Key"),
    ]

    /// Image generation. (DeepSeek has no image API, so pair it with one of these.)
    static let image: [AIPreset] = [
        AIPreset(id: "openai", name: "OpenAI 图像", baseURL: "https://api.openai.com/v1", model: "gpt-image-1",
                 format: AIImageFormat.openAI.rawValue, keyHint: "在 platform.openai.com 创建 API Key"),
        AIPreset(id: "siliconflow", name: "硅基流动", baseURL: "https://api.siliconflow.cn/v1", model: "Kwai-Kolors/Kolors",
                 format: AIImageFormat.siliconFlow.rawValue, keyHint: "在 cloud.siliconflow.cn 创建 API Key"),
        AIPreset(id: "custom", name: "自定义（OpenAI 兼容）", baseURL: "", model: "",
                 format: AIImageFormat.openAI.rawValue, keyHint: "任何兼容 /images/generations 的接口"),
    ]
}

/// Non-secret part of a provider setup (secrets live in the Keychain).
struct AIEndpoint: Codable, Equatable {
    var presetID: String
    var format: String
    var baseURL: String
    var model: String

    var host: String { URL(string: baseURL)?.host ?? baseURL }
    var isComplete: Bool { !baseURL.trimmingCharacters(in: .whitespaces).isEmpty && !model.trimmingCharacters(in: .whitespaces).isEmpty }

    init(preset: AIPreset) {
        presetID = preset.id; format = preset.format; baseURL = preset.baseURL; model = preset.model
    }
}

/// User-supplied AI configuration ("bring your own key"). Never synced, never exported.
@Observable
final class AISettings {
    enum Kind: String { case chat, image }

    private(set) var chat: AIEndpoint?
    private(set) var image: AIEndpoint?
    private(set) var hasChatKey = false
    private(set) var hasImageKey = false

    init() {
        chat = Self.loadEndpoint(.chat)
        image = Self.loadEndpoint(.image)
        hasChatKey = !(Keychain.read(Kind.chat.rawValue) ?? "").isEmpty
        hasImageKey = !(Keychain.read(Kind.image.rawValue) ?? "").isEmpty
    }

    /// Local endpoints (Ollama etc.) may not need a key.
    var chatReady: Bool { (chat?.isComplete ?? false) && (hasChatKey || chat?.presetID == "custom") }
    var imageReady: Bool { (image?.isComplete ?? false) && (hasImageKey || image?.presetID == "custom") }

    func key(_ kind: Kind) -> String { Keychain.read(kind.rawValue) ?? "" }

    func save(_ kind: Kind, endpoint: AIEndpoint?, key: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if let endpoint, let data = try? JSONEncoder().encode(endpoint) {
            UserDefaults.standard.set(data, forKey: "ai.endpoint.\(kind.rawValue)")
        } else {
            UserDefaults.standard.removeObject(forKey: "ai.endpoint.\(kind.rawValue)")
        }
        if trimmedKey.isEmpty { Keychain.delete(kind.rawValue) } else { Keychain.write(kind.rawValue, trimmedKey) }
        switch kind {
        case .chat: chat = endpoint; hasChatKey = !trimmedKey.isEmpty
        case .image: image = endpoint; hasImageKey = !trimmedKey.isEmpty
        }
    }

    func clear(_ kind: Kind) { save(kind, endpoint: nil, key: "") }

    // MARK: consent (per host, asked before the first request leaves the phone)
    func hasConsent(for host: String) -> Bool { UserDefaults.standard.bool(forKey: "ai.consent.\(host)") }
    func grantConsent(for host: String) { UserDefaults.standard.set(true, forKey: "ai.consent.\(host)") }

    private static func loadEndpoint(_ kind: Kind) -> AIEndpoint? {
        guard let data = UserDefaults.standard.data(forKey: "ai.endpoint.\(kind.rawValue)") else { return nil }
        return try? JSONDecoder().decode(AIEndpoint.self, from: data)
    }
}

/// Minimal Keychain wrapper. Items stay on this device (not in iCloud Keychain or backups).
enum Keychain {
    private static let service = "com.betterhalf.ai"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read(_ account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ account: String, _ value: String) {
        let data = Data(value.utf8)
        let attrs: [String: Any] = [kSecValueData as String: data,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        if SecItemUpdate(query(account) as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var q = query(account)
            q.merge(attrs) { $1 }
            SecItemAdd(q as CFDictionary, nil)
        }
    }

    static func delete(_ account: String) { SecItemDelete(query(account) as CFDictionary) }
}
