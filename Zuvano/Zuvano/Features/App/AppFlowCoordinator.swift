import Foundation
import Observation
import SwiftData

enum AppFlow: Equatable {
    case home
    case processing
    case actionReview
    case pipelineFailure
    case manualTextEntry
    case homeTextEntry
}

@Observable
@MainActor
final class AppFlowCoordinator {
    var flow: AppFlow = .home
    var activeIntake: IntakeSnapshot?
    var drafts: [ActionDraftSnapshot] = []
    var isWorking = false
    var alertTitle = "Something went wrong"
    var alertMessage: String?

    private let pipeline: IntakePipeline
    private let store: ActionStore

    init(modelContainer: ModelContainer) {
        let store = ActionStore(modelContainer: modelContainer)
        self.store = store
        self.pipeline = IntakePipeline(store: store)
    }

    init(pipeline: IntakePipeline, store: ActionStore) {
        self.pipeline = pipeline
        self.store = store
    }

    func recoverOnLaunch() async {
        let recovered = await pipeline.recoverSessionsOnLaunch()
        guard let latest = recovered.first else { return }
        activeIntake = latest
        await resumeIntake(latest)
    }

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
        drafts = []

        do {
            let outcome = try await pipeline.startIntake(from: source)
            applyOutcome(outcome)
        } catch {
            activeIntake = nil
            drafts = []
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
            let outcome = try await pipeline.retryUnderstanding(intakeID: intakeID)
            applyOutcome(outcome)
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
            let outcome = try await pipeline.retryDraftGeneration(intakeID: intakeID)
            applyOutcome(outcome)
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
            let outcome = try await pipeline.retryExtraction(intakeID: intakeID)
            applyOutcome(outcome)
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
        flow = .processing

        do {
            let outcome = try await pipeline.applyManualText(intakeID: intakeID, text: text)
            applyOutcome(outcome)
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

    func finishReview() async {
        guard let intakeID = activeIntake?.id else {
            returnToHome()
            return
        }

        try? await pipeline.discard(intakeID: intakeID)
        returnToHome()
    }

    func updateDraft(_ draft: ActionDraftSnapshot) async {
        do {
            let updated = try await pipeline.updateDraft(draft)
            if let index = drafts.firstIndex(where: { $0.id == updated.id }) {
                drafts[index] = updated
            }
        } catch {
            alertTitle = "Couldn't save changes"
            alertMessage = "Try editing again."
        }
    }

    func skipDraft(id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        var draft = drafts[index]
        draft = ActionDraftSnapshot(
            id: draft.id,
            intakeID: draft.intakeID,
            intentKind: draft.intentKind,
            actionKind: draft.actionKind,
            title: draft.title,
            sourcePhrase: draft.sourcePhrase,
            when: draft.when,
            location: draft.location,
            person: draft.person,
            notes: draft.notes,
            confidence: draft.confidence,
            ambiguous: draft.ambiguous,
            confirmationState: .rejected,
            executionState: draft.executionState,
            nativeIdentifier: draft.nativeIdentifier,
            executionError: draft.executionError,
            createdAt: draft.createdAt,
            updatedAt: .now
        )
        await updateDraft(draft)
    }

    func restoreDraft(id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        var draft = drafts[index]
        draft = ActionDraftSnapshot(
            id: draft.id,
            intakeID: draft.intakeID,
            intentKind: draft.intentKind,
            actionKind: draft.actionKind,
            title: draft.title,
            sourcePhrase: draft.sourcePhrase,
            when: draft.when,
            location: draft.location,
            person: draft.person,
            notes: draft.notes,
            confidence: draft.confidence,
            ambiguous: draft.ambiguous,
            confirmationState: .pending,
            executionState: draft.executionState,
            nativeIdentifier: draft.nativeIdentifier,
            executionError: draft.executionError,
            createdAt: draft.createdAt,
            updatedAt: .now
        )
        await updateDraft(draft)
    }

    func createDraft(id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let draft = drafts[index]
        guard DraftValidator.canCreate(draft) else { return }

        let confirmed = ActionDraftSnapshot(
            id: draft.id,
            intakeID: draft.intakeID,
            intentKind: draft.intentKind,
            actionKind: draft.actionKind,
            title: draft.title,
            sourcePhrase: draft.sourcePhrase,
            when: draft.when,
            location: draft.location,
            person: draft.person,
            notes: draft.notes,
            confidence: draft.confidence,
            ambiguous: draft.ambiguous,
            confirmationState: .confirmed,
            executionState: draft.executionState,
            nativeIdentifier: draft.nativeIdentifier,
            executionError: draft.executionError,
            createdAt: draft.createdAt,
            updatedAt: .now
        )
        await updateDraft(confirmed)
    }

    func createAllReady() async {
        for draft in drafts where DraftValidator.canCreate(draft) {
            await createDraft(id: draft.id)
        }
    }

    func createSelected(ids: [UUID]) async {
        for id in ids {
            await createDraft(id: id)
        }
    }

    func showManualTextEntry() {
        flow = .manualTextEntry
    }

    func cancelHomeTextEntry() {
        flow = .home
    }

    func returnToHome() {
        activeIntake = nil
        drafts = []
        flow = .home
    }

    private func resumeIntake(_ snapshot: IntakeSnapshot) async {
        switch snapshot.processingState {
        case .understanding:
            isWorking = true
            flow = .processing
            do {
                let outcome = try await pipeline.continueUnderstanding(intakeID: snapshot.id)
                applyOutcome(outcome)
            } catch {
                activeIntake = snapshot
                route(for: snapshot)
            }
            isWorking = false
        case .readyForReview:
            activeIntake = snapshot
            do {
                drafts = try await pipeline.loadDrafts(for: snapshot.id)
            } catch {
                drafts = []
            }
            route(for: snapshot)
        default:
            route(for: snapshot)
        }
    }

    private func applyOutcome(_ outcome: ReviewOutcome) {
        activeIntake = outcome.snapshot
        drafts = outcome.drafts
        route(for: outcome.snapshot)
    }

    private func route(for snapshot: IntakeSnapshot) {
        switch snapshot.processingState {
        case .readyForReview:
            flow = .actionReview
        case .failed:
            flow = .pipelineFailure
        case .understanding, .extracting, .importing, .generatingDrafts:
            flow = .processing
        default:
            flow = .home
        }
    }
}
