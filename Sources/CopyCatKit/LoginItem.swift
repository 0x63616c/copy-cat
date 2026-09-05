import ServiceManagement
import SwiftUI

/// macOS owns this preference; never duplicate it in config.json.
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var error: String?
    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void

    init(
        readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
    ) {
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        status = readStatus()
    }

    var isOn: Bool { status == .enabled || status == .requiresApproval }

    func refresh() { status = readStatus() }

    func setEnabled(_ enabled: Bool) {
        error = nil
        do {
            if enabled { try register() } else { try unregister() }
        } catch {
            self.error = "Couldn’t change Open at Login. \(error.localizedDescription)"
        }
        refresh()
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
