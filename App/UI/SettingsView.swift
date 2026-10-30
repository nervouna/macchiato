import SwiftUI

struct SettingsView: View {
    @AppStorage(Config.modelKey) private var modelName = Config.defaultModel
    @AppStorage(Config.sizeKey) private var size = Config.defaultSize
    @AppStorage(Config.qualityKey) private var quality = Config.defaultQuality
    @AppStorage(Config.keepDaysKey) private var keepDays = Config.defaultKeepDays
    @State private var key = ""
    @State private var launchAtLogin = AppModel.shared.launchesAtLogin
    private let model = AppModel.shared

    var body: some View {
        Form {
            Section {
                SecureField("OpenAI API Key", text: $key, prompt: Text(model.hasKey ? LocalizedStringKey("Saved. Enter a new key to replace it") : LocalizedStringKey("sk-…")))
                    .onSubmit(save)
                HStack {
                    Button("Save", action: save).disabled(key.isEmpty)
                    if model.hasKey { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                }
            }
            Section {
                Picker("Resolution", selection: $size) {
                    Text("4K  3840×2160").tag("3840x2160")
                    Text("2K  2560×1440").tag("2560x1440")
                }
                Picker("Quality", selection: $quality) {
                    ForEach(["max", "xhigh", "high", "medium"], id: \.self) { Text($0).tag($0) }
                }
                TextField("Model", text: $modelName)
                Stepper("Keep \(keepDays) days", value: $keepDays, in: 3...90)
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in model.launchesAtLogin = newValue }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        model.saveKey(key)
        key = ""
    }
}
