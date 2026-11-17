import SwiftUI

struct ThemeSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let colorBinding = Binding<Color>(
            get: { model.theme.color },
            set: { model.theme = ThemeColor(color: $0) })

        NavigationStack {
            Form {
                Section {
                    preview
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section("プリセット") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 14) {
                        ForEach(ThemePreset.all) { preset in
                            Button { model.theme = preset.theme } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(preset.theme.color)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            if preset.theme == model.theme {
                                                Image(systemName: "checkmark")
                                                    .font(.headline.weight(.bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    Text(preset.name)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(preset.theme == model.theme ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    ColorPicker("好きな色を選ぶ", selection: colorBinding, supportsOpacity: false)
                } header: {
                    Text("カスタム")
                } footer: {
                    Text("選んだ色はホーム画面のウィジェットにも反映されます。")
                }
            }
            .navigationTitle("色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    private var preview: some View {
        let snapshot = model.snapshots[.steps].flatMap { $0.hasData ? $0 : nil } ?? DemoData.snapshot(for: .steps)
        return VStack(spacing: 10) {
            HeatmapGrid(snapshot: snapshot, scale: IntensityScale(snapshot: snapshot), theme: model.theme,
                        weeks: 17, cellSize: 14, spacing: 3)
            HeatmapLegend(theme: model.theme)
        }
        .padding(.vertical, 8)
    }
}
