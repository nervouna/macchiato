import SwiftUI

struct MenuView: View {
    private let model = AppModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let preview = model.preview {
                    Image(nsImage: preview).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 292, height: 164)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.themeTitle).font(.headline)
                if !model.statusLine.isEmpty {
                    Text(model.statusLine)
                        .font(.caption)
                        .foregroundStyle(model.isFailed ? Color.red : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Button { model.regenerate() } label: { Label("Regenerate", systemImage: "arrow.clockwise") }
                    .disabled(model.isWorking)
                Button { model.openFolder() } label: { Image(systemName: "folder") }
                    .help("Open folder")
                    .accessibilityLabel("Open folder")
                Spacer()
                Button {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                } label: { Image(systemName: "gearshape") }
                .help("Settings")
                .accessibilityLabel("Settings")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                    .help("Quit")
                    .accessibilityLabel("Quit")
            }
        }
        .padding(14)
        .frame(width: 320)
    }
}
