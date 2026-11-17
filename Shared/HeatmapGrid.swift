import SwiftUI

/// 1マス＝1日、列＝週のヒートマップ。
struct HeatmapGrid: View {
    let snapshot: MetricSnapshot
    let scale: IntensityScale
    let theme: ThemeColor
    let weeks: Int
    var endDate: Date = .now
    var cellSize: CGFloat
    var spacing: CGFloat
    var showMonthLabels = false
    var selectedDate: Date? = nil
    var onSelect: ((Date) -> Void)? = nil

    private let calendar = Calendar.current

    static func monthLabelHeight(for cellSize: CGFloat) -> CGFloat { max(10, cellSize * 0.8) + 3 }

    var body: some View {
        let columns = HeatmapLayout.weekStarts(weeks: weeks, endingAt: endDate, calendar: calendar)
        let today = calendar.startOfDay(for: .now)
        VStack(alignment: .leading, spacing: 3) {
            if showMonthLabels {
                HStack(spacing: spacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { index, weekStart in
                        Text(monthLabel(for: weekStart, isFirst: index == 0) ?? "")
                            .font(.system(size: max(8, cellSize * 0.8)))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .frame(width: cellSize, alignment: .leading)
                    }
                }
                .frame(height: Self.monthLabelHeight(for: cellSize) - 3, alignment: .leading)
            }
            HStack(alignment: .top, spacing: spacing) {
                ForEach(columns, id: \.self) { weekStart in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { i in
                            cell(day: calendar.date(byAdding: .day, value: i, to: weekStart)!, today: today)
                        }
                    }
                }
            }
        }
    }

    /// その列に月初（1日）があれば月名。先頭列は表示がはみ出さないよう月初のときだけ。
    private func monthLabel(for weekStart: Date, isFirst: Bool) -> String? {
        for i in 0..<7 {
            let day = calendar.date(byAdding: .day, value: i, to: weekStart)!
            if calendar.component(.day, from: day) == 1 {
                return "\(calendar.component(.month, from: day))月"
            }
        }
        return nil
    }

    @ViewBuilder
    private func cell(day: Date, today: Date) -> some View {
        let shape = RoundedRectangle(cornerRadius: max(1.5, cellSize * 0.22), style: .continuous)
        if day > today {
            Color.clear.frame(width: cellSize, height: cellSize)
        } else {
            let level = scale.level(for: snapshot.value(on: day, calendar: calendar))
            ZStack {
                if let level {
                    shape.fill(theme.fill(level: level))
                } else {
                    shape.strokeBorder(Color.primary.opacity(0.14), lineWidth: max(0.5, cellSize / 14))
                }
                if let selectedDate, calendar.isDate(selectedDate, inSameDayAs: day) {
                    shape.strokeBorder(Color.primary, lineWidth: 1.5)
                }
            }
            .frame(width: cellSize, height: cellSize)
            .contentShape(Rectangle())
            .onTapGesture { onSelect?(day) }
            .accessibilityElement()
            .accessibilityLabel(Text(day, format: .dateTime.month().day()))
            .accessibilityValue(accessibilityValue(day))
        }
    }

    private func accessibilityValue(_ day: Date) -> String {
        guard let v = snapshot.value(on: day, calendar: calendar) else { return "データなし" }
        return snapshot.metric.format(v)
    }
}

/// 与えられた領域いっぱいにマスの大きさを合わせる（ウィジェット用）。
struct FittingHeatmap: View {
    let snapshot: MetricSnapshot
    let scale: IntensityScale
    let theme: ThemeColor
    let weeks: Int
    var endDate: Date = .now
    var showMonthLabels = false
    var spacingRatio: CGFloat = 0.22

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / (CGFloat(weeks) + CGFloat(weeks - 1) * spacingRatio)
            let labelH = showMonthLabels ? 13.0 : 0
            let h = (geo.size.height - labelH) / (7 + 6 * spacingRatio)
            let cell = max(2, floor(min(w, h) * 2) / 2)
            HeatmapGrid(snapshot: snapshot, scale: scale, theme: theme, weeks: weeks, endDate: endDate,
                        cellSize: cell, spacing: max(1, (cell * spacingRatio).rounded(.down)),
                        showMonthLabels: showMonthLabels)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// 「少 □□□□□ 多」の凡例。
struct HeatmapLegend: View {
    let theme: ThemeColor
    var cellSize: CGFloat = 10
    var showNoData = true

    var body: some View {
        HStack(spacing: 3) {
            if showNoData {
                RoundedRectangle(cornerRadius: cellSize * 0.22)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
                    .frame(width: cellSize, height: cellSize)
                Text("なし").padding(.trailing, 6)
            }
            Text("少")
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: cellSize * 0.22)
                    .fill(theme.fill(level: level))
                    .frame(width: cellSize, height: cellSize)
            }
            Text("多")
        }
        .font(.system(size: max(9, cellSize)))
        .foregroundStyle(.secondary)
    }
}
