import Foundation
import os
import UIKit
import Vision

struct VisionTextExtractor: TextExtracting {
    nonisolated private let passthrough = PassthroughTextExtractor()

    nonisolated init() {}

    nonisolated func extract(from source: Source) async throws -> ExtractedText {
        switch source.type {
        case .text, .shareText:
            return try await passthrough.extract(from: source)
        case .image, .shareImage:
            guard let imageData = source.imageData else {
                throw ExtractionError.invalidImage
            }
            return try await recognizeText(in: imageData)
        }
    }

    nonisolated private func recognizeText(in imageData: Data) async throws -> ExtractedText {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            throw ExtractionError.invalidImage
        }

        let resumeGate = OSAllocatedUnfairLock(initialState: false)
        return try await withCheckedThrowingContinuation { continuation in
            let resumeOnce: (Result<ExtractedText, Error>) -> Void = { result in
                let shouldResume = resumeGate.withLock { resumed in
                    if resumed { return false }
                    resumed = true
                    return true
                }
                guard shouldResume else { return }
                continuation.resume(with: result)
            }

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    resumeOnce(.failure(error))
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

                guard !text.isEmpty else {
                    resumeOnce(.failure(ExtractionError.emptyResult))
                    return
                }

                let confidences = observations.compactMap { observation in
                    observation.topCandidates(1).first?.confidence
                }
                let averageConfidence = confidences.isEmpty
                    ? nil
                    : Double(confidences.reduce(0, +)) / Double(confidences.count)

                resumeOnce(.success(
                    ExtractedText(
                        text: text,
                        method: .ocr,
                        ocrConfidence: averageConfidence
                    )
                ))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumeOnce(.failure(error))
            }
        }
    }
}
