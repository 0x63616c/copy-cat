import Foundation
import Testing
@testable import CopyCatCore

@Test func screenshotIdIsItsPath() {
    let url = URL(fileURLWithPath: "/tmp/Screenshot 2026-06-04 at 10.00.00.png")
    let shot = Screenshot(url: url, captureDate: Date(timeIntervalSince1970: 100))
    #expect(shot.id == url.path)
}

@Test func screenshotsWithSamePathAreEqual() {
    let url = URL(fileURLWithPath: "/tmp/a.png")
    let a = Screenshot(url: url, captureDate: Date(timeIntervalSince1970: 1))
    let b = Screenshot(url: url, captureDate: Date(timeIntervalSince1970: 2))
    #expect(a == b) // identity is the path, not the date
}
