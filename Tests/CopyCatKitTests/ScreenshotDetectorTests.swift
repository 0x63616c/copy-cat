import Foundation
import Testing
@testable import CopyCatKit

@Test @MainActor
func changingWatchFolderCancelsSourceWithoutExecutorTrap() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("copycat-detector-\(UUID().uuidString)", isDirectory: true)
    let first = root.appendingPathComponent("first", isDirectory: true)
    let second = root.appendingPathComponent("second", isDirectory: true)

    try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let detector = ScreenshotDetector(folderPath: first.path)
    detector.start()
    detector.update(folderPath: second.path)
    detector.stop()

    // Dispatch source cancellation is asynchronous. Give both cancel handlers
    // time to execute on the detector's background scan queue.
    try await Task.sleep(for: .milliseconds(100))
}
