import SwiftUI

/// 初回起動時。説明のあとヘルスケアと写真へのアクセスを求める。
struct OnboardingView: View {
    let onFinish: () -> Void
    @Environment(AppModel.self) private var model
    @State private var isRequesting = false

    var body: some View {
        let demo = DemoData.snapshot(for: .steps)
        VStack(spacing: 28) {
            Spacer(minLength: 20)
            HeatmapGrid(snapshot: demo, scale: IntensityScale(snapshot: demo), theme: model.theme,
                        weeks: 15, cellSize: 15, spacing: 3)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("生活ヒートマップ")
                    .font(.largeTitle.weight(.bold))
                Text("毎日の生活を、草のようなヒートマップに。\n手入力はいりません。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Metric.allCases) { metric in
                    HStack(spacing: 14) {
                        Image(systemName: metric.symbol)
                            .font(.title3)
                            .foregroundStyle(model.theme.color)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.title).font(.headline)
                            Text(metric.sourceName + "から自動で取得").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isRequesting = true
                    Task {
                        await model.requestPermissions()
                        isRequesting = false
                        onFinish()
                    }
                } label: {
                    Text("アクセスを許可してはじめる")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isRequesting)

                Button("あとで") { onFinish() }
                    .foregroundStyle(.secondary)

                Text("データの読み取りのみ行い、端末の外には送信しません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }
}
