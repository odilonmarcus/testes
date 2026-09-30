import Foundation

struct OpenAIClient {
    struct ResponseEnvelope: Decodable {
        struct OutputItem: Decodable {
            struct ContentItem: Decodable {
                let type: String?
                let text: String?
            }
            let type: String?
            let content: [ContentItem]?
        }

        struct APIError: Decodable {
            let message: String?
        }

        let output: [OutputItem]?
        let error: APIError?
    }

    func generate(apiKey: String, model: String, system: String, prompt: String, maxOutputTokens: Int) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingCredential("OpenAI")
        }

        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "instructions": system,
            "input": prompt,
            "max_output_tokens": maxOutputTokens,
            "store": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse("OpenAI")
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = extractErrorMessage(from: data) ?? String(data: data, encoding: .utf8) ?? "Erro HTTP \(http.statusCode)"
            throw AIClientError.provider("OpenAI", message)
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        let texts = decoded.output?
            .flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" || $0.type == nil }
            .compactMap(\.text) ?? []

        let result = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            if let message = decoded.error?.message {
                throw AIClientError.provider("OpenAI", message)
            }
            throw AIClientError.emptyResponse("OpenAI")
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

enum AIClientError: LocalizedError {
    case missingCredential(String)
    case invalidResponse(String)
    case provider(String, String)
    case emptyResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingCredential(let provider):
            return "Configure a chave da \(provider) em Ajustes."
        case .invalidResponse(let provider):
            return "Resposta inválida recebida da \(provider)."
        case .provider(let provider, let message):
            return "\(provider): \(message)"
        case .emptyResponse(let provider):
            return "A \(provider) retornou uma resposta vazia."
        }
    }
}
