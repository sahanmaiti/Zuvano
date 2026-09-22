import PhotosUI
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var coordinator: AppFlowCoordinator?
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Group {
            if let coordinator {
                @Bindable var coordinator = coordinator
                NavigationStack {
                    rootContent(coordinator: coordinator)
                }
                .photosPicker(
                    isPresented: $isPhotoPickerPresented,
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                )
                .alert(
                    coordinator.alertTitle,
                    isPresented: Binding(
                        get: { coordinator.alertMessage != nil },
                        set: { isPresented in
                            if !isPresented {
                                coordinator.dismissAlert()
                            }
                        }
                    ),
                    actions: {
                        Button("OK", role: .cancel) {
                            coordinator.dismissAlert()
                        }
                    },
                    message: {
                        Text(coordinator.alertMessage ?? "")
                    }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ZuvanoColors.contentBackground)
            }
        }
        .onAppear {
            if coordinator == nil {
                coordinator = AppFlowCoordinator(modelContainer: modelContext.container)
            }
            Task {
                await coordinator?.recoverOnLaunch()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await handlePhotoSelection(newItem)
            }
        }
    }

    @ViewBuilder
    private func rootContent(coordinator: AppFlowCoordinator) -> some View {
        switch coordinator.flow {
        case .home:
            HomeView(
                onPaste: { text in
                    coordinator.handlePastedText(text)
                },
                onChoosePhoto: {
                    isPhotoPickerPresented = true
                },
                onEnterText: {
                    coordinator.showHomeTextEntry()
                }
            )
        case .homeTextEntry:
            ManualTextEntryView(
                isSubmitting: coordinator.isWorking,
                onSubmit: { text in
                    coordinator.submitHomeText(text)
                },
                onCancel: {
                    coordinator.cancelHomeTextEntry()
                }
            )
        case .processing:
            if let intake = coordinator.activeIntake {
                ProcessingView(intake: intake) {
                    Task { await coordinator.discardActiveIntake() }
                }
            } else {
                processingPlaceholder
            }
        case .understandingResults:
            if let intake = coordinator.activeIntake {
                UnderstandingResultsView(
                    intake: intake,
                    filteredIntents: coordinator.filteredIntents
                ) {
                    Task { await coordinator.finishReview() }
                }
            } else {
                processingPlaceholder
            }
        case .pipelineFailure:
            if let intake = coordinator.activeIntake {
                PipelineFailureView(
                    intake: intake,
                    onRetry: {
                        Task { await coordinator.retryFromFailure() }
                    },
                    onEnterText: {
                        coordinator.showManualTextEntry()
                    },
                    onDiscard: {
                        Task { await coordinator.discardActiveIntake() }
                    }
                )
            } else {
                processingPlaceholder
            }
        case .manualTextEntry:
            ManualTextEntryView(
                isSubmitting: coordinator.isWorking,
                onSubmit: { text in
                    Task { await coordinator.submitManualText(text) }
                },
                onCancel: {
                    coordinator.flow = .pipelineFailure
                }
            )
        }
    }

    private var processingPlaceholder: some View {
        ProcessingView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: nil,
                temporaryImageRef: nil,
                processingState: .extracting,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            onCancel: {}
        )
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        guard let coordinator else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                selectedPhotoItem = nil
                coordinator.showPhotoImportError()
                return
            }
            selectedPhotoItem = nil
            await coordinator.startIntake(from: .pickedImage(data))
        } catch {
            selectedPhotoItem = nil
            coordinator.showPhotoImportError()
        }
    }
}
