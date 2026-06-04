import Testing
@testable import CopyCatCore

@Test func versionIsNonEmpty() {
    #expect(!CopyCatCore.version.isEmpty)
}
