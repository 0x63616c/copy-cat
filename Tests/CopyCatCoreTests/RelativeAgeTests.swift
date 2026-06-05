import XCTest
@testable import CopyCatCore

final class RelativeAgeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000_000)

    private func age(secondsAgo: Double) -> String {
        compactRelativeAge(from: now.addingTimeInterval(-secondsAgo), now: now)
    }

    func testJustNow() {
        XCTAssertEqual(age(secondsAgo: 0), "now")
        XCTAssertEqual(age(secondsAgo: 59), "now")
    }

    func testMinutes() {
        XCTAssertEqual(age(secondsAgo: 60), "1m")
        XCTAssertEqual(age(secondsAgo: 59 * 60), "59m")
    }

    func testHours() {
        XCTAssertEqual(age(secondsAgo: 3600), "1h")
        XCTAssertEqual(age(secondsAgo: 23 * 3600), "23h")
    }

    func testDays() {
        XCTAssertEqual(age(secondsAgo: 86_400), "1d")
        XCTAssertEqual(age(secondsAgo: 7 * 86_400), "7d")
        XCTAssertEqual(age(secondsAgo: 33 * 86_400), "33d")
        XCTAssertEqual(age(secondsAgo: 99 * 86_400), "99d")
    }

    func testMonthsAndYears() {
        XCTAssertEqual(age(secondsAgo: 100 * 86_400), "3mo")
        XCTAssertEqual(age(secondsAgo: 400 * 86_400), "1y")
    }

    func testFutureClampsToNow() {
        XCTAssertEqual(age(secondsAgo: -500), "now")
    }
}
