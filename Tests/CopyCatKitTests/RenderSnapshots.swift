import XCTest
import SwiftUI
import CopyCatCore
@testable import CopyCatKit

/// Opt-in product photography of the actual SwiftUI views with synthetic content.
/// COPYCAT_SCREENSHOTS=1 COPYCAT_SCREEN_CAPTURE=1 swift test --filter RenderSnapshots
@MainActor
final class RenderSnapshots: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["COPYCAT_SCREENSHOTS"] == "1", "Product screenshots are opt-in")
    }

    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func samples() throws -> [Screenshot] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("copy-cat-product-fixtures")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let names = ["Alpine lake", "Build output", "Project overview", "Release notes", "Components", "Calendar", "Photo library", "Test results", "Activity", "Design review", "Documentation", "Schedule"]
        return try names.enumerated().map { index, name in
            let view = ProductFixture(index: index, title: name).frame(width: 720, height: 520)
            let renderer = ImageRenderer(content: view)
            let image = try XCTUnwrap(renderer.nsImage)
            let rep = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
            let url = dir.appendingPathComponent("\(name).png")
            try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: url)
            _ = ThumbnailCache.shared.thumbnail(for: url, maxPixel: Int(PopoverMetrics.tile * 3))
            return Screenshot(url: url, captureDate: Date().addingTimeInterval(Double(-index * 180)))
        }
    }

    private func capture(_ view: some View, size: CGSize, name: String) async throws {
        let host = NSHostingView(rootView: view.environment(\.colorScheme, .light)
            .frame(width: size.width, height: size.height)
            .background(Color(red: 0.93, green: 0.95, blue: 0.98)))
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: 200, y: 200), size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        host.displayIfNeeded()
        if ProcessInfo.processInfo.environment["COPYCAT_SCREEN_CAPTURE"] == "1" {
            let directory = root.appendingPathComponent("site/assets")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", "-o", "-l", String(window.windowNumber), directory.appendingPathComponent(name).path]
            try process.run()
            process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 0, "Window capture failed")
            return
        }
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let directory = root.appendingPathComponent("site/assets")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCTUnwrap(rep.representation(using: .png, properties: [:])).write(to: directory.appendingPathComponent(name))
    }

    func testProductScreenshots() async throws {
        let controller = AppController(store: makeTempStore(), clipboard: FakeClipboard(), prefs: FakePrefs(), access: FakeAccess())
        controller.ingest(try samples())
        let size = PopoverMetrics.size(columns: AppSettings.gridColumns, rows: AppSettings.gridRows, count: controller.screenshots.count, banner: false, settings: false)
        try await capture(PopoverRootView(loginItem: LoginItem(readStatus: { .notRegistered })).environmentObject(controller).environmentObject(UpdateManager()), size: size, name: "library.png")
        try await capture(
            HStack(alignment: .top, spacing: 16) {
                FloatingPreview(screenshot: controller.screenshots.first)
                PopoverRootView(loginItem: LoginItem(readStatus: { .notRegistered }))
                    .environmentObject(controller).environmentObject(UpdateManager())
                    .frame(width: size.width, height: size.height)
            }.padding(12), size: CGSize(width: 1046, height: 510), name: "product.png")
        controller.openSettings()
        let settingsSize = PopoverMetrics.size(columns: AppSettings.gridColumns, rows: AppSettings.gridRows, count: controller.screenshots.count, banner: false, settings: true)
        try await capture(PopoverRootView(loginItem: LoginItem(readStatus: { .notRegistered })).environmentObject(controller).environmentObject(UpdateManager()), size: settingsSize, name: "settings.png")
    }
}

