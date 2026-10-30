import AppKit
import ImageIO
import Security

/// User-adjustable generation settings, shared by the Settings window (@AppStorage) and the generator.
enum Config {
    static let modelKey = "model"
    static let sizeKey = "size"
    static let qualityKey = "quality"
    static let keepDaysKey = "keepDays"

    static let defaultModel = "gpt-image-2.5-sunburst"
    static let defaultSize = "3840x2160"
    static let defaultQuality = "max"
    static let defaultKeepDays = 14

    static var current: GenerationSettings {
        let defaults = UserDefaults.standard
        return GenerationSettings(
            model: defaults.string(forKey: modelKey).flatMap { $0.isEmpty ? nil : $0 } ?? defaultModel,
            size: defaults.string(forKey: sizeKey) ?? defaultSize,
            quality: defaults.string(forKey: qualityKey) ?? defaultQuality,
            keepDays: defaults.object(forKey: keepDaysKey) as? Int ?? defaultKeepDays)
    }
}

struct GenerationSettings: Sendable {
    var model: String
    var size: String
    var quality: String
    var keepDays: Int
}

/// Files under ~/Library/Application Support/Macchiato: days/YYYY-MM-DD/<size>/{light,dark}.png and current.json.
enum Store {
    static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Macchiato", isDirectory: true)
    static let manifest = root.appendingPathComponent("current.json")

    static func folder(for day: Day, size: String) -> URL {
        root.appendingPathComponent("days/\(day)/\(size)", isDirectory: true)
    }

    struct Pair: Equatable, Sendable {
        var light: URL
        var dark: URL
    }

    static func pair(in folder: URL) -> Pair {
        Pair(light: folder.appendingPathComponent("light.png"), dark: folder.appendingPathComponent("dark.png"))
    }

    static func isComplete(_ pair: Pair) -> Bool {
        let manager = FileManager.default
        return manager.fileExists(atPath: pair.light.path) && manager.fileExists(atPath: pair.dark.path)
    }

    static func writeManifest(_ pair: Pair) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: ["light": pair.light.path, "dark": pair.dark.path])
        try data.write(to: manifest, options: .atomic)
    }

    static func readManifest() -> Pair? {
        guard let data = try? Data(contentsOf: manifest),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let light = json["light"], let dark = json["dark"] else { return nil }
        let pair = Pair(light: URL(fileURLWithPath: light), dark: URL(fileURLWithPath: dark))
        return isComplete(pair) ? pair : nil
    }

    /// Removes day folders that are `keepDays` or more days older than `day`.
    static func prune(before day: Day, keepDays: Int) {
        let days = root.appendingPathComponent("days")
        let entries = (try? FileManager.default.contentsOfDirectory(at: days, includingPropertiesForKeys: nil)) ?? []
        for entry in entries {
            guard let entryDay = Day(entry.lastPathComponent), day.epochDays - entryDay.epochDays >= keepDays else { continue }
            try? FileManager.default.removeItem(at: entry)
        }
    }
}

enum Keychain {
    private static let service = "io.damao.macchiato"
    private static let account = "openai-api-key"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let key = String(data: data, encoding: .utf8) else { return nil }
        return key
    }

    @discardableResult
    static func write(_ key: String) -> Bool {
        let data = Data(key.utf8)
        if SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecSuccess { return true }
        var item = query
        item[kSecValueData as String] = data
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }

    /// The environment variable wins, so scripts and CI can override the stored key.
    static var apiKey: String? {
        if let fromEnvironment = ProcessInfo.processInfo.environment["MACCHIATO_OPENAI_API_KEY"], !fromEnvironment.isEmpty {
            return fromEnvironment
        }
        return read().flatMap { $0.isEmpty ? nil : $0 }
    }
}

enum Imaging {
    /// Mean luminance on a 0-255 scale, measured on a small downscale.
    static func meanLuminance(of url: URL) -> Double? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let width = 96, height = 54
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Double(pixels.reduce(0) { $0 + Int($1) }) / Double(pixels.count)
    }

    static func thumbnail(of url: URL, maxPixel: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
