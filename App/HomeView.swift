import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    #if DEBUG
    /// スクリーンショット用。起動引数 -showTheme で色の画面を開いた状態にする。
    @State private var showTheme = ProcessInfo.processInfo.arguments.contains("-showTheme")
    #else
    @State private var showTheme = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Metric.allCases) { metric in
                        MetricCard(metric: metric, snapshot: model.snapshots[metric], theme: model.theme)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("濃さは、過去1年の自分の記録を少ない順に4等分して決めています。")
                        Link("プライバシーポリシー", destination: AppLinks.privacyPolicy)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("生活ヒートマップ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showTheme = true } label: {
                        Image(systemName: "paintpalette.fill")
                    }
                    .accessibilityLabel("色を変更")
                }
            }
            .refreshable { await model.refresh() }
            .task { await model.refresh() }
            .sheet(isPresented: $showTheme) { ThemeSettingsView() }
        }
    }
}

struct MetricCard: View {
    let metric: Metric
    let snapshot: MetricSnapshot?
    let theme: ThemeColor
    @Environment(AppModel.self) private var model
    @State private var selected: Date?

    private var current: MetricSnapshot { snapshot ?? .empty(metric, status: .notDetermined) }

    var body: some View {
        let scale = IntensityScale(snapshot: current)
        VStack(alignment: .leading, spacing: 12) {
            header(scale: scale)
            ScrollView(.horizontal, showsIndicators: false) {
                HeatmapGrid(snapshot: current, scale: scale, theme: theme, weeks: 53,
                            cellSize: 15, spacing: 3, showMonthLabels: true,
                            selectedDate: selected,
                            onSelect: { day in selected = (selected == day) ? nil : day })
                    .padding(.vertical, 2)
            }
            .defaultScrollAnchor(.trailing)
            .opacity(current.hasData ? 1 : 0.5)

            if current.hasData {
                HStack {
                    if let avg = scale.average {
                        Text("平均 \(metric.format(avg))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HeatmapLegend(theme: theme)
                }
            } else {
                StatusMessage(metric: metric, status: current.status)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func header(scale: IntensityScale) -> some View {
        let day = selected ?? .now
        let value = current.value(on: day)
        return HStack(alignment: .firstTextBaseline) {
            Label(metric.title, systemImage: metric.symbol)
                .font(.headline)
                .foregroundStyle(theme.color)
            Spacer()
            if current.hasData {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(selected.map { $0.formatted(.dateTime.month().day().weekday()) } ?? "今日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value.map(metric.format) ?? "データなし")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
        }
    }
}

/// 権限なし・データなしのときの案内。
struct StatusMessage: View {
    let metric: Metric
    let status: DataStatus
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                switch status {
                case .notDetermined:
                    Button("アクセスを許可する") { Task { await model.requestPermissions() } }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                case .notAuthorized:
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                default:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: String {
        switch status {
        case .notDetermined, .notAuthorized: "lock.fill"
        case .unavailable: "exclamationmark.triangle"
        default: "tray"
        }
    }

    private var message: String {
        switch status {
        case .notDetermined:
            "\(metric.sourceName)へのアクセスがまだ許可されていません。"
        case .notAuthorized:
            "\(metric.sourceName)へのアクセスが許可されていません。設定アプリから許可してください。"
        case .unavailable:
            "この端末では\(metric.title)を取得できません。"
        case .noData, .ok:
            metric.source == .health
                ? "データがありません。ヘルスケアアプリの「共有」→「アプリ」で、読み取りが許可されているか確認してください。"
                : "まだ写真がありません。"
        }
    }
}

enum AppLinks {
    static let privacyPolicy = URL(string: "https://izuminanami.github.io/LifeHeatmap/privacy-policy/")!
    static let support = URL(string: "https://izuminanami.github.io/LifeHeatmap/")!
}
