import Foundation

/// プレビュー・ウィジェットギャラリー・デバッグ用のサンプルデータ。
enum DemoData {
    static func snapshot(for metric: Metric, days: Int = 400, calendar: Calendar = .current) -> MetricSnapshot {
        var rng = SeededRandom(seed: UInt64(Metric.allCases.firstIndex(of: metric)! + 1) * 7919)
        let today = calendar.startOfDay(for: .now)
        var values: [String: Double] = [:]
        for offset in 0..<days {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let weekday = calendar.component(.weekday, from: day)
            let weekend = weekday == 1 || weekday == 7
            let r = rng.next()
            if metric != .photos, r < 0.06 { continue }   // ときどきデータなしの日
            let v: Double
            switch metric {
            case .steps: v = (weekend ? 9500 : 7000) * (0.25 + 1.5 * rng.next())
            case .sleep: v = ((weekend ? 7.8 : 6.6) * (0.75 + 0.5 * rng.next()) * 10).rounded() / 10
            case .photos: v = rng.next() < 0.35 ? 0 : ((weekend ? 14 : 4) * (0.2 + 1.8 * rng.next())).rounded()
            }
            values[DayKey.key(day, calendar: calendar)] = v
        }
        return MetricSnapshot(metric: metric, values: values, status: .ok, updatedAt: .now)
    }
}

struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}
