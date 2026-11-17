import Foundation

/// App Group の UserDefaults。アプリとウィジェットで色とデータのキャッシュを共有する。
enum SharedStore {
    static let appGroupID = "group.com.imuzi37.LifeHeatmap"
    static let defaults = UserDefaults(suiteName: appGroupID) ?? .standard

    private static let themeKey = "theme"
    private static let demoKey = "demoMode"
    private static func snapshotKey(_ metric: Metric) -> String { "snapshot.\(metric.rawValue)" }

    static var theme: ThemeColor {
        get {
            guard let data = defaults.data(forKey: themeKey),
                  let theme = try? JSONDecoder().decode(ThemeColor.self, from: data) else { return .default }
            return theme
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: themeKey) }
    }

    static func snapshot(for metric: Metric) -> MetricSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey(metric)) else { return nil }
        return try? JSONDecoder().decode(MetricSnapshot.self, from: data)
    }

    static func save(_ snapshot: MetricSnapshot) {
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: snapshotKey(snapshot.metric))
    }

    /// デバッグ用。起動引数 -demoData でサンプルデータを表示する（ウィジェットにも伝わる）。
    static var demoMode: Bool {
        get { defaults.bool(forKey: demoKey) }
        set { defaults.set(newValue, forKey: demoKey) }
    }
}
