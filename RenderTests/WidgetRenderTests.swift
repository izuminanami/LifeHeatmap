import SwiftUI
import WidgetKit
import XCTest

/// ウィジェットの見た目を PNG に書き出して確認するためのテスト（RENDER_DIR に出力）。
@MainActor
final class WidgetRenderTests: XCTestCase {
    func testRenderWidgets() throws {
        guard let dir = ProcessInfo.processInfo.environment["RENDER_DIR"] else { throw XCTSkip("RENDER_DIR 未指定") }
        let sizes: [(WidgetFamily, CGSize, String)] = [
            (.systemSmall, CGSize(width: 170, height: 170), "small"),
            (.systemMedium, CGSize(width: 364, height: 170), "medium"),
            (.systemLarge, CGSize(width: 364, height: 382), "large"),
        ]
        let cases: [(Metric, ThemeColor, MetricSnapshot?)] = [
            (.steps, ThemeColor.default, nil),
            (.sleep, ThemeColor.default, nil),
            (.photos, ThemeColor.default, .empty(.photos, status: .notAuthorized)),
        ]
        for scheme in [ColorScheme.light, .dark] {
            for (family, size, name) in sizes {
                for (metric, theme, override) in cases {
                    let entry = HeatmapEntry(date: .now, snapshot: override ?? DemoData.snapshot(for: metric), theme: theme)
                    let view = HeatmapWidgetView(entry: entry, familyOverride: family)
                        .padding(16)
                        .frame(width: size.width, height: size.height)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(10)
                        .background(scheme == .dark ? Color(white: 0.25) : Color(white: 0.85))
                        .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 3
                    let data = try XCTUnwrap(renderer.uiImage?.pngData())
                    try data.write(to: URL(fileURLWithPath: "\(dir)/\(name)-\(metric.rawValue)-\(scheme == .dark ? "dark" : "light").png"))
                }
            }
        }
    }
}
