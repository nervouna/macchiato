import AppKit
import Observation
import ServiceManagement
@preconcurrency import UserNotifications

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    enum Phase: Equatable {
        case idle
        case working(String)
        case failed(String)
    }

    var phase: Phase = .idle
    var theme: Prompts?
    var preview: NSImage?
    var hasKey = Keychain.apiKey != nil

    private let wallpaper = WallpaperService()
    private var task: Task<Void, Never>?
    private var started = false

    var menuSymbol: String {
        switch phase {
        case .idle: "circle.lefthalf.filled"
        case .working: "arrow.triangle.2.circlepath"
        case .failed: "exclamationmark.triangle"
        }
    }

    var themeTitle: String {
        guard let theme else { return "Macchiato" }
        let term = NSLocalizedString("term.\(theme.term)", comment: "")
        let style = NSLocalizedString("style.\(theme.style)", comment: "")
        return theme.termDay ? String(localized: "\(term) (today) · \(style)") : String(localized: "\(term) · \(style)")
    }

    var statusLine: String {
        switch phase {
        case .idle: hasKey ? "" : String(localized: "Add your API key in Settings")
        case .working(let step): step
        case .failed(let message): message
        }
    }

    var isWorking: Bool {
        if case .working = phase { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    func start() {
        guard !started else { return }
        started = true
        wallpaper.onApplied = { [weak self] url in
            self?.preview = Imaging.thumbnail(of: url, maxPixel: 720)
        }
        wallpaper.start()
        theme = Season.prompts(for: Day(Date()))
        registerLoginItemOnce()

        let center = NotificationCenter.default
        center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.catchUp() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.catchUp() }
        }
        // Retry transient failures (no network at midnight, rate limits) without user action.
        Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.catchUp() }
        }
        catchUp()
    }

    /// Generates today's pair if it is missing; otherwise just makes sure it is the current wallpaper.
    func catchUp() {
        if case .failed = phase, lastFailureWasPermanent { return }
        generate(force: false)
    }

    func regenerate() {
        lastFailureWasPermanent = false
        generate(force: true)
    }

    private var lastFailureWasPermanent = false

    private func generate(force: Bool) {
        guard task == nil else { return }
        hasKey = Keychain.apiKey != nil
        let day = Day(Date())
        let settings = Config.current
        theme = Season.prompts(for: day)
        phase = .working(String(localized: "Getting ready"))
        task = Task { [weak self] in
            do {
                let result = try await Generator.run(day: day, settings: settings, force: force) { step in
                    Task { @MainActor in AppModel.shared.phase = .working(step) }
                }
                try Store.writeManifest(result.pair)
                self?.wallpaper.use(result.pair)
                Store.prune(before: day, keepDays: settings.keepDays)
                self?.finish(.idle)
            } catch {
                let permanent = (error as? GenerationError)?.isPermanent ?? false
                self?.lastFailureWasPermanent = permanent
                self?.finish(.failed(error.localizedDescription))
                Self.notifyFailure(error.localizedDescription)
            }
        }
    }

    private func finish(_ phase: Phase) {
        self.phase = phase
        task = nil
    }

    func openFolder() {
        try? FileManager.default.createDirectory(at: Store.root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Store.root)
    }

    func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { Keychain.delete() } else { Keychain.write(trimmed) }
        hasKey = Keychain.apiKey != nil
        lastFailureWasPermanent = false
        if hasKey, case .failed = phase { catchUp() }
    }

    // MARK: Login item

    var launchesAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            if newValue { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        }
    }

    private func registerLoginItemOnce() {
        #if !DEBUG
        let key = "didRegisterLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? SMAppService.mainApp.register()
        #endif
    }

    private static func notifyFailure(_ message: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Macchiato"
            content.body = String(localized: "Today's wallpaper was not generated: \(message)")
            center.add(UNNotificationRequest(identifier: "failure", content: content, trigger: nil))
        }
    }
}
