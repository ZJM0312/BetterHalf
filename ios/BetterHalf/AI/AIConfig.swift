import Foundation
import Observation
import Security

/// Wire format a provider speaks.
enum AIChatFormat: String, Codable { case openAI, anthropic }
/// Image APIs differ in small ways; each case builds the request body its provider expects.
enum AIImageFormat: String, Codable {
    case openAI       // model, prompt, size, n
    case minimal      // model, prompt (+ size if set) — xAI, 智谱 CogView
    case siliconFlow  // image_size, batch_size
    case ark          // 火山方舟 Seedream: size, watermark, response_format
    case minimax      // MiniMax image_generation: aspect_ratio, base64 response
}

struct AIPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let group: String
    let baseURL: String
    let model: String
    let format: String // AIChatFormat / AIImageFormat raw value
    let keyHint: String
    var size: String? = nil
    var needsKey = true
}

enum AIPresets {
    static let groupOrder = ["国内", "海外", "聚合 / 本地 / 自定义"]

    /// Text chat. Anything that speaks the OpenAI `/chat/completions` format works via "自定义".
    static let chat: [AIPreset] = {
        let o = AIChatFormat.openAI.rawValue
        return [
            AIPreset(id: "deepseek", name: "DeepSeek", group: "国内", baseURL: "https://api.deepseek.com", model: "deepseek-chat",
                     format: o, keyHint: "在 platform.deepseek.com 创建 API Key。便宜、中文好，推荐"),
            AIPreset(id: "doubao", name: "豆包 Seed（火山方舟）", group: "国内", baseURL: "https://ark.cn-beijing.volces.com/api/v3",
                     model: "doubao-seed-1-6-flash-250828", format: o,
                     keyHint: "在火山方舟控制台创建 API Key，并开通对应模型。模型名可以填控制台里的模型 ID 或接入点 ID（ep-…）"),
            AIPreset(id: "qwen", name: "通义千问（阿里云百炼）", group: "国内", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
                     model: "qwen-plus", format: o, keyHint: "在阿里云百炼控制台创建 API Key"),
            AIPreset(id: "kimi", name: "Kimi（月之暗面）", group: "国内", baseURL: "https://api.moonshot.cn/v1", model: "kimi-k2-turbo-preview",
                     format: o, keyHint: "在 platform.moonshot.cn 创建 API Key"),
            AIPreset(id: "glm", name: "智谱 GLM", group: "国内", baseURL: "https://open.bigmodel.cn/api/paas/v4", model: "glm-4-flash",
                     format: o, keyHint: "在 open.bigmodel.cn 创建 API Key（glm-4-flash 免费）"),
            AIPreset(id: "minimax", name: "MiniMax", group: "国内", baseURL: "https://api.minimaxi.com/v1", model: "MiniMax-M1",
                     format: o, keyHint: "在 platform.minimaxi.com 创建 API Key"),
            AIPreset(id: "ernie", name: "文心一言（百度千帆）", group: "国内", baseURL: "https://qianfan.baidubce.com/v2", model: "ernie-4.5-turbo-32k",
                     format: o, keyHint: "在百度智能云千帆控制台创建 API Key（bce-v3/…）"),
            AIPreset(id: "hunyuan", name: "腾讯混元", group: "国内", baseURL: "https://api.hunyuan.cloud.tencent.com/v1", model: "hunyuan-turbos-latest",
                     format: o, keyHint: "在腾讯云混元控制台创建 API Key"),
            AIPreset(id: "spark", name: "讯飞星火", group: "国内", baseURL: "https://spark-api-open.xf-yun.com/v1", model: "lite",
                     format: o, keyHint: "在讯飞开放平台控制台复制 APIPassword 填到这里"),
            AIPreset(id: "stepfun", name: "阶跃星辰", group: "国内", baseURL: "https://api.stepfun.com/v1", model: "step-2-mini",
                     format: o, keyHint: "在 platform.stepfun.com 创建 API Key"),
            AIPreset(id: "openai", name: "OpenAI", group: "海外", baseURL: "https://api.openai.com/v1", model: "gpt-4.1-mini",
                     format: o, keyHint: "在 platform.openai.com 创建 API Key"),
            AIPreset(id: "claude", name: "Claude（Anthropic）", group: "海外", baseURL: "https://api.anthropic.com", model: "claude-opus-5-5",
                     format: AIChatFormat.anthropic.rawValue, keyHint: "在 console.anthropic.com 创建 API Key"),
            AIPreset(id: "gemini", name: "Google Gemini", group: "海外", baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
                     model: "gemini-2.5-flash", format: o, keyHint: "在 aistudio.google.com 创建 API Key"),
            AIPreset(id: "grok", name: "xAI Grok", group: "海外", baseURL: "https://api.x.ai/v1", model: "grok-3-mini",
                     format: o, keyHint: "在 console.x.ai 创建 API Key"),
            AIPreset(id: "mistral", name: "Mistral", group: "海外", baseURL: "https://api.mistral.ai/v1", model: "mistral-small-latest",
                     format: o, keyHint: "在 console.mistral.ai 创建 API Key"),
            AIPreset(id: "groq", name: "Groq", group: "海外", baseURL: "https://api.groq.com/openai/v1", model: "llama-3.3-70b-versatile",
                     format: o, keyHint: "在 console.groq.com 创建 API Key"),
            AIPreset(id: "siliconflow", name: "硅基流动", group: "聚合 / 本地 / 自定义", baseURL: "https://api.siliconflow.cn/v1",
                     model: "deepseek-ai/DeepSeek-V3", format: o, keyHint: "在 cloud.siliconflow.cn 创建 API Key，一个 Key 可用很多开源模型"),
            AIPreset(id: "openrouter", name: "OpenRouter", group: "聚合 / 本地 / 自定义", baseURL: "https://openrouter.ai/api/v1",
                     model: "deepseek/deepseek-chat", format: o, keyHint: "在 openrouter.ai 创建 API Key，一个 Key 可用各家模型"),
            AIPreset(id: "ollama", name: "Ollama（自己电脑上）", group: "聚合 / 本地 / 自定义", baseURL: "http://192.168.1.2:11434/v1",
                     model: "qwen2.5:7b", format: o, keyHint: "把地址里的 IP 换成你电脑在同一 Wi-Fi 下的 IP，电脑上用 OLLAMA_HOST=0.0.0.0 启动；不需要 Key",
                     needsKey: false),
            AIPreset(id: "custom", name: "自定义（OpenAI 兼容）", group: "聚合 / 本地 / 自定义", baseURL: "", model: "",
                     format: o, keyHint: "任何兼容 /chat/completions 的接口都可以；不需要 Key 的服务可以留空", needsKey: false),
            AIPreset(id: "custom-anthropic", name: "自定义（Anthropic 兼容）", group: "聚合 / 本地 / 自定义", baseURL: "", model: "",
                     format: AIChatFormat.anthropic.rawValue, keyHint: "兼容 Anthropic /v1/messages 的接口或代理"),
        ]
    }()

