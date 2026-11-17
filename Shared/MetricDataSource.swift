import Foundation
import HealthKit
import Photos

enum DataFetchError: Error {
    case unavailable
    case notAuthorized
}

/// HealthKit と PhotoKit から日別の値を取る。
enum MetricDataSource {
    static let healthStore = HKHealthStore()

    static var healthReadTypes: Set<HKObjectType> {
        [HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis)]
    }

    // MARK: 権限

    static func requestHealthAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await healthStore.requestAuthorization(toShare: [], read: healthReadTypes)
    }

    @discardableResult
    static func requestPhotosAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// 値が1件もなかったときの状態。HealthKit は読み取り拒否を知らせないので「データなし」として扱う。
    static func emptyStatus(for metric: Metric) async -> DataStatus {
        switch metric.source {
        case .photos:
            return .noData
        case .health:
            let status = try? await healthStore.statusForAuthorizationRequest(toShare: [], read: healthReadTypes)
            return status == .shouldRequest ? .notDetermined : .noData
        }
    }

    // MARK: 取得

    /// 直近 days 日分（今日を含む）の値。キーは DayKey。
    static func fetch(_ metric: Metric, days: Int, calendar: Calendar = .current) async throws -> [String: Double] {
        let end = Date.now
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: end))!
        switch metric {
        case .steps:
            return try await quantitySums(.stepCount, unit: .count(), start: start, end: end, calendar: calendar)
        case .sleep:
            return try await sleepHours(start: start, end: end, calendar: calendar)
        case .photos:
            return try photoCounts(start: start, end: end, calendar: calendar)
        }
    }

    private static func quantitySums(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date,
                                     calendar: Calendar) async throws -> [String: Double] {
        guard HKHealthStore.isHealthDataAvailable() else { throw DataFetchError.unavailable }
        let type = HKQuantityType(id)
        let predicate = HKSamplePredicate.quantitySample(
            type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end))
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate, options: .cumulativeSum, anchorDate: start,
            intervalComponents: DateComponents(day: 1))
        let collection = try await descriptor.result(for: healthStore)
        var result: [String: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            if let sum = stats.sumQuantity() {
                result[DayKey.key(stats.startDate, calendar: calendar)] = sum.doubleValue(for: unit)
            }
        }
        return result
    }

    /// 睡眠は複数ソース（iPhone と Apple Watch など）の重なりを結合し、起きた日に計上する。
    private static func sleepHours(start: Date, end: Date, calendar: Calendar) async throws -> [String: Double] {
        guard HKHealthStore.isHealthDataAvailable() else { throw DataFetchError.unavailable }
        let queryStart = calendar.date(byAdding: .day, value: -1, to: start)!
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis),
                                         predicate: HKQuery.predicateForSamples(withStart: queryStart, end: end))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let samples = try await descriptor.result(for: healthStore)
        let asleep = HKCategoryValueSleepAnalysis.allAsleepValues
        let intervals = samples
            .filter { HKCategoryValueSleepAnalysis(rawValue: $0.value).map(asleep.contains) ?? false }
            .map { ($0.startDate, $0.endDate) }
            .sorted { $0.0 < $1.0 }

        var merged: [(Date, Date)] = []
        for interval in intervals {
            if let last = merged.last, interval.0 <= last.1 {
                merged[merged.count - 1].1 = max(last.1, interval.1)
            } else {
                merged.append(interval)
            }
        }

        var result: [String: Double] = [:]
        for (s, e) in merged where e >= start {
            result[DayKey.key(e, calendar: calendar), default: 0] += e.timeIntervalSince(s) / 3600
        }
        return result
    }

    private static func photoCounts(start: Date, end: Date, calendar: Calendar) throws -> [String: Double] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited: break
        case .notDetermined: throw DataFetchError.notAuthorized
        default: throw DataFetchError.notAuthorized
        }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@ AND mediaType == %d",
                                        start as NSDate, end as NSDate, PHAssetMediaType.image.rawValue)
        options.includeAssetSourceTypes = [.typeUserLibrary]
        let assets = PHAsset.fetchAssets(with: options)

        // 写真は「0枚」も実際の記録なので、期間内の全日を0で埋める。
        var result: [String: Double] = [:]
        var day = start
        while day <= end {
            result[DayKey.key(day, calendar: calendar)] = 0
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        assets.enumerateObjects { asset, _, _ in
            if let date = asset.creationDate {
                result[DayKey.key(date, calendar: calendar), default: 0] += 1
            }
        }
        return result
    }

    static var photosStatus: DataStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited: .ok
        case .notDetermined: .notDetermined
        default: .notAuthorized
        }
    }
}

/// 取得とキャッシュをまとめる。ウィジェットでロック中などに取得できないときはキャッシュを返す。
enum HeatmapRepository {
    static let fetchDays = 400

    static func load(_ metric: Metric) async -> MetricSnapshot {
        if SharedStore.demoMode { return DemoData.snapshot(for: metric) }
        let cached = SharedStore.snapshot(for: metric)

        if metric == .photos, MetricDataSource.photosStatus != .ok {
            return .empty(metric, status: MetricDataSource.photosStatus)
        }

        do {
            let values = try await MetricDataSource.fetch(metric, days: fetchDays)
            let hasData = values.values.contains { $0 > 0 }
            if !hasData, let cached, cached.hasData { return cached }
            let status: DataStatus = hasData ? .ok : await MetricDataSource.emptyStatus(for: metric)
            let snapshot = MetricSnapshot(metric: metric, values: values, status: status, updatedAt: .now)
            SharedStore.save(snapshot)
            return snapshot
        } catch DataFetchError.notAuthorized {
            return .empty(metric, status: .notAuthorized)
        } catch {
            if let cached, cached.hasData { return cached }
            return .empty(metric, status: .unavailable)
        }
    }
}
