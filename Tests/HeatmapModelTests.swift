import XCTest
@testable import LifeHeatmap

final class HeatmapModelTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        c.firstWeekday = 1
        return c
    }

    func testLevelsByQuartiles() {
        // 1〜8 の四分位は 2.75 / 4.5 / 6.25
        let scale = IntensityScale(baseline: [1, 2, 3, 4, 5, 6, 7, 8, 0])
        XCTAssertNil(scale.level(for: nil))
        XCTAssertEqual(scale.level(for: 0), 0)
        XCTAssertEqual(scale.level(for: 2), 1)
        XCTAssertEqual(scale.level(for: 3), 2)
        XCTAssertEqual(scale.level(for: 5), 3)
        XCTAssertEqual(scale.level(for: 7), 4)
        XCTAssertEqual(scale.average, 4.5)
    }

    func testLowVarianceStillUsesAllLevels() {
        // 睡眠のようにばらつきが小さくても4段階に均等に分かれる
        let values = (0..<100).map { 6.5 + Double($0) * 0.01 }
        let scale = IntensityScale(baseline: values)
        var counts = [0, 0, 0, 0, 0]
        for v in values { counts[scale.level(for: v)!] += 1 }
        for level in 1...4 { XCTAssertEqual(Double(counts[level]), 25, accuracy: 2) }
    }

    func testBaselineExcludesTodayAndEmptyDays() {
        let cal = calendar
        let today = cal.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12))!
        let y1 = cal.date(byAdding: .day, value: -1, to: today)!
        let y2 = cal.date(byAdding: .day, value: -2, to: today)!
        let y3 = cal.date(byAdding: .day, value: -3, to: today)!
        let snap = MetricSnapshot(metric: .steps, values: [
            DayKey.key(today, calendar: cal): 99999,
            DayKey.key(y1, calendar: cal): 1000,
            DayKey.key(y2, calendar: cal): 3000,
            DayKey.key(y3, calendar: cal): 0,
        ], status: .ok, updatedAt: today)
        XCTAssertEqual(IntensityScale(snapshot: snap, today: today, calendar: cal).average, 2000)
    }

    func testNoBaselineGivesMaxForPositive() {
        let scale = IntensityScale(baseline: [])
        XCTAssertEqual(scale.level(for: 5), 4)
        XCTAssertEqual(scale.level(for: 0), 0)
    }

    func testWeekStartsEndWithCurrentWeek() {
        let cal = calendar
        let date = cal.date(from: DateComponents(year: 2026, month: 11, day: 17))! // 火曜
        let starts = HeatmapLayout.weekStarts(weeks: 8, endingAt: date, calendar: cal)
        XCTAssertEqual(starts.count, 8)
        XCTAssertEqual(DayKey.key(starts.last!, calendar: cal), "2026-11-15")
        XCTAssertEqual(DayKey.key(starts.first!, calendar: cal), "2026-09-27")
    }

    func testThemeRoundTrip() throws {
        let theme = ThemeColor(hex: 0x2F81F7)
        let decoded = try JSONDecoder().decode(ThemeColor.self, from: JSONEncoder().encode(theme))
        XCTAssertEqual(decoded, theme)
        let fromColor = ThemeColor(color: theme.color)
        XCTAssertEqual(fromColor.red, theme.red, accuracy: 0.01)
        XCTAssertEqual(fromColor.blue, theme.blue, accuracy: 0.01)
    }
}