    /// Image generation. DeepSeek / Claude have no image API, so pair them with one of these.
    static let image: [AIPreset] = [
        AIPreset(id: "seedream", name: "豆包 Seedream（火山方舟）", group: "国内", baseURL: "https://ark.cn-beijing.volces.com/api/v3",
                 model: "doubao-seedream-4-0-250828", format: AIImageFormat.ark.rawValue,
                 keyHint: "在火山方舟控制台创建 API Key 并开通 Seedream", size: "2048x2048"),
        AIPreset(id: "siliconflow", name: "硅基流动（Kolors 等）", group: "国内", baseURL: "https://api.siliconflow.cn/v1", model: "Kwai-Kolors/Kolors",
                 format: AIImageFormat.siliconFlow.rawValue, keyHint: "在 cloud.siliconflow.cn 创建 API Key", size: "1024x1024"),
        AIPreset(id: "cogview", name: "智谱 CogView", group: "国内", baseURL: "https://open.bigmodel.cn/api/paas/v4", model: "cogview-3-flash",
                 format: AIImageFormat.minimal.rawValue, keyHint: "在 open.bigmodel.cn 创建 API Key（cogview-3-flash 免费）", size: "1024x1024"),
        AIPreset(id: "minimax", name: "MiniMax 图像", group: "国内", baseURL: "https://api.minimaxi.com/v1", model: "image-01",
                 format: AIImageFormat.minimax.rawValue, keyHint: "在 platform.minimaxi.com 创建 API Key"),
        AIPreset(id: "openai", name: "OpenAI 图像", group: "海外", baseURL: "https://api.openai.com/v1", model: "gpt-image-1",
                 format: AIImageFormat.openAI.rawValue, keyHint: "在 platform.openai.com 创建 API Key", size: "1024x1024"),
        AIPreset(id: "imagen", name: "Google Imagen", group: "海外", baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
                 model: "imagen-4.0-generate-001", format: AIImageFormat.openAI.rawValue,
                 keyHint: "在 aistudio.google.com 创建 API Key（需开通付费）", size: "1024x1024"),
        AIPreset(id: "grok", name: "xAI Grok 图像", group: "海外", baseURL: "https://api.x.ai/v1", model: "grok-2-image",
                 format: AIImageFormat.minimal.rawValue, keyHint: "在 console.x.ai 创建 API Key"),
        AIPreset(id: "custom", name: "自定义（OpenAI 兼容）", group: "聚合 / 本地 / 自定义", baseURL: "", model: "",
                 format: AIImageFormat.openAI.rawValue, keyHint: "任何兼容 /images/generations 的接口；有特殊参数可以填在「附加参数」里",
                 size: "1024x1024", needsKey: false),
    ]

