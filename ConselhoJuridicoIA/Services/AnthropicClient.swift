import Foundation

struct AnthropicClient {
    struct ResponseEnvelope: Decodable {
        struct ContentItem: Decodable {
            let type: String
            let text: String?
        }
        let content: [ContentItem]
    }

    func generate(apiKey: String, model: String, system: String, prompt: String, maxOutputTokens: Int) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingCredential("Anthropic")
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxOutputTokens,
            "system": system,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse("Anthropic")
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = extractErrorMessage(from: data) ?? String(data: data, encoding: .utf8) ?? "Erro HTTP \(http.statusCode)"
            throw AIClientError.provider("Anthropic", message)
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        let result = decoded.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.isEmpty else {
            throw AIClientError.emptyResponse("Anthropic")
        }
        return result
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }
}
