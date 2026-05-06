import Foundation
import UIKit
import Vision

/// Free, on-device photo hints using Apple’s image classifier + `LocalFoodCatalog` keyword matching.
enum OnDeviceMealPhotoAnalyzer {
    nonisolated static func classifyImage(_ image: UIImage) async throws -> [(identifier: String, confidence: Float)] {
        guard let cgImage = image.cgImage else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let pairs = observations.prefix(35).map { ($0.identifier, $0.confidence) }
                continuation.resume(returning: Array(pairs))
            }
            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Classifies the image and returns catalog entries ranked by best keyword overlap with labels.
    static func suggestCatalogEntries(from image: UIImage) async throws -> (entries: [LocalFoodCatalog.Entry], labelSummary: String) {
        let results = try await classifyImage(image)
        let ranked = LocalFoodCatalog.rankedEntries(visionResults: results)
        let summary = results.prefix(8).map { ident, conf in
            let pct = Int((conf * 100).rounded())
            return "\(ident.replacingOccurrences(of: "_", with: " ")) (\(pct)%)"
        }.joined(separator: ", ")
        return (ranked, summary)
    }
}