    static func grouped(_ list: [AIPreset]) -> [(String, [AIPreset])] {
        groupOrder.compactMap { g in
            let items = list.filter { $0.group == g }
            return items.isEmpty ? nil : (g, items)
        }
    }
}

/// Non-secret part of a provider setup (secrets live in the Keychain).
struct AIEndpoint: Codable, Equatable {
    var presetID: String
    var format: String
    var baseURL: String
    var model: String
    /// Image size such as "1024x1024" (image endpoints only; nil = provider default).
    var size: String? = nil
    /// Extra JSON object merged into the request body, for provider-specific options.
    var extra: String? = nil

    var host: String { URL(string: baseURL)?.host ?? baseURL }
    var isComplete: Bool { !baseURL.trimmingCharacters(in: .whitespaces).isEmpty && !model.trimmingCharacters(in: .whitespaces).isEmpty }

    init(preset: AIPreset) {
        presetID = preset.id; format = preset.format; baseURL = preset.baseURL; model = preset.model; size = preset.size
    }

    /// Parsed `extra`; nil if empty, throws a readable error if it isn't a JSON object.
    func extraParams() throws -> [String: Any] {
        let t = (extra ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [:] }
        guard let obj = try? JSONSerialization.jsonObject(with: Data(t.utf8)) as? [String: Any] else {
            throw AIError.http(0, "「附加参数」需要是 JSON 对象，例如 {\"temperature\": 0.8}")
        }
        return obj
    }
}

/// User-supplied AI configuration ("bring your own key"). Never synced, never exported.
/// Keys are stored per provider, so switching between providers never sends one provider's key to another.
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
        Self.migrateLegacyKey(.chat, presetID: chat?.presetID)
        Self.migrateLegacyKey(.image, presetID: image?.presetID)
        refreshKeyFlags()
    }

    private func refreshKeyFlags() {
        hasChatKey = !(chat.map { key(.chat, presetID: $0.presetID) } ?? "").isEmpty
        hasImageKey = !(image.map { key(.image, presetID: $0.presetID) } ?? "").isEmpty
    }

    static func preset(_ kind: Kind, _ id: String?) -> AIPreset? {
        (kind == .chat ? AIPresets.chat : AIPresets.image).first { $0.id == id }
    }

    /// Local endpoints (Ollama etc.) may not need a key.
    var chatReady: Bool { ready(.chat, chat, hasChatKey) }
    var imageReady: Bool { ready(.image, image, hasImageKey) }
    private func ready(_ kind: Kind, _ e: AIEndpoint?, _ hasKey: Bool) -> Bool {
        guard let e, e.isComplete else { return false }
        return hasKey || !(Self.preset(kind, e.presetID)?.needsKey ?? true)
    }

    /// Key for the currently saved provider of this kind.
    func key(_ kind: Kind) -> String {
        guard let id = (kind == .chat ? chat : image)?.presetID else { return "" }
        return key(kind, presetID: id)
    }
    func key(_ kind: Kind, presetID: String) -> String { Keychain.read("\(kind.rawValue).\(presetID)") ?? "" }

    func save(_ kind: Kind, endpoint: AIEndpoint?, key: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if let endpoint, let data = try? JSONEncoder().encode(endpoint) {
            UserDefaults.standard.set(data, forKey: "ai.endpoint.\(kind.rawValue)")
            let account = "\(kind.rawValue).\(endpoint.presetID)"
            if trimmedKey.isEmpty { Keychain.delete(account) } else { Keychain.write(account, trimmedKey) }
        } else {
            UserDefaults.standard.removeObject(forKey: "ai.endpoint.\(kind.rawValue)")
        }
        switch kind {
        case .chat: chat = endpoint
        case .image: image = endpoint
        }
        refreshKeyFlags()
    }

    /// Forget the active provider and its key.
    func clear(_ kind: Kind) {
        if let id = (kind == .chat ? chat : image)?.presetID { Keychain.delete("\(kind.rawValue).\(id)") }
        save(kind, endpoint: nil, key: "")
    }

    // MARK: consent (per host, asked before the first request leaves the phone)
    func hasConsent(for host: String) -> Bool { UserDefaults.standard.bool(forKey: "ai.consent.\(host)") }
    func grantConsent(for host: String) { UserDefaults.standard.set(true, forKey: "ai.consent.\(host)") }

    private static func loadEndpoint(_ kind: Kind) -> AIEndpoint? {
        guard let data = UserDefaults.standard.data(forKey: "ai.endpoint.\(kind.rawValue)") else { return nil }
        return try? JSONDecoder().decode(AIEndpoint.self, from: data)
    }

    /// Earlier builds kept one key per kind; move it under the provider it was saved with.
    private static func migrateLegacyKey(_ kind: Kind, presetID: String?) {
        guard let old = Keychain.read(kind.rawValue) else { return }
        if let presetID, Keychain.read("\(kind.rawValue).\(presetID)") == nil { Keychain.write("\(kind.rawValue).\(presetID)", old) }
        Keychain.delete(kind.rawValue)
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
