import SwiftUI
import WidgetKit

struct HeatmapProvider: TimelineProvider {
    let metric: Metric

    func placeholder(in context: Context) -> HeatmapEntry {
        HeatmapEntry(date: .now, snapshot: DemoData.snapshot(for: metric), theme: SharedStore.theme)
    }

    func getSnapshot(in context: Context, completion: @escaping (HeatmapEntry) -> Void) {
        if context.isPreview {
            // ウィジェットギャラリーでは、実データがなければサンプルを見せる。
            let cached = SharedStore.snapshot(for: metric)
            let snapshot = (cached?.hasData == true ? cached : nil) ?? DemoData.snapshot(for: metric)
            completion(HeatmapEntry(date: .now, snapshot: snapshot, theme: SharedStore.theme))
            return
        }
        Task {
            completion(HeatmapEntry(date: .now, snapshot: await HeatmapRepository.load(metric),
                                    theme: SharedStore.theme))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeatmapEntry>) -> Void) {
        Task {
            let entry = HeatmapEntry(date: .now, snapshot: await HeatmapRepository.load(metric),
                                     theme: SharedStore.theme)
            let calendar = Calendar.current
            let hourLater = calendar.date(byAdding: .hour, value: 1, to: .now)!
            let tomorrow = calendar.date(byAdding: .minute, value: 1,
                                         to: calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now)!))!
            completion(Timeline(entries: [entry], policy: .after(min(hourLater, tomorrow))))
        }
    }
}

/// データごとに別のウィジェット（ギャラリーで種類として選ぶ）。
/// 名前と説明は WidgetKit の要件に合わせて静的な文字列で渡す。
func heatmapConfiguration(for metric: Metric, name: LocalizedStringResource,
                          description: LocalizedStringResource) -> some WidgetConfiguration {
    StaticConfiguration(kind: "HeatmapWidget.\(metric.rawValue)", provider: HeatmapProvider(metric: metric)) { entry in
        HeatmapWidgetView(entry: entry)
            .containerBackground(Color(.systemBackground), for: .widget)
    }
    .configurationDisplayName(name)
    .description(description)
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
}

struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        heatmapConfiguration(for: .steps, name: "歩数", description: "歩数の記録をヒートマップで表示します。")
    }
}

struct SleepWidget: Widget {
    var body: some WidgetConfiguration {
        heatmapConfiguration(for: .sleep, name: "睡眠時間", description: "睡眠時間の記録をヒートマップで表示します。")
    }
}

struct PhotosWidget: Widget {
    var body: some WidgetConfiguration {
        heatmapConfiguration(for: .photos, name: "撮った写真", description: "撮った写真の枚数をヒートマップで表示します。")
    }
}

@main
struct HeatmapWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepsWidget()
        SleepWidget()
        PhotosWidget()
    }
}

#Preview("Small", as: .systemSmall) {
    StepsWidget()
} timeline: {
    HeatmapEntry(date: .now, snapshot: DemoData.snapshot(for: .steps), theme: .default)
}

#Preview("Medium", as: .systemMedium) {
    SleepWidget()
} timeline: {
    HeatmapEntry(date: .now, snapshot: DemoData.snapshot(for: .sleep), theme: .default)
}

#Preview("Large", as: .systemLarge) {
    PhotosWidget()
} timeline: {
    HeatmapEntry(date: .now, snapshot: DemoData.snapshot(for: .photos), theme: .default)
    HeatmapEntry(date: .now, snapshot: .empty(.photos, status: .notAuthorized), theme: .default)
}
