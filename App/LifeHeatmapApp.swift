import SwiftUI
import WidgetKit

@main
struct LifeHeatmapApp: App {
    @State private var model: AppModel
    @AppStorage("didOnboard") private var didOnboard = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        SharedStore.demoMode = ProcessInfo.processInfo.arguments.contains("-demoData")
        #else
        SharedStore.demoMode = false
        #endif
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if didOnboard {
                    HomeView()
                } else {
                    OnboardingView { didOnboard = true }
                }
            }
            .environment(model)
            .tint(model.theme.color)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, didOnboard { Task { await model.refresh() } }
            }
        }
    }
}

@Observable
@MainActor
final class AppModel {
    var snapshots: [Metric: MetricSnapshot] = [:]
    var isLoading = false
    var theme: ThemeColor {
        didSet {
            guard theme != oldValue else { return }
            SharedStore.theme = theme
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    init() {
        theme = SharedStore.theme
        for metric in Metric.allCases {
            snapshots[metric] = SharedStore.demoMode ? DemoData.snapshot(for: metric) : SharedStore.snapshot(for: metric)
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        await withTaskGroup(of: MetricSnapshot.self) { group in
            for metric in Metric.allCases {
                group.addTask { await HeatmapRepository.load(metric) }
            }
            for await snapshot in group {
                snapshots[snapshot.metric] = snapshot
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func requestPermissions() async {
        await MetricDataSource.requestHealthAuthorization()
        await MetricDataSource.requestPhotosAuthorization()
        await refresh()
    }
}
