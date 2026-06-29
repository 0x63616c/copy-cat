import Foundation

/// A global keyboard shortcut: a virtual key code plus modifier flags.
///
/// Pure data so it can live in Core and be unit-tested without Carbon/AppKit.
/// `keyCode` is the platform virtual key code (same values AppKit's
/// `NSEvent.keyCode` and Carbon's `kVK_*` use). The Carbon translation needed to
/// actually register the hotkey lives in CopyCatKit.
public struct HotKey: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var command: Bool
    public var control: Bool
    public var option: Bool
    public var shift: Bool

    public init(
        keyCode: UInt16,
        command: Bool = false,
        control: Bool = false,
        option: Bool = false,
        shift: Bool = false
    ) {
        self.keyCode = keyCode
        self.command = command
        self.control = control
        self.option = option
        self.shift = shift
    }

    /// "Hyper" = all four modifiers held together. A near-unused combo, so it
    /// rarely collides with app or system shortcuts — the right default for a
    /// global utility hotkey.
    public static func hyper(_ keyCode: UInt16) -> HotKey {
        HotKey(keyCode: keyCode, command: true, control: true, option: true, shift: true)
    }

    /// At least one modifier must be held, or the shortcut would fire on a bare
    /// keypress and hijack normal typing system-wide.
    public var hasModifier: Bool { command || control || option || shift }

    /// Human-readable form, e.g. "⌃⌥⇧⌘X". Modifier order matches Apple's
    /// convention (Control, Option, Shift, Command), key glyph last.
    public var displayString: String {
        var s = ""
        if control { s += "⌃" }
        if option { s += "⌥" }
        if shift { s += "⇧" }
        if command { s += "⌘" }
        s += Self.keyName(for: keyCode)
        return s
    }

    /// Maps a virtual key code to its display glyph. Covers letters, digits, and
    /// the common named keys; unknown codes fall back to "key NN" so the UI never
    /// shows an empty shortcut.
    public static func keyName(for keyCode: UInt16) -> String {
        if let named = namedKeys[keyCode] { return named }
        return "key \(keyCode)"
    }

    /// Virtual-key-code → glyph table (US ANSI layout). Values are the standard
    /// `kVK_*` constants.
    private static let namedKeys: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 32: "U", 34: "I", 31: "O", 35: "P", 37: "L",
        38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9", 29: "0",
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        27: "-", 24: "=", 33: "[", 30: "]", 41: ";", 39: "'",
        43: ",", 47: ".", 44: "/", 42: "\\", 50: "`",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}
