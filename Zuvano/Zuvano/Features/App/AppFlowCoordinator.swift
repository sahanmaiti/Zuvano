import Foundation
import Observation
import SwiftData
import UIKit

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
    var deniedPermissionKinds: Set<PermissionKind> = []
    var showPermissionPreAlert = false
    var pendingPermissionActionKinds: Set<ActionKind> = []
    var pendingCreateDraftIDs: [UUID] = []
    var lastExecutionAnnouncement: String?
    var dismissedFailedDraftIDs: Set<UUID> = []

    private let pipeline: IntakePipeline
    private let store: ActionStore
    private let executionService: DraftExecutionService
    private let handoffStore: ShareHandoffStore
    private var hasShownPermissionPreAlert = false
    private var isIngestingHandoff = false
    private var executingDraftIDs: Set<UUID> = []
    private var runningCreateOperation: Task<Void, Never>?

    init(modelContainer: ModelContainer) {
        let store = ActionStore(modelContainer: modelContainer)
        self.store = store
        self.pipeline = IntakePipeline(store: store)
        self.executionService = DraftExecutionService()
        self.handoffStore = ShareHandoffStore()
    }

    init(
        pipeline: IntakePipeline,
        store: ActionStore,
        executionService: DraftExecutionService,
        handoffStore: ShareHandoffStore = ShareHandoffStore()
    ) {
        self.pipeline = pipeline
        self.store = store
        self.executionService = executionService
        self.handoffStore = handoffStore
    }

    var canFinishReview: Bool {
        guard !drafts.isEmpty else { return true }
        return drafts.allSatisfy { draft in
            DraftExecutionEligibility.isTerminal(
                draft,
                failureDismissed: dismissedFailedDraftIDs.contains(draft.id)
            )
        }
    }

    func recoverOnLaunch() async {
        handoffStore.deleteStale()

        let pendingHandoffs = handoffStore.pendingTokens()
        if let token = pendingHandoffs.last {
            await ingestHandoff(token: token)
            return
        }

        let recovered = await pipeline.recoverSessionsOnLaunch()
        guard let latest = recovered.first else { return }
        activeIntake = latest
        await resumeIntake(latest)
    }

    func handleHandoffURL(_ url: URL) {
        guard let token = ShareHandoffStore.parseHandoffToken(from: url) else {
            showShareHandoffFailure()
            return
        }

        Task {
            await ingestHandoff(token: token)
        }
    }

    func dismissFailedDraft(id: UUID) {
        guard let draft = drafts.first(where: { $0.id == id }),
              draft.executionState == .failed else {
            return
        }
        dismissedFailedDraftIDs.insert(id)
    }

    private func ingestHandoff(token: UUID) async {
        guard !isIngestingHandoff else { return }
        isIngestingHandoff = true
        defer { isIngestingHandoff = false }

        do {
            let source = try handoffStore.load(token: token)
            handoffStore.delete(token: token)
            await startIntake(from: source)
        } catch {
            handoffStore.delete(token: token)
            showShareHandoffFailure()
        }
    }

    private func showShareHandoffFailure() {
        flow = .home
        alertTitle = "Couldn't open that share"
        alertMessage = "Try pasting the text instead."
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
        deniedPermissionKinds = []

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
        guard canFinishReview else { return }

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
            refreshDeniedPermissions()
        } catch {
            alertTitle = "Couldn't save changes"
            alertMessage = "Try editing again."
        }
    }

    func skipDraft(id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let draft = drafts[index]
        guard draft.confirmationState == .pending
            || (draft.confirmationState == .confirmed && draft.executionState == .notStarted) else {
            return
        }
        await updateDraft(draft.updating(confirmationState: .rejected))
    }

    func restoreDraft(id: UUID) async {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let draft = drafts[index]
        await updateDraft(draft.updating(confirmationState: .pending))
    }

    func createDraft(id: UUID) async {
        await serializedCreateOperation { [self] in
            if let draft = self.drafts.first(where: { $0.id == id }),
               draft.confirmationState == .confirmed,
               draft.executionState == .notStarted {
                await self.resumeExecution(id: id)
                return
            }
            await self.createDrafts(ids: [id])
        }
    }

    func createAllReady() async {
        await serializedCreateOperation { [self] in
            let ids = self.drafts.filter { DraftValidator.canCreate($0) }.map(\.id)
            await self.createDrafts(ids: ids)
        }
    }

    func createSelected(ids: [UUID]) async {
        await serializedCreateOperation { [self] in
            await self.createDrafts(ids: ids)
        }
    }

    func retryExecution(id: UUID) async {
        dismissedFailedDraftIDs.remove(id)
        guard let draft = drafts.first(where: { $0.id == id }) else { return }
        if DraftExecutionEligibility.canRetry(draft) || canResumeExecution(draft) {
            await executeDraft(draft)
        }
    }

    func resumeExecution(id: UUID) async {
        guard let draft = drafts.first(where: { $0.id == id }),
              canResumeExecution(draft) else {
            return
        }

        let permissionKind = DraftExecutionService.permissionKind(for: draft.actionKind)
        let outcome = await executionService.ensurePermissions(for: [draft.actionKind])
        deniedPermissionKinds = outcome.deniedKinds
        refreshDeniedPermissions()

        guard !outcome.deniedKinds.contains(permissionKind) else { return }
        await executeDraft(draft)
    }

    private func canResumeExecution(_ draft: ActionDraftSnapshot) -> Bool {
        draft.confirmationState == .confirmed
            && draft.executionState == .notStarted
            && draft.nativeIdentifier == nil
            && DraftExecutionEligibility.canExecute(draft)
    }

    func continueAfterPermissionPreAlert() async {
        showPermissionPreAlert = false
        let ids = pendingCreateDraftIDs
        pendingCreateDraftIDs = []
        let kinds = pendingPermissionActionKinds
        pendingPermissionActionKinds = []

        await serializedCreateOperation { [self] in
            await self.performCreate(draftIDs: ids, actionKinds: kinds)
        }
    }

    func cancelPermissionPreAlert() {
        showPermissionPreAlert = false
        pendingCreateDraftIDs = []
        pendingPermissionActionKinds = []
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
        deniedPermissionKinds = []
        dismissedFailedDraftIDs = []
        flow = .home
    }

    private func serializedCreateOperation(_ operation: @escaping () async -> Void) async {
        let previous = runningCreateOperation
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        runningCreateOperation = task
        await task.value
    }

    private func createDrafts(ids: [UUID]) async {
        let eligibleIDs = ids.filter { id in
            guard let draft = drafts.first(where: { $0.id == id }) else { return false }
            return DraftValidator.canCreate(draft)
        }
        guard !eligibleIDs.isEmpty else { return }

        let actionKinds = Set(eligibleIDs.compactMap { id in
            drafts.first(where: { $0.id == id })?.actionKind
        })

        let currentlyDenied = executionService.currentDeniedKinds(for: actionKinds)

        if !currentlyDenied.isEmpty && !hasShownPermissionPreAlert {
            hasShownPermissionPreAlert = true
            pendingCreateDraftIDs = eligibleIDs
            pendingPermissionActionKinds = actionKinds
            showPermissionPreAlert = true
            return
        }

        await performCreate(draftIDs: eligibleIDs, actionKinds: actionKinds)
    }

    private func performCreate(draftIDs: [UUID], actionKinds: Set<ActionKind>) async {
        let permissionOutcome = await executionService.ensurePermissions(for: actionKinds)
        deniedPermissionKinds = permissionOutcome.deniedKinds
        refreshDeniedPermissions()

        for id in draftIDs {
            guard let index = drafts.firstIndex(where: { $0.id == id }),
                  DraftValidator.canCreate(drafts[index]) else {
                continue
            }

            let draft = drafts[index]
            let confirmed = draft.updating(
                confirmationState: .confirmed,
                executionState: .notStarted,
                executionError: .some(nil)
            )
            await persistDraft(confirmed)
            refreshDeniedPermissions()

            let permissionKind = DraftExecutionService.permissionKind(for: draft.actionKind)
            if permissionOutcome.deniedKinds.contains(permissionKind) {
                continue
            }

            await executeDraft(drafts.first(where: { $0.id == id }) ?? confirmed)
        }
    }

    private func executeDraft(_ draft: ActionDraftSnapshot) async {
        guard beginExecutionClaim(for: draft) else { return }
        defer { endExecutionClaim(draft.id) }

        let baseline = drafts.first(where: { $0.id == draft.id }) ?? draft

        guard baseline.nativeIdentifier == nil else { return }
        guard DraftExecutionEligibility.canExecute(baseline) || DraftExecutionEligibility.canRetry(baseline) else {
            return
        }

        let executing = baseline.updating(
            confirmationState: .confirmed,
            executionState: .executing,
            executionError: .some(nil)
        )
        await persistDraft(executing)

        guard let current = drafts.first(where: { $0.id == draft.id }) else {
            await persistExecutionFailure(
                for: baseline,
                reason: .persistenceFailed
            )
            return
        }

        if current.executionState == .executed {
            return
        }

        if let nativeIdentifier = current.nativeIdentifier {
            let executed = current.updating(
                executionState: .executed,
                nativeIdentifier: .some(nativeIdentifier),
                executionError: .some(nil)
            )
            await persistDraft(executed)
            announceSuccess(for: executed)
            return
        }

        guard current.executionState == .executing else {
            await persistExecutionFailure(
                for: current,
                reason: .persistenceFailed
            )
            return
        }

        do {
            try Task.checkCancellation()
            let result = try await executionService.execute(current)
            let executed = current.updating(
                executionState: .executed,
                nativeIdentifier: .some(result.nativeIdentifier),
                executionError: .some(nil)
            )
            await persistDraft(executed)
            announceSuccess(for: executed)
        } catch {
            let reason = executionService.persistableFailureReason(
                for: error,
                actionKind: current.actionKind
            )
            await persistExecutionFailure(for: current, reason: reason)
            announceFailure(for: current.updating(executionState: .failed, executionError: .some(reason)))
        }
    }

    private func beginExecutionClaim(for draft: ActionDraftSnapshot) -> Bool {
        guard !executingDraftIDs.contains(draft.id) else { return false }
        guard DraftExecutionEligibility.canExecute(draft) || DraftExecutionEligibility.canRetry(draft) else {
            return false
        }
        executingDraftIDs.insert(draft.id)
        return true
    }

    private func endExecutionClaim(_ draftID: UUID) {
        executingDraftIDs.remove(draftID)
    }

    private func persistExecutionFailure(
        for draft: ActionDraftSnapshot,
        reason: FailureReason
    ) async {
        EventKitExecutionDiagnostics.boundary(
            "persistFailure.before",
            draftID: draft.id,
            entity: draft.actionKind == .calendarEvent ? "event" : "reminder"
        )
        let latest = drafts.first(where: { $0.id == draft.id }) ?? draft
        guard latest.executionState == .executing else { return }

        let failed = latest.updating(
            executionState: .failed,
            executionError: .some(reason)
        )
        await persistDraft(failed)
        EventKitExecutionDiagnostics.boundary(
            "persistFailure.after",
            draftID: draft.id,
            entity: draft.actionKind == .calendarEvent ? "event" : "reminder"
        )
    }

    private func persistDraft(_ draft: ActionDraftSnapshot) async {
        do {
            let updated = try await pipeline.updateDraft(draft)
            if let index = drafts.firstIndex(where: { $0.id == updated.id }) {
                drafts[index] = updated
            }
        } catch {
            alertTitle = "Couldn't save changes"
            alertMessage = "Try again."
        }
    }

    private func refreshDeniedPermissions() {
        let actionKinds = Set(
            drafts
                .filter { $0.confirmationState == .confirmed && $0.executionState == .notStarted }
                .map(\.actionKind)
        )
        deniedPermissionKinds = executionService.currentDeniedKinds(for: actionKinds)
    }

    private func announceSuccess(for draft: ActionDraftSnapshot) {
        ZuvanoHaptics.success()
        let destination = draft.actionKind == .calendarEvent ? "Calendar" : "Reminders"
        lastExecutionAnnouncement = "Added to \(destination)."
    }

    private func announceFailure(for draft: ActionDraftSnapshot) {
        ZuvanoHaptics.failure()
        let destination = draft.actionKind == .calendarEvent ? "Calendar" : "Reminders"
        lastExecutionAnnouncement = "Couldn't add to \(destination)."
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
                refreshDeniedPermissions()
            } catch {
                drafts = []
            }
            route(for: snapshot)
        default:
            route(for: snapshot)
        }
    }

    private func applyOutcome(_ outcome: ReviewOutcome) {
        if flow == .processing && outcome.snapshot.processingState == .readyForReview {
            ZuvanoHaptics.selection()
        }
        activeIntake = outcome.snapshot
        drafts = outcome.drafts
        refreshDeniedPermissions()
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
