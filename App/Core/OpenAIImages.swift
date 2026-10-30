import Foundation

enum GenerationError: LocalizedError {
    case missingKey
    case rejected(status: Int, detail: String)
    case unreachable(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingKey: String(localized: "No OpenAI API key is set")
        case .rejected(let status, let detail): String(localized: "OpenAI returned \(status): \(detail)")
        case .unreachable(let detail): String(localized: "Network error: \(detail)")
        case .badResponse: String(localized: "The response from OpenAI could not be read")
        }
    }

    /// Retrying later cannot help until the user changes something.
    var isPermanent: Bool {
        switch self {
        case .missingKey: true
        case .rejected(let status, _): ![408, 409, 429].contains(status) && status < 500
        case .unreachable, .badResponse: false
        }
    }
}

struct OpenAIImages: Sendable {
    let apiKey: String
    let model: String
    let quality: String

    private static let retryDelays: [UInt64] = [20, 60, 180]

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 600
        configuration.timeoutIntervalForResource = 900
        return URLSession(configuration: configuration)
    }()

    func generate(prompt: String, size: String) async throws -> Data {
        let body: [String: Any] = ["model": model, "prompt": prompt, "size": size, "quality": quality, "n": 1]
        return try await send("generations", body: JSONSerialization.data(withJSONObject: body), contentType: "application/json")
    }

    func edit(prompt: String, image: Data, size: String) async throws -> Data {
        let boundary = UUID().uuidString
        var body = Data()
        for (name, value) in ["model": model, "prompt": prompt, "size": size, "quality": quality, "n": "1"] {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"light.png\"\r\nContent-Type: image/png\r\n\r\n".utf8))
        body.append(image)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return try await send("edits", body: body, contentType: "multipart/form-data; boundary=\(boundary)")
    }

    /// POSTs to the images API, retrying transient failures; returns the decoded image bytes.
    private func send(_ path: String, body: Data, contentType: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/\(path)")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        var attempt = 0
        while true {
            let failure: GenerationError
            do {
                let (data, response) = try await Self.session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 200 { return try Self.decode(data) }
                failure = .rejected(status: status, detail: Self.errorMessage(in: data))
            } catch let error as GenerationError {
                throw error
            } catch {
                failure = .unreachable(error.localizedDescription)
            }
            if failure.isPermanent || attempt >= Self.retryDelays.count { throw failure }
            try await Task.sleep(nanoseconds: Self.retryDelays[attempt] * 1_000_000_000)
            attempt += 1
        }
    }

    private static func decode(_ data: Data) throws -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]],
              let encoded = items.first?["b64_json"] as? String,
              let image = Data(base64Encoded: encoded) else { throw GenerationError.badResponse }
        return image
    }

    private static func errorMessage(in data: Data) -> String {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (json?["error"] as? [String: Any])?["message"] as? String
        return String((message ?? String(decoding: data.prefix(300), as: UTF8.self)).prefix(300))
    }
}
