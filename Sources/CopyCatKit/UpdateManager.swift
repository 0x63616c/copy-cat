import AppKit
import Combine
import Sparkle

/// Sparkle owns scheduling, preferences, signature validation, and installation.
@MainActor
final class UpdateManager: ObservableObject {
    @Published private(set) var canCheck = false
    @Published private(set) var isAvailable = false
    @Published private(set) var automaticallyChecks = true
    @Published private(set) var automaticallyInstalls = false
    @Published private(set) var error: String?
    private var controller: SPUStandardUpdaterController?
    private var observations = Set<AnyCancellable>()

    func start() {
        guard controller == nil, Bundle.main.bundleIdentifier == "com.0x63616c.copy-cat" else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        do {
            try controller.updater.start()
            isAvailable = true
        } catch {
            self.error = "Updates are unavailable. \(error.localizedDescription)"
        }
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main).sink { [weak self] in self?.canCheck = $0 }.store(in: &observations)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main).sink { [weak self] in self?.automaticallyChecks = $0 }.store(in: &observations)
        controller.updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: RunLoop.main).sink { [weak self] in self?.automaticallyInstalls = $0 }.store(in: &observations)
    }

    func checkForUpdates() {
        guard canCheck else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticallyInstalls(_ enabled: Bool) {
        controller?.updater.automaticallyDownloadsUpdates = enabled
    }
}
