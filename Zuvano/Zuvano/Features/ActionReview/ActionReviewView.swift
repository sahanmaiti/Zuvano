import SwiftUI

struct ActionReviewView: View {
    let intake: IntakeSnapshot
    let drafts: [ActionDraftSnapshot]
    let deniedPermissionKinds: Set<PermissionKind>
    let canFinish: Bool
    let showPermissionPreAlert: Bool
    let permissionPreAlertMessage: String
    let onUpdateDraft: (ActionDraftSnapshot) -> Void
    let onSkip: (UUID) -> Void
    let onRestore: (UUID) -> Void
    let onCreate: (UUID) -> Void
    let onCreateAllReady: () -> Void
    let onCreateSelected: ([UUID]) -> Void
    let onRetry: (UUID) -> Void
    let onDismissFailure: (UUID) -> Void
    let dismissedFailedDraftIDs: Set<UUID>
    let onOpenSettings: () -> Void
    let onContinuePermissionPreAlert: () -> Void
    let onCancelPermissionPreAlert: () -> Void
    let onDone: () -> Void
    let onDiscard: () -> Void

    @State private var editingDraft: ActionDraftSnapshot?
    @State private var showSourceText = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showDiscardConfirmation = false

    private var pendingDrafts: [ActionDraftSnapshot] {
        drafts.filter { $0.confirmationState == .pending }
    }

    private var readyCount: Int {
        pendingDrafts.filter { DraftValidator.canCreate($0) }.count
    }

    private var invalidCount: Int {
        pendingDrafts.filter {
            switch DraftValidator.validationConcern(for: $0) {
            case .needsStartTime, .needsTitle: return true
            default: return false
            }
        }.count
    }

    private var allSkipped: Bool {
        !drafts.isEmpty && drafts.allSatisfy { $0.confirmationState == .rejected }
    }

