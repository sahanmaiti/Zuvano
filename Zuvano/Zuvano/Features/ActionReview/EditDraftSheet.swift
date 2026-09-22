import SwiftUI

struct EditDraftSheet: View {
    let draft: ActionDraftSnapshot
    let onSave: (ActionDraftSnapshot) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var actionKind: ActionKind
    @State private var startDate: Date
    @State private var hasStartDate: Bool
    @State private var endDate: Date
    @State private var hasEndDate: Bool
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var location: String
    @State private var person: String
    @State private var notes: String
    @State private var isAmbiguous: Bool
    @State private var showDiscardConfirmation = false

    init(draft: ActionDraftSnapshot, onSave: @escaping (ActionDraftSnapshot) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _title = State(initialValue: draft.title)
        _actionKind = State(initialValue: draft.actionKind)
        _startDate = State(initialValue: draft.when?.startDate ?? .now)
        _hasStartDate = State(initialValue: draft.when?.startDate != nil)
        _endDate = State(initialValue: draft.when?.endDate ?? Date.now.addingTimeInterval(3600))
        _hasEndDate = State(initialValue: draft.when?.endDate != nil)
        _dueDate = State(initialValue: draft.when?.startDate ?? .now)
        _hasDueDate = State(initialValue: draft.when?.startDate != nil)
        _location = State(initialValue: draft.location ?? "")
        _person = State(initialValue: draft.person ?? "")
        _notes = State(initialValue: draft.notes ?? "")
        _isAmbiguous = State(initialValue: draft.ambiguous)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $actionKind) {
                        Text("Calendar Event").tag(ActionKind.calendarEvent)
                        Text("Reminder").tag(ActionKind.reminder)
                    }
                }

                if actionKind == .calendarEvent {
                    Section("When") {
                        Toggle("Starts", isOn: $hasStartDate)
                        if hasStartDate {
                            DatePicker("Start", selection: $startDate)
                            Toggle("Ends", isOn: $hasEndDate)
                            if hasEndDate {
                                DatePicker("End", selection: $endDate)
                            }
                        }
                    }
                } else {
                    Section("When") {
                        Toggle("Due", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("Due", selection: $dueDate)
                        }
                    }
                }

                Section("Details") {
                    TextField("Location", text: $location)
                    TextField("Person", text: $person)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let rawExpression = draft.when?.rawExpression, !rawExpression.isEmpty {
                    Section {
                        Text("Original: \(rawExpression)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if actionKind == .calendarEvent && !hasStartDate {
                    Section {
                        Text("Add a start time to create this event.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        title != draft.title
            || actionKind != draft.actionKind
            || location != (draft.location ?? "")
            || person != (draft.person ?? "")
            || notes != (draft.notes ?? "")
    }

    private func save() {
        let when: ActionDateTime?
        if actionKind == .calendarEvent {
            when = hasStartDate
                ? ActionDateTime(
                    rawExpression: draft.when?.rawExpression ?? "",
                    startDate: startDate,
                    endDate: hasEndDate ? endDate : nil,
                    ambiguous: isAmbiguous
                )
                : ActionDateTime(
                    rawExpression: draft.when?.rawExpression ?? "",
                    ambiguous: isAmbiguous
                )
        } else {
            when = hasDueDate
                ? ActionDateTime(
                    rawExpression: draft.when?.rawExpression ?? "",
                    startDate: dueDate,
                    ambiguous: isAmbiguous
                )
                : nil
        }

        let resolvedAmbiguous = isAmbiguous && !(hasStartDate || hasDueDate)

        let updated = ActionDraftSnapshot(
            id: draft.id,
            intakeID: draft.intakeID,
            intentKind: draft.intentKind,
            actionKind: actionKind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            sourcePhrase: draft.sourcePhrase,
            when: when,
            location: location.isEmpty ? nil : location,
            person: person.isEmpty ? nil : person,
            notes: notes.isEmpty ? nil : notes,
            confidence: draft.confidence,
            ambiguous: resolvedAmbiguous,
            confirmationState: draft.confirmationState,
            executionState: draft.executionState,
            nativeIdentifier: draft.nativeIdentifier,
            executionError: draft.executionError,
            createdAt: draft.createdAt,
            updatedAt: .now
        )
        onSave(updated)
        dismiss()
    }
}
