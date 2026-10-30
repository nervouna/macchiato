import Foundation

/// Produces a day's light/dark pair: renders the light image, then the dark one as an edit of it.
enum Generator {
    static let lightMinimum = 120.0  // mean luminance (0-255) a light image must reach
    static let darkMaximum = 70.0    // and a dark image must stay under
    static let attempts = 3

    struct Result: Sendable {
        var pair: Store.Pair
        var prompts: Prompts
    }

    /// Reuses the files already in the day's folder unless `force` is set.
    static func run(day: Day, settings: GenerationSettings, force: Bool,
                    progress: @escaping @Sendable (String) -> Void) async throws -> Result {
        let prompts = Season.prompts(for: day)
        let folder = Store.folder(for: day, size: settings.size)
        let pair = Store.pair(in: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if force {
            try? FileManager.default.removeItem(at: pair.light)
            try? FileManager.default.removeItem(at: pair.dark)
        }
        let manager = FileManager.default
        if manager.fileExists(atPath: pair.light.path) && manager.fileExists(atPath: pair.dark.path) {
            return Result(pair: pair, prompts: prompts)
        }

        guard let key = Keychain.apiKey else { throw GenerationError.missingKey }
        let client = OpenAIImages(apiKey: key, model: settings.model, quality: settings.quality)

        if !manager.fileExists(atPath: pair.light.path) {
            try await render(to: pair.light, accept: { $0 >= lightMinimum }, kind: .light, progress: progress) {
                try await client.generate(prompt: prompts.day, size: settings.size)
            }
        }
        if !manager.fileExists(atPath: pair.dark.path) {
            let light = try Data(contentsOf: pair.light)
            try await render(to: pair.dark, accept: { $0 <= darkMaximum }, kind: .dark, progress: progress) {
                try await client.edit(prompt: prompts.night, image: light, size: settings.size)
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(prompts).write(to: folder.appendingPathComponent("prompts.json"))
        return Result(pair: pair, prompts: prompts)
    }

    private enum Kind { case light, dark }

    private static func message(for kind: Kind, attempt: Int) -> String {
        switch (kind, attempt) {
        case (.light, 1): String(localized: "Generating the light image")
        case (.dark, 1): String(localized: "Generating the dark image")
        case (.light, _): String(localized: "Redrawing the light image (attempt \(attempt))")
        case (.dark, _): String(localized: "Redrawing the dark image (attempt \(attempt))")
        }
    }

    /// Writes make() to `url`, retrying while the mean luminance is out of range; keeps the last attempt.
    private static func render(to url: URL, accept: (Double) -> Bool, kind: Kind,
                               progress: @Sendable (String) -> Void, make: () async throws -> Data) async throws {
        for attempt in 1...attempts {
            progress(message(for: kind, attempt: attempt))
            try await make().write(to: url, options: .atomic)
            if let value = Imaging.meanLuminance(of: url), !accept(value) { continue }
            return
        }
    }
}