    var body: some View {
        Group {
            if drafts.isEmpty {
                emptyState
            } else {
                reviewList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zuvanoContentBackground()
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .sheet(item: $editingDraft) { draft in
            EditDraftSheet(draft: draft) { updated in
                onUpdateDraft(updated)
            }
        }
        .sheet(isPresented: $showSourceText) {
            if let text = intake.extractedText {
                SourceTextSheet(extractedText: text)
            }
        }
        .alert("Allow access to continue", isPresented: Binding(
            get: { showPermissionPreAlert },
            set: { isPresented in
                if !isPresented { onCancelPermissionPreAlert() }
            }
        )) {
            Button("Continue", action: onContinuePermissionPreAlert)
            Button("Cancel", role: .cancel, action: onCancelPermissionPreAlert)
        } message: {
            Text(permissionPreAlertMessage)
        }
        .confirmationDialog(
            "Discard this conversation?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive, action: onDiscard)
            Button("Keep Reviewing", role: .cancel) {}
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to create", systemImage: "tray")
        } description: {
            Text("Zuvano didn't find anything for you to add to Calendar or Reminders.")
                .zuvanoMetaStyle()
        } actions: {
            Button("Done", action: onDone)
                .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                .accessibilityHint("Returns home and removes this conversation from Zuvano.")
        }
        .padding(.horizontal)
    }

    private func isSelectableInBatch(_ draft: ActionDraftSnapshot) -> Bool {
        draft.confirmationState == .pending && DraftValidator.canCreate(draft)
    }

    private func toggleSelection(for draftID: UUID) {
        if selectedIDs.contains(draftID) {
            selectedIDs.remove(draftID)
        } else {
            selectedIDs.insert(draftID)
        }
    }

    private var reviewList: some View {
        List {
            Section {
                HStack {
                    Text(headerCopy)
                        .zuvanoContentHeadlineStyle()
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    if intake.extractedText != nil {
                        Button("View source") {
                            showSourceText = true
                        }
                        .font(.subheadline)
                    }
                }
                .listRowBackground(Color.clear)

                if allSkipped {
                    Text("Every proposal was skipped.")
                        .zuvanoMetaStyle()
                        .listRowBackground(Color.clear)
                }

                if invalidCount > 0 && readyCount > 0 {
                    Text("\(invalidCount) need a start time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                if !deniedPermissionKinds.isEmpty {
                    permissionBanner
                }
            }

            Section {
                ForEach(drafts) { draft in
                    HStack(alignment: .top, spacing: ZuvanoSpacing.footnoteTop) {
                        if isSelecting {
                            if isSelectableInBatch(draft) {
                                Button {
                                    toggleSelection(for: draft.id)
                                } label: {
                                    Image(systemName: selectedIDs.contains(draft.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedIDs.contains(draft.id) ? Color.accentColor : .secondary)
                                }
                                .buttonStyle(.plain)
                                .frame(width: ZuvanoSpacing.minimumTouchTarget, height: ZuvanoSpacing.minimumTouchTarget)
                                .accessibilityLabel(
                                    selectedIDs.contains(draft.id)
                                        ? "Selected \(draft.title)"
                                        : "Not selected \(draft.title)"
                                )
                                .accessibilityHint("Double tap to toggle selection for batch create.")
                            } else {
                                Color.clear
                                    .frame(width: ZuvanoSpacing.minimumTouchTarget, height: ZuvanoSpacing.minimumTouchTarget)
                                    .accessibilityHidden(true)
                            }
                        }

                        DraftRowView(
                        draft: draft,
                        isPermissionDenied: isPermissionDenied(for: draft),
                        isFailureDismissed: dismissedFailedDraftIDs.contains(draft.id),
                        onEdit: { editingDraft = draft },
                        onCreate: { onCreate(draft.id) },
                        onSkip: { onSkip(draft.id) },
                        onRestore: { onRestore(draft.id) },
                        onRetry: { onRetry(draft.id) },
                        onDismissFailure: { onDismissFailure(draft.id) },
                        onOpenSettings: onOpenSettings
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if draft.confirmationState == .rejected {
                            Button("Restore") { onRestore(draft.id) }
                                .tint(.blue)
                        } else if DraftExecutionEligibility.canRetry(draft) {
                            Button("Retry") { onRetry(draft.id) }
                                .tint(.blue)
                        } else if draft.confirmationState == .pending
                                    || (draft.confirmationState == .confirmed && draft.executionState == .notStarted) {
                            Button("Skip") { onSkip(draft.id) }
                                .tint(.orange)
                        }
                    }
                    .contextMenu {
                        if DraftValidator.canCreate(draft) {
                            Button("Create") { onCreate(draft.id) }
                        }
                        if DraftExecutionEligibility.canRetry(draft) {
                            Button("Retry") { onRetry(draft.id) }
                        }
                        Button("Edit") { editingDraft = draft }
                        if draft.confirmationState == .rejected {
                            Button("Restore") { onRestore(draft.id) }
                        } else if draft.confirmationState == .pending
                                    || (draft.confirmationState == .confirmed && draft.executionState == .notStarted) {
                            Button("Skip") { onSkip(draft.id) }
                        }
                        if intake.extractedText != nil {
                            Button("View source") { showSourceText = true }
                        }
                    }
                }
            }

            Section {
                Button("Done", action: onDone)
                    .frame(maxWidth: .infinity, minHeight: ZuvanoSpacing.minimumTouchTarget)
                    .disabled(!canFinish)
                    .accessibilityHint(
                        canFinish
                            ? "Returns home and removes this conversation from Zuvano."
                            : "Finish creating, skipping, or resolving failed actions first."
                    )
            }
        }
        .listStyle(.insetGrouped)
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if deniedPermissionKinds.contains(.calendar) {
                Text("Calendar access is off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if deniedPermissionKinds.contains(.reminders) {
                Text("Reminders access is off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Open Settings", action: onOpenSettings)
                .font(.footnote)
                .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
        }
        .listRowBackground(Color.clear)
    }

    private func isPermissionDenied(for draft: ActionDraftSnapshot) -> Bool {
        guard draft.confirmationState == .confirmed, draft.executionState == .notStarted else {
            return false
        }
        let kind = DraftExecutionService.permissionKind(for: draft.actionKind)
        return deniedPermissionKinds.contains(kind)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                if isSelecting {
                    isSelecting = false
                    selectedIDs.removeAll()
                } else {
                    showDiscardConfirmation = true
                }
            }
            .accessibilityHint(
                isSelecting
                    ? "Exits selection mode."
                    : "Stops review and discards this conversation."
            )
        }

        if !drafts.isEmpty && readyCount > 0 {
            ToolbarItem(placement: .primaryAction) {
                if readyCount == 1, let draft = pendingDrafts.first(where: { DraftValidator.canCreate($0) }) {
                    Button(createButtonTitle(for: [draft])) { onCreate(draft.id) }
                        .disabled(!DraftValidator.canCreate(draft))
                } else if readyCount > 1 {
                    Button(createAllTitle) { onCreateAllReady() }
                }
            }
        }

        if drafts.count > 1 && readyCount > 1 && !isSelecting {
            ToolbarItem(placement: .automatic) {
                Button("Select") {
                    isSelecting = true
                }
            }
        }

        if isSelecting && !selectedIDs.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Button("Create Selected (\(selectedIDs.count))") {
                    onCreateSelected(Array(selectedIDs))
                    isSelecting = false
                    selectedIDs.removeAll()
                }
            }
        }
    }

    private var headerCopy: String {
        let count = drafts.filter { $0.confirmationState != .rejected && $0.executionState != .executed }.count
        if count == 1 {
            return "1 proposed action"
        }
        return "\(count) proposed actions"
    }

    private var createAllTitle: String {
        let ready = pendingDrafts.filter { DraftValidator.canCreate($0) }
        if invalidCount > 0 {
            return "Create \(readyCount) Ready"
        }
        return createButtonTitle(for: ready)
    }

    private func createButtonTitle(for readyDrafts: [ActionDraftSnapshot]) -> String {
        let calendarCount = readyDrafts.filter { $0.actionKind == .calendarEvent }.count
        let reminderCount = readyDrafts.filter { $0.actionKind == .reminder }.count

        switch (calendarCount, reminderCount) {
        case (1, 0):
            return "Add to Calendar"
        case (0, 1):
            return "Add Reminder"
        case (let c, let r) where c > 0 && r > 0:
            if r == 1 {
                return "Create \(c) Events & 1 Reminder"
            }
            return "Create \(c) Events & \(r) Reminders"
        case (let c, 0) where c > 1:
            return "Add to Calendar"
        case (0, let r) where r > 1:
            return "Add Reminder"
        default:
            return "Create"
        }
    }
}

#Preview("Multiple Drafts") {
    NavigationStack {
        ActionReviewView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Sample conversation.",
                temporaryImageRef: nil,
                processingState: .readyForReview,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            drafts: [
                ActionDraftSnapshot(
                    intakeID: UUID(),
                    intentKind: .meeting,
                    actionKind: .calendarEvent,
                    title: "Meeting",
                    sourcePhrase: "Let's meet Friday around 7 at the café near campus.",
                    when: ActionDateTime(rawExpression: "Friday, around 7", startDate: .now, ambiguous: true),
                    location: "café near campus",
                    confidence: .high,
                    ambiguous: true
                ),
                ActionDraftSnapshot(
                    intakeID: UUID(),
                    intentKind: .reminder,
                    actionKind: .reminder,
                    title: "Call Arjun",
                    sourcePhrase: "Remind me Thursday to call Arjun.",
                    when: ActionDateTime(rawExpression: "Thursday", startDate: .now),
                    person: "Arjun",
                    confidence: .high
                )
            ],
            deniedPermissionKinds: [],
            canFinish: false,
            showPermissionPreAlert: false,
            permissionPreAlertMessage: "",
            onUpdateDraft: { _ in },
            onSkip: { _ in },
            onRestore: { _ in },
            onCreate: { _ in },
            onCreateAllReady: {},
            onCreateSelected: { _ in },
            onRetry: { _ in },
            onDismissFailure: { _ in },
            dismissedFailedDraftIDs: [],
            onOpenSettings: {},
            onContinuePermissionPreAlert: {},
            onCancelPermissionPreAlert: {},
            onDone: {},
            onDiscard: {}
        )
    }
}

#Preview("Nothing Actionable") {
    NavigationStack {
        ActionReviewView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Did you send the file?",
                temporaryImageRef: nil,
                processingState: .readyForReview,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            drafts: [],
            deniedPermissionKinds: [],
            canFinish: true,
            showPermissionPreAlert: false,
            permissionPreAlertMessage: "",
            onUpdateDraft: { _ in },
            onSkip: { _ in },
            onRestore: { _ in },
            onCreate: { _ in },
            onCreateAllReady: {},
            onCreateSelected: { _ in },
            onRetry: { _ in },
            onDismissFailure: { _ in },
            dismissedFailedDraftIDs: [],
            onOpenSettings: {},
            onContinuePermissionPreAlert: {},
            onCancelPermissionPreAlert: {},
            onDone: {},
            onDiscard: {}
        )
    }
}
