import AppKit

/// Headless entry points, so the app binary doubles as a scriptable generator:
///   Macchiato --print-prompt YYYY-MM-DD
///   Macchiato --once [--date YYYY-MM-DD] [--size WxH] [--force] [--no-apply]
///   Macchiato --save-key        (stores $MACCHIATO_OPENAI_API_KEY in the Keychain)
enum CommandLineTool {
    static var isActive = false

    static func runIfRequested() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first, ["--print-prompt", "--once", "--save-key"].contains(command) else { return }
        isActive = true

        func value(after flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        }
        func fail(_ message: String) -> Never {
            FileHandle.standardError.write(Data((message + "\n").utf8))
            exit(1)
        }

        switch command {
        case "--print-prompt":
            guard let text = value(after: command), let day = Day(text) else { fail("usage: --print-prompt YYYY-MM-DD") }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            print(String(decoding: try! encoder.encode(Season.prompts(for: day)), as: UTF8.self))
            exit(0)

        case "--save-key":
            guard let key = ProcessInfo.processInfo.environment["MACCHIATO_OPENAI_API_KEY"], !key.isEmpty else {
                fail("MACCHIATO_OPENAI_API_KEY is not set")
            }
            print(Keychain.write(key) ? "saved" : "failed")
            exit(0)

        default:
            let day = value(after: "--date").flatMap(Day.init) ?? Day(Date())
            var settings = Config.current
            if let size = value(after: "--size") { settings.size = size }
            let force = args.contains("--force")
            let apply = !args.contains("--no-apply")
            Task { @MainActor in
                do {
                    let result = try await Generator.run(day: day, settings: settings, force: force) { step in
                        print(step)
                    }
                    print("\(day) \(settings.size): \(result.prompts.theme)")
                    if apply {
                        try Store.writeManifest(result.pair)
                        WallpaperService().use(result.pair)
                        print("wallpaper applied")
                    }
                    exit(0)
                } catch {
                    fail("failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
