import Foundation
import Testing
@testable import CopyCatCore

@Test func previewPrefersHoverThenNewest() {
    let a = Screenshot(url: URL(fileURLWithPath: "/a"), captureDate: Date(timeIntervalSince1970: 1))
    let b = Screenshot(url: URL(fileURLWithPath: "/b"), captureDate: Date(timeIntervalSince1970: 2))
    #expect(previewTarget(hovered: a, newest: b) == a)
    #expect(previewTarget(hovered: nil, newest: b) == b)
    #expect(previewTarget(hovered: nil, newest: nil) == nil)
}

@Test func badgeIsBlackCatNormallyAndWarningWhenNoAccess() {
    #expect(badgeSymbolName(for: .normal) == "cat.fill")
    #expect(badgeSymbolName(for: .empty) == "cat.fill")
    #expect(badgeSymbolName(for: .noAccess) == "exclamationmark.triangle.fill")
}
