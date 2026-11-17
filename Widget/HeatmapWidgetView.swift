import SwiftUI
import WidgetKit

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let snapshot: MetricSnapshot
    let theme: ThemeColor
}

struct HeatmapWidgetView: View {
    let entry: HeatmapEntry
    /// 画像書き出しテスト用。通常は nil で環境のサイズを使う。
    var familyOverride: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var environmentFamily
    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    private var snapshot: MetricSnapshot { entry.snapshot }
    private var metric: Metric { snapshot.metric }
    private var theme: ThemeColor { entry.theme }

    /// サイズごとの表示週数。Large は 26週×2段（約1年）。
    static func weeks(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: 8
        case .systemMedium: 20
        default: 52
        }
    }

    var body: some View {
        let scale = IntensityScale(snapshot: snapshot, today: entry.date)
        Group {
            if !snapshot.hasData {
                emptyState
            } else {
                switch family {
                case .systemSmall: small(scale)
                case .systemMedium: medium(scale)
                default: large(scale)
                }
            }
        }
        .widgetURL(URL(string: "lifeheatmap://metric/\(metric.rawValue)"))
    }

    // MARK: サイズ別

    private func small(_ scale: IntensityScale) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: metric.symbol).foregroundStyle(theme.color)
                Text(todayText).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            }
            .font(.caption.weight(.semibold))
            FittingHeatmap(snapshot: snapshot, scale: scale, theme: theme, weeks: Self.weeks(for: .systemSmall),
                           endDate: entry.date)
        }
    }

    private func medium(_ scale: IntensityScale) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(scale)
            FittingHeatmap(snapshot: snapshot, scale: scale, theme: theme, weeks: Self.weeks(for: .systemMedium),
                           endDate: entry.date)
        }
    }

    private func large(_ scale: IntensityScale) -> some View {
        let half = Self.weeks(for: .systemLarge) / 2
        let olderEnd = Calendar.current.date(byAdding: .weekOfYear, value: -half, to: entry.date)!
        return VStack(alignment: .leading, spacing: 8) {
            header(scale)
            FittingHeatmap(snapshot: snapshot, scale: scale, theme: theme, weeks: half,
                           endDate: olderEnd, showMonthLabels: true)
            FittingHeatmap(snapshot: snapshot, scale: scale, theme: theme, weeks: half,
                           endDate: entry.date, showMonthLabels: true)
            HStack {
                if let avg = scale.average {
                    Text("平均 \(metric.format(avg))")
                }
                Spacer()
                HeatmapLegend(theme: theme, cellSize: 9)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func header(_ scale: IntensityScale) -> some View {
        HStack(spacing: 6) {
            Label(metric.title, systemImage: metric.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.color)
            Spacer(minLength: 4)
            Text("今日 ").font(.caption2).foregroundStyle(.secondary)
                + Text(todayText).font(.caption.weight(.semibold))
        }
        .lineLimit(1)
        .monospacedDigit()
    }

    private var todayText: String {
        snapshot.value(on: entry.date).map(metric.format) ?? "–"
    }

    // MARK: 権限なし・データなし

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(metric.title, systemImage: metric.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.color)
            Spacer(minLength: 0)
            Image(systemName: snapshot.status == .noData ? "tray" : "lock.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(emptyMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyMessage: String {
        switch snapshot.status {
        case .notDetermined, .notAuthorized:
            "アプリを開いて\(metric.sourceName)へのアクセスを許可してください"
        case .unavailable:
            "データを取得できませんでした"
        case .noData, .ok:
            "まだデータがありません"
        }
    }
}
