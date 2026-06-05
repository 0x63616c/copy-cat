import Foundation

/// Compact "time ago" label for a screenshot, e.g. `now`, `5m`, `3h`, `33d`,
/// `4mo`, `1y`. Days run up to ~3 months so a `33d`-old shot reads as days, not
/// "1mo". Deliberately terse for tile/preview overlays — pass an explicit `now`
/// so it stays pure and testable.
public func compactRelativeAge(from date: Date, now: Date) -> String {
    let seconds = max(0, now.timeIntervalSince(date))
    let minute = 60.0
    let hour = 3600.0
    let day = 86_400.0
    let month = day * 30
    let year = day * 365

    switch seconds {
    case ..<minute:
        return "now"
    case ..<hour:
        return "\(Int(seconds / minute))m"
    case ..<day:
        return "\(Int(seconds / hour))h"
    case ..<(day * 100):
        return "\(Int(seconds / day))d"
    case ..<year:
        return "\(Int(seconds / month))mo"
    default:
        return "\(Int(seconds / year))y"
    }
}
