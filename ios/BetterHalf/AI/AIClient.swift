import Foundation
import UIKit

struct AIChatMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    var role: String // "user" | "assistant"
    var content: String
    var date = Date()
    var fromAI = false // false = offline brain reply
}

enum AIError: LocalizedError {
    case notConfigured
    case http(Int, String)
    case badResponse
    case refused

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "还没有填写 AI 设置"
        case let .http(code, msg): return code == 401 || code == 403 ? "API Key 无效或没有权限（\(code)）" : "服务返回错误（\(code)）：\(msg)"
        case .badResponse: return "没有看懂服务返回的内容，请检查接口地址和模型名"
        case .refused: return "模型拒绝回答这条消息，换个说法试试"
        }
    }
}

/// Talks to whichever provider the user configured. Keys come from the Keychain and go only to that provider.
enum AIClient {
    // MARK: chat

    static func chat(system: String, history: [AIChatMessage], endpoint: AIEndpoint, key: String) async throws -> String {
        let base = endpoint.baseURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let turns = history.suffix(16).map { ["role": $0.role, "content": $0.content] }

        switch AIChatFormat(rawValue: endpoint.format) ?? .openAI {
        case .openAI:
            var req = try request(base + "/chat/completions", key: key.isEmpty ? nil : ("Authorization", "Bearer \(key)"))
            let body: [String: Any] = [
                "model": endpoint.model,
                "messages": [["role": "system", "content": system]] + turns,
                "max_tokens": 600,
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let json = try await send(req)
            guard let choices = json["choices"] as? [[String: Any]],
                  let msg = choices.first?["message"] as? [String: Any],
                  let text = msg["content"] as? String else { throw AIError.badResponse }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)

        case .anthropic:
            // Claude Messages API over raw HTTP (no official Swift SDK).
            let url = base.hasSuffix("/v1") ? base + "/messages" : base + "/v1/messages"
            var req = try request(url, key: ("x-api-key", key))
            req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
            var body: [String: Any] = [
                "model": endpoint.model,
                "max_tokens": 1024, // replies are deliberately short
                "system": system,
                "messages": turns,
            ]
            // Server-side refusal fallback for the models that support it.
            let m = endpoint.model
            if m.hasPrefix("claude-opus-5") || m.hasPrefix("claude-fable-5") || m == "claude-sonnet-5-5" {
                req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
                body["fallbacks"] = "default"
            }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let json = try await send(req)
            if json["stop_reason"] as? String == "refusal" { throw AIError.refused }
            guard let content = json["content"] as? [[String: Any]] else { throw AIError.badResponse }
            let text = content.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
            guard !text.isEmpty else { throw AIError.badResponse }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: image

    static func image(prompt: String, endpoint: AIEndpoint, key: String) async throws -> UIImage {
        let base = endpoint.baseURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var req = try request(base + "/images/generations", key: key.isEmpty ? nil : ("Authorization", "Bearer \(key)"))
        req.timeoutInterval = 180
        let body: [String: Any]
        switch AIImageFormat(rawValue: endpoint.format) ?? .openAI {
        case .openAI: body = ["model": endpoint.model, "prompt": prompt, "size": "1024x1024", "n": 1]
        case .siliconFlow: body = ["model": endpoint.model, "prompt": prompt, "image_size": "1024x1024", "batch_size": 1]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let json = try await send(req)
        // Accept the common response shapes: data[].b64_json | data[].url | images[].url
        let items = (json["data"] as? [[String: Any]]) ?? (json["images"] as? [[String: Any]]) ?? []
        if let b64 = items.first?["b64_json"] as? String, let data = Data(base64Encoded: b64), let img = UIImage(data: data) {
            return img
        }
        if let s = items.first?["url"] as? String, let url = URL(string: s) {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) { return img }
        }
        throw AIError.badResponse
    }

    // MARK: helpers

    private static func request(_ urlString: String, key: (String, String)?) throws -> URLRequest {
        guard let url = URL(string: urlString), url.scheme == "https" || url.host == "localhost" || url.host?.hasPrefix("192.168.") == true || url.host == "127.0.0.1" else {
            throw AIError.http(0, "接口地址需要以 https:// 开头")
        }
        var req = URLRequest(url: url, timeoutInterval: 60)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key { req.setValue(key.1, forHTTPHeaderField: key.0) }
        return req
    }

    private static func send(_ req: URLRequest) async throws -> [String: Any] {
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(code) else {
            let err = json["error"] as? [String: Any]
            let msg = (err?["message"] as? String) ?? (json["message"] as? String) ?? String(data: data.prefix(200), encoding: .utf8) ?? ""
            throw AIError.http(code, msg)
        }
        return json
    }
}
