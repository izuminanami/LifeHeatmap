import Foundation

/// ヒートマップにできるデータの種類。ウィジェットはデータごとに別の種類として用意する。
enum Metric: String, CaseIterable, Codable, Identifiable {
    case steps
    case sleep
    case photos

    var id: String { rawValue }

    enum Source { case health, photos }

    var source: Source { self == .photos ? .photos : .health }

    var title: String {
        switch self {
        case .steps: "歩数"
        case .sleep: "睡眠時間"
        case .photos: "撮った写真"
        }
    }

    var symbol: String {
        switch self {
        case .steps: "figure.walk"
        case .sleep: "bed.double.fill"
        case .photos: "camera.fill"
        }
    }

    var sourceName: String { source == .health ? "ヘルスケア" : "写真" }

    func format(_ value: Double) -> String {
        switch self {
        case .steps: "\(Int(value.rounded()).formatted())歩"
        case .sleep: String(format: "%.1f時間", value)
        case .photos: "\(Int(value.rounded()))枚"
        }
    }
}
