import AppKit

/// Applies the light or dark image to every screen and follows appearance, wake and display changes.
@MainActor
final class WallpaperService {
    var onApplied: ((URL) -> Void)?

    private var pair: Store.Pair?
    private var pending: DispatchWorkItem?
    private var appearanceObservation: NSKeyValueObservation?

    var isDark: Bool {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    func start() {
        pair = Store.readManifest()
        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.schedule() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.schedule() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.schedule() }
        }
        apply()
    }

    /// Makes `pair` the current wallpaper. `force` re-sets screens that already show the image.
    func use(_ pair: Store.Pair, force: Bool = true) {
        self.pair = pair
        apply(force: force)
    }

    private func schedule() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.apply() }
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: item)
    }

    private func apply(force: Bool = false) {
        guard let pair else { return }
        let url = isDark ? pair.dark : pair.light
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        for screen in NSScreen.screens where force || NSWorkspace.shared.desktopImageURL(for: screen)?.path != url.path {
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
        }
        onApplied?(url)
    }
}
