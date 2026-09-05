// Vector adaptation of the approved CopyCat mark for a monochrome menu-bar template.
// Run: swift scripts/menu-bar-mark.swift Resources/menubar-cat.pdf
import AppKit

final class Mark: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let transform = AffineTransform(translationByX: -230, byY: -270)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 310, y: 544))
        path.line(to: NSPoint(x: 310, y: 332))
        path.curve(to: NSPoint(x: 349, y: 296), controlPoint1: NSPoint(x: 310, y: 278), controlPoint2: NSPoint(x: 330, y: 289))
        path.line(to: NSPoint(x: 519, y: 426))
        path.curve(to: NSPoint(x: 734, y: 426), controlPoint1: NSPoint(x: 590, y: 415), controlPoint2: NSPoint(x: 670, y: 415))
        path.line(to: NSPoint(x: 899, y: 296))
        path.curve(to: NSPoint(x: 940, y: 327), controlPoint1: NSPoint(x: 934, y: 278), controlPoint2: NSPoint(x: 941, y: 295))
        path.line(to: NSPoint(x: 941, y: 538))
        path.curve(to: NSPoint(x: 998, y: 743), controlPoint1: NSPoint(x: 985, y: 614), controlPoint2: NSPoint(x: 1007, y: 681))
        path.curve(to: NSPoint(x: 629, y: 948), controlPoint1: NSPoint(x: 984, y: 877), controlPoint2: NSPoint(x: 850, y: 948))
        path.curve(to: NSPoint(x: 252, y: 758), controlPoint1: NSPoint(x: 405, y: 948), controlPoint2: NSPoint(x: 270, y: 880))
        path.curve(to: NSPoint(x: 310, y: 544), controlPoint1: NSPoint(x: 239, y: 676), controlPoint2: NSPoint(x: 265, y: 603))
        path.close()
        path.appendOval(in: NSRect(x: 410, y: 620, width: 130, height: 130))
        path.appendOval(in: NSRect(x: 710, y: 620, width: 130, height: 130))
        path.windingRule = .evenOdd
        path.transform(using: transform)
        NSColor.black.setFill()
        path.fill()
    }
}
let view = Mark(frame: NSRect(x: 0, y: 0, width: 790, height: 710))
try view.dataWithPDF(inside: view.bounds).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
