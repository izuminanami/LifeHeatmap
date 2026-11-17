import Foundation

/// 日付を "yyyy-MM-dd" のキーにする（タイムゾーンが変わっても同じ暦日を指す）。
enum DayKey {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

enum DataStatus: String, Codable {
    case ok
    case noData          // 取得できたが値がない
    case notDetermined   // まだ許可を求めていない
    case notAuthorized   // 許可されていない
    case unavailable     // この端末では使えない／取得に失敗
}

/// 1種類のデータの日別の値。アプリとウィジェットで App Group 経由で共有する。
struct MetricSnapshot: Codable, Equatable {
    var metric: Metric
    /// キーは DayKey。値がない日はキー自体がない（＝データなし）。
    var values: [String: Double]
    var status: DataStatus
    var updatedAt: Date

    func value(on date: Date, calendar: Calendar = .current) -> Double? {
        values[DayKey.key(date, calendar: calendar)]
    }

    var hasData: Bool { values.values.contains { $0 > 0 } }

    static func empty(_ metric: Metric, status: DataStatus) -> MetricSnapshot {
        MetricSnapshot(metric: metric, values: [:], status: status, updatedAt: .now)
    }
}

/// 濃さ（0〜4の5段階）。GitHub と同じく、過去の自分の記録を4等分して決める。
/// 今日を除く直近365日のうち値が0より大きい日を並べ、25・50・75パーセンタイルを境目にする。
/// ばらつきが小さいデータ（睡眠など）でも4段階が均等に使われる。
struct IntensityScale {
    static let baselineDays = 365

    /// 段階1→2、2→3、3→4 の境目。記録がなければ nil。
    let thresholds: (Double, Double, Double)?
    /// 表示用の平均（同じ期間の、値が0より大きい日）。
    let average: Double?

    init(snapshot: MetricSnapshot, today: Date = .now, calendar: Calendar = .current) {
        let todayStart = calendar.startOfDay(for: today)
        var values: [Double] = []
        for offset in 1...Self.baselineDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart),
                  let v = snapshot.value(on: day, calendar: calendar), v > 0 else { continue }
            values.append(v)
        }
        if values.isEmpty, let v = snapshot.value(on: todayStart, calendar: calendar), v > 0 {
            values = [v]
        }
        self.init(baseline: values)
    }

    init(baseline: [Double]) {
        let sorted = baseline.filter { $0 > 0 }.sorted()
        guard !sorted.isEmpty else {
            thresholds = nil
            average = nil
            return
        }
        thresholds = (Self.percentile(sorted, 0.25), Self.percentile(sorted, 0.5), Self.percentile(sorted, 0.75))
        average = sorted.reduce(0, +) / Double(sorted.count)
    }

    /// 線形補間のパーセンタイル（sorted は昇順）。
    static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard sorted.count > 1 else { return sorted[0] }
        let pos = p * Double(sorted.count - 1)
        let lower = Int(pos.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (pos - Double(lower))
    }

    /// nil はデータなしの日。
    func level(for value: Double?) -> Int? {
        guard let value else { return nil }
        guard value > 0 else { return 0 }
        guard let (q1, q2, q3) = thresholds else { return 4 }
        if value < q1 { return 1 }
        if value < q2 { return 2 }
        if value < q3 { return 3 }
        return 4
    }
}

/// 週の列（各列の先頭日）を古い順に返す。最後の列に endDate を含む。
enum HeatmapLayout {
    static func weekStarts(weeks: Int, endingAt endDate: Date, calendar: Calendar = .current) -> [Date] {
        let lastStart = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start
            ?? calendar.startOfDay(for: endDate)
        return (0..<weeks).reversed().compactMap {
            calendar.date(byAdding: .weekOfYear, value: -$0, to: lastStart)
        }
    }
}
