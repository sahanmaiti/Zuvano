import Foundation
import Observation
import SwiftData

enum AppFlow: Equatable {
    case home
    case processing
    case extractionComplete
    case pipelineFailure
    case manualTextEntry
    case homeTextEntry
}

@Observable
@MainActor
final class AppFlowCoordinator {
    var flow: AppFlow = .home
    var activeIntake: IntakeSnapshot?
    var isWorking = false
    var alertTitle = "Something went wrong"
    var alertMessage: String?

    private let pipeline: IntakePipeline

    init(modelContainer: ModelContainer) {
        let store = ActionStore(modelContainer: modelContainer)
        self.pipeline = IntakePipeline(store: store)
    }

    init(pipeline: IntakePipeline) {
        self.pipeline = pipeline
    }

    func recoverOnLaunch() async {
        let recovered = await pipeline.recoverSessionsOnLaunch()
        guard let latest = recovered.first else { return }
        activeIntake = latest
        route(for: latest)
    }

    /// Called by SwiftUI `PasteButton` after iOS authorizes clipboard access.
    func handlePastedText(_ text: String) {
        alertMessage = nil
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertTitle = "Couldn't paste"
            alertMessage = "No text was pasted. Copy a conversation in another app and try again."
            return
        }

        Task {
            await startIntake(from: .pastedText(trimmed))
        }
    }

    func showHomeTextEntry() {
        flow = .homeTextEntry
    }

    func submitHomeText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            await startIntake(from: .pastedText(trimmed))
        }
    }

    func showPhotoImportError() {
        alertTitle = "That content can't be used"
        alertMessage = "Try choosing another photo, pasting the conversation text, or entering it manually."
    }

    func dismissAlert() {
        alertMessage = nil
    }

    func startIntake(from source: Source) async {
        isWorking = true
        flow = .processing
        activeIntake = nil

        do {
            let snapshot = try await pipeline.startIntake(from: source)
            activeIntake = snapshot
            route(for: snapshot)
        } catch {
            activeIntake = nil
            flow = .home
            alertTitle = "That content can't be used"
            alertMessage = "Try copying the conversation again or entering the text manually."
        }

        isWorking = false
    }

    func retryFromFailure() async {
        guard let intake = activeIntake else { return }

        switch intake.failedStage {
        case .extraction:
            await retryExtraction()
        case .understanding:
            await retryUnderstanding()
        case .draftGeneration:
            await retryDraftGeneration()
        case .none:
            break
        }
    }

    func retryUnderstanding() async {
        guard let intakeID = activeIntake?.id else { return }
        isWorking = true
        flow = .processing

        do {
            let snapshot = try await pipeline.retryUnderstanding(intakeID: intakeID)
            activeIntake = snapshot
            route(for: snapshot)
        } catch {
            if let snapshot = try? await pipeline.snapshot(for: intakeID) {
                activeIntake = snapshot
                route(for: snapshot)
            }
        }

        isWorking = false
    }

    func retryDraftGeneration() async {
        guard let intakeID = activeIntake?.id else { return }
        isWorking = true
        flow = .processing

        do {
            let snapshot = try await pipeline.retryDraftGeneration(intakeID: intakeID)
            activeIntake = snapshot
            route(for: snapshot)
        } catch {
            if let snapshot = try? await pipeline.snapshot(for: intakeID) {
                activeIntake = snapshot
                route(for: snapshot)
            }
        }

        isWorking = false
    }

    func retryExtraction() async {
        guard let intakeID = activeIntake?.id else { return }
        isWorking = true
        flow = .processing

        do {
            let snapshot = try await pipeline.retryExtraction(intakeID: intakeID)
            activeIntake = snapshot
            route(for: snapshot)
        } catch {
            if let snapshot = try? await pipeline.snapshot(for: intakeID) {
                activeIntake = snapshot
                route(for: snapshot)
            }
        }

        isWorking = false
    }

    func submitManualText(_ text: String) async {
        guard let intakeID = activeIntake?.id else { return }
        isWorking = true

        do {
            let snapshot = try await pipeline.applyManualText(intakeID: intakeID, text: text)
            activeIntake = snapshot
            flow = .extractionComplete
        } catch {
            flow = .manualTextEntry
        }

        isWorking = false
    }

    func discardActiveIntake() async {
        guard let intakeID = activeIntake?.id else {
            returnToHome()
            return
        }

        try? await pipeline.discard(intakeID: intakeID)
        returnToHome()
    }

    func finishExtraction() async {
        guard let intakeID = activeIntake?.id else {
            returnToHome()
            return
        }

        try? await pipeline.discard(intakeID: intakeID)
        returnToHome()
    }

    func showManualTextEntry() {
        flow = .manualTextEntry
    }

    func cancelHomeTextEntry() {
        flow = .home
    }

    func returnToHome() {
        activeIntake = nil
        flow = .home
    }

    private func route(for snapshot: IntakeSnapshot) {
        switch snapshot.processingState {
        case .understanding:
            flow = .extractionComplete
        case .failed:
            flow = .pipelineFailure
        case .extracting, .importing, .generatingDrafts:
            flow = .processing
        default:
            flow = .home
        }
    }
}
