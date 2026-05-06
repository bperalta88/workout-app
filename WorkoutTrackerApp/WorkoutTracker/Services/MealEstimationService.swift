import Foundation
import UIKit

// MARK: - API payload (decoded from model JSON)

struct MealVisionPayload: Codable {
    var mealName: String?
    var items: [MealVisionItemRow]
}

struct MealVisionItemRow: Codable {
    var name: String
    var estimatedGrams: Double
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
}

// MARK: - Errors

enum MealEstimationError: LocalizedError {
    case missingAPIKey
    case invalidImage
    case malformedRequest
    case httpStatus(code: Int, message: String?)
    case emptyChoices
    case emptyResponseContent
    case jsonPayloadInvalid
    case decodingFailed(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Paste your OpenAI API key (starts with sk-) in Settings → Meal photos, or under Log meal → Photo. Create a key at platform.openai.com/api-keys."
        case .invalidImage:
            return "Could not read the photo."
        case .malformedRequest:
            return "Could not build the API request."
        case .httpStatus(let code, let message):
            if let message, !message.isEmpty { return "API error (\(code)): \(message)" }
            return "API request failed (code \(code))."
        case .emptyChoices:
            return "The API returned no result."
        case .emptyResponseContent:
            return "The API returned an empty message."
        case .jsonPayloadInvalid:
            return "Could not parse nutrition JSON from the model."
        case .decodingFailed(let err):
            return "Invalid JSON structure: \(err.localizedDescription)"
        case .network(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}

// MARK: - OpenAI (GPT-4o vision)

enum MealEstimationService {
    private static let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    private static let systemPrompt = """
    You are a nutrition assistant. Analyze meal photos and estimate foods, portion sizes in grams, and macronutrients for each visible item.
    For each item, calories, proteinG, carbsG, and fatG must be totals for that item at estimatedGrams (not per 100g).
    Reply with a single JSON object only — no markdown, no code fences, no commentary.
    Schema: {"mealName":string or null,"items":[{"name":string,"estimatedGrams":number,"calories":number,"proteinG":number,"carbsG":number,"fatG":number}]}
    Use realistic grams from plate context. If unsure, give your best estimate and conservative ranges in the numbers.
    """

    private static let userPrompt = """
    Identify each distinct food, estimate grams per item from the image, and provide calories, proteinG, carbsG, and fatG for that portion.
    Sum portions should reflect a typical serving for what is shown. Output JSON only.
    """

    /// JPEG suitable for API: max side 1024, ~0.72 quality.
    static func compressImageForAPI(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1024
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: newSize))
        guard let resized = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        return resized.jpegData(compressionQuality: 0.72)
    }

    static func dataURLJPEGBase64(_ jpegData: Data) -> String {
        "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }

    /// Calls OpenAI Chat Completions with `gpt-4o` and a vision `image_url` part.
    static func estimateMealFromPhoto(image: UIImage, apiKey: String) async throws -> MealVisionPayload {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MealEstimationError.missingAPIKey }
        guard let jpeg = compressImageForAPI(image) else { throw MealEstimationError.invalidImage }

        let dataURL = dataURLJPEGBase64(jpeg)
        let body: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 2000,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": systemPrompt],
                [
                    "role": "user",
                    "content": [
                        ["type": "image_url", "image_url": ["url": dataURL]],
                        ["type": "text", "text": userPrompt]
                    ]
                ]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw MealEstimationError.malformedRequest
        }

        var request = URLRequest(url: chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        request.httpBody = httpBody

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 120
        let session = URLSession(configuration: config)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MealEstimationError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw MealEstimationError.httpStatus(code: -1, message: "Not an HTTP response")
        }

        if http.statusCode < 200 || http.statusCode >= 300 {
            let msg = String(data: data, encoding: .utf8)
            throw MealEstimationError.httpStatus(code: http.statusCode, message: msg)
        }

        let content: String
        do {
            content = try extractAssistantContent(from: data)
        } catch {
            throw error
        }

        let jsonData: Data
        do {
            jsonData = try extractJSONObjectData(from: content)
        } catch {
            throw MealEstimationError.jsonPayloadInvalid
        }

        do {
            let decoded = try decodeMealPayload(jsonData)
            if decoded.items.isEmpty {
                throw MealEstimationError.jsonPayloadInvalid
            }
            return decoded
        } catch let err as MealEstimationError {
            throw err
        } catch {
            throw MealEstimationError.decodingFailed(error)
        }
    }

    private static func decodeMealPayload(_ jsonData: Data) throws -> MealVisionPayload {
        do {
            return try JSONDecoder().decode(MealVisionPayload.self, from: jsonData)
        } catch {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(MealVisionPayload.self, from: jsonData)
        }
    }

    private struct OpenAIChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        let choices: [Choice]
    }

    private static func extractAssistantContent(from data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let first = decoded.choices.first else { throw MealEstimationError.emptyChoices }
        guard let text = first.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw MealEstimationError.emptyResponseContent
        }
        return text
    }

    /// Strips optional ```json fences and returns UTF-8 JSON data.
    static func extractJSONObjectData(from raw: String) throws -> Data {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstLineEnd = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstLineEnd)...])
            }
            if let fence = s.range(of: "```") {
                s = String(s[..<fence.lowerBound])
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = s.data(using: .utf8) else { throw MealEstimationError.jsonPayloadInvalid }
        return data
    }
}