private struct ProductFixture: View {
    let index: Int
    let title: String
    private var dark: Bool { index % 6 == 1 || index % 6 == 4 }
    private var landscape: NSImage {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return NSImage(contentsOf: root.appendingPathComponent("site/assets/sample-landscape.png"))!
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ForEach([Color.red.opacity(0.8), .yellow.opacity(0.8), .green.opacity(0.8)], id: \.self) { color in
                    Circle().fill(color).frame(width: 10, height: 10)
                }
                Spacer()
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                Image(systemName: "sidebar.right").font(.system(size: 13))
            }
            .padding(16).background(dark ? Color.white.opacity(0.06) : Color.black.opacity(0.035))
            content
        }
        .foregroundStyle(dark ? Color.white : Color.black.opacity(0.88))
        .background(dark ? Color(red: 0.08, green: 0.09, blue: 0.11) : .white)
    }

    @ViewBuilder private var content: some View {
        switch index % 6 {
        case 0:
            Image(nsImage: landscape).resizable().scaledToFill().frame(width: 720, height: 474).clipped()
        case 1:
            VStack(alignment: .leading, spacing: 18) {
                Text("~/Projects/copy-cat  main").foregroundStyle(.gray)
                Text("❯ swift test").foregroundStyle(.white)
                Text("Building for debugging…\nBuild complete! (2.41s)").foregroundStyle(.gray)
                Text("✓ Screenshot detection\n✓ Clipboard integration\n✓ Login item registration\n✓ Settings persistence\n✓ Update configuration").foregroundStyle(Color(red: 0.45, green: 0.8, blue: 0.6))
                Text("All tests passed.").foregroundStyle(.white)
                Text("❯ ▋").foregroundStyle(.gray)
            }.font(.system(size: 20, design: .monospaced)).padding(32).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case 2:
            VStack(alignment: .leading, spacing: 24) {
                Text("Overview").font(.system(size: 32, weight: .semibold))
                HStack(spacing: 16) {
                    metric("Page views", "24,892")
                    metric("Visitors", "8,421")
                    metric("Conversion", "4.8%")
                }
                Text("Activity over time").font(.system(size: 15, weight: .semibold))
                GeometryReader { geo in
                    Path { path in
                        let values: [CGFloat] = [0.78,0.7,0.73,0.61,0.65,0.44,0.5,0.35,0.4,0.24,0.3,0.11]
                        for (i,v) in values.enumerated() {
                            let point = CGPoint(x: CGFloat(i) / 11 * geo.size.width, y: v * geo.size.height)
                            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                    }.stroke(Color.blue.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
                    VStack { ForEach(0..<4) { _ in Spacer(); Divider() } }.opacity(0.3)
                }
                HStack { Text("Mon"); Spacer(); Text("Wed"); Spacer(); Text("Fri"); Spacer(); Text("Sun") }.font(.system(size: 12)).foregroundStyle(.gray)
            }.padding(30)
        case 3:
            VStack(alignment: .leading, spacing: 22) {
                Text("September 5, 2026").font(.system(size: 13)).foregroundStyle(.gray)
                Text(index == 3 ? "Release notes" : "Design review").font(.system(size: 36, weight: .bold))
                Text("CopyCat 0.2.0").font(.system(size: 20, weight: .semibold))
                Divider()
                ForEach(["Open at Login", "Native Liquid Glass controls", "Automatic updates", "Keyboard shortcuts"], id: \.self) { text in
                    Label(text, systemImage: "checkmark.circle").font(.system(size: 21)).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(36)
        case 4:
            VStack(alignment: .leading, spacing: 26) {
                Text(index == 4 ? "Components" : "Documentation").font(.system(size: 34, weight: .semibold))
                Text("Interface primitives for macOS.").font(.system(size: 18)).foregroundStyle(.gray)
                HStack(spacing: 14) {
                    Text("Button").padding(16).background(.white, in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.black)
                    Text("Secondary").padding(16).overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray.opacity(0.5)))
                    Label("Settings", systemImage: "gearshape").padding(16)
                }.font(.system(size: 17))
                VStack(alignment: .leading, spacing: 16) {
                    Text("import SwiftUI").foregroundStyle(.purple)
                    Text("struct SettingsView: View {")
                    Text("    var body: some View {").foregroundStyle(.gray)
                    Text("        Toggle(\"Open at Login\", isOn: $enabled)").foregroundStyle(.mint)
                    Text("    }\n}")
                }.font(.system(size: 17, design: .monospaced)).padding(22).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                Spacer()
            }.padding(32)
        default:
            VStack(alignment: .leading, spacing: 22) {
                HStack { Text("September 2026").font(.system(size: 30, weight: .semibold)); Spacer(); Text("Week").font(.system(size: 14)).padding(10).background(.black.opacity(0.04), in: Capsule()) }
                HStack(alignment: .top, spacing: 1) {
                    ForEach(0..<5) { day in
                        VStack(spacing: 16) {
                            Text(["MON", "TUE", "WED", "THU", "FRI"][day]).font(.system(size: 11)).foregroundStyle(.gray)
                            Text("\(day + 7)").font(.system(size: 25, weight: .medium))
                            Rectangle().fill(.gray.opacity(0.15)).frame(height: 1)
                            Text(["Design review", "Focus time", "Release", "Planning", "Demo"][day]).font(.system(size: 13, weight: .medium)).padding(10).frame(maxWidth: .infinity).background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                            Spacer()
                        }.frame(maxWidth: .infinity).padding(7).overlay(Rectangle().stroke(.gray.opacity(0.1)))
                    }
                }
            }.padding(28)
        }
    }

    private func metric(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(name).font(.system(size: 13)).foregroundStyle(.gray)
            Text(value).font(.system(size: 26, weight: .semibold))
            Text("+12.4% this month").font(.system(size: 11)).foregroundStyle(.gray)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.2)))
    }
}
