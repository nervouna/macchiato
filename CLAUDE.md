# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Macchiato is a macOS 14+ menu bar app (Swift 5, SwiftUI + AppKit, no third-party dependencies). Every day it generates a light and a dark abstract wallpaper with OpenAI's image API, coloured by the Chinese solar-term (二十四节气) calendar, and applies the one matching the system appearance.

## Commands

The Xcode project is generated: `project.yml` (XcodeGen) is the source of truth, and `Macchiato.xcodeproj/` and `Config/Info.plist` are gitignored. Needs `brew install xcodegen`.

```bash
scripts/build.sh [debug|release]       # xcodegen generate + xcodebuild -> build/Macchiato.app (debug is ad-hoc signed)
scripts/release.sh [--skip-notarize]   # Developer ID build, notarize, staple, zip -> build/release/Macchiato-<version>.zip(.sha256)
xcodegen generate                      # regenerate the project after adding/removing files or editing project.yml
xcodebuild -project Macchiato.xcodeproj -scheme Macchiato -destination 'platform=macOS' test
xcodebuild -project Macchiato.xcodeproj -scheme Macchiato -destination 'platform=macOS' test -only-testing:MacchiatoTests/SeasonTests/testDayArithmetic
```

There is no linter or formatter config. CI (`.github/workflows/ci.yml`) runs xcodegen then the test command above with `CODE_SIGN_IDENTITY=-`.

`App/Core/Season.swift` has no app dependencies, so date and solar-term logic can be swept without Xcode: put a probe in a file named `main.swift` outside the repo and run `swiftc App/Core/Season.swift <dir>/main.swift -o <dir>/probe`.

The built binary doubles as a headless CLI (handled in `App/CommandLineTool.swift`):

```bash
build/Macchiato.app/Contents/MacOS/Macchiato --print-prompt 2026-11-07   # free: prints the prompts/metadata for a date
build/Macchiato.app/Contents/MacOS/Macchiato --once [--date YYYY-MM-DD] [--size 2560x1440] [--force] [--no-apply]
```

`--once` calls the real OpenAI API with the stored key (or `MACCHIATO_OPENAI_API_KEY`) and costs money; use `--print-prompt` to check prompt changes, and `--no-apply` to avoid changing the desktop.

Release signing/notarization settings live outside the repo in `${XDG_CONFIG_HOME:-$HOME/.config}/macchiato/signing.env` (see `scripts/common.sh`). Never print or commit those values.

## Architecture

**Generation pipeline** (the core flow, spans several files): `AppModel.generate` → `Generator.run` → `OpenAIImages` → `Store`/`WallpaperService`.
- `Generator.run` is idempotent per day and size: it works in `~/Library/Application Support/Macchiato/days/YYYY-MM-DD/<size>/` and skips any of `light.png` / `dark.png` that already exist; `force` deletes both first. Pruning old day folders is separate (`Store.prune`).
- The light image is a text-to-image call (`/images/generations`); the dark image is an **edit of the light image** (`/images/edits`) so the shapes are identical. Each render is re-drawn up to 3 times if its mean luminance misses the threshold (`Generator.lightMinimum` / `darkMaximum`), then the last attempt is kept.
- `Store.writeManifest` writes `current.json` (paths of the current pair); `WallpaperService` reads it at launch and re-applies the light/dark image on appearance, wake and screen-parameter changes.

**Scheduling and failure handling** (`AppModel`): `catchUp()` runs at launch, on `NSCalendarDayChanged`, on wake and every 30 minutes. `GenerationError.isPermanent` (missing key, or an HTTP status below 500 other than 408/409/429) decides whether a failure stops the retries; saving a new key or `regenerate()` clears that. `OpenAIImages.send` additionally retries transient errors itself (20s, 60s, 180s).

**Prompts** (`App/Core/Season.swift`): the solar term comes from computing the apparent solar longitude (Meeus) at 00:00 UTC+8 of the day; `terms[i]` covers longitude `15*i` (index 0 is 春分). Style is `day.ordinal % 4` and composition `(ordinal / 4) % 4`. `Day` is a timezone-free calendar date with its own epoch-day math. Changes to prompts, palettes or date logic need a test.

**CLI/app split**: `MacchiatoApp.init` calls `CommandLineTool.runIfRequested()`; when a CLI flag is present it sets `CommandLineTool.isActive`, which hides the `MenuBarExtra` and makes `AppDelegate` skip startup. In normal mode `AppDelegate` enforces a single instance and disables automatic termination, since a menu bar app has no windows to keep it alive.

## Gotchas

- The `MacchiatoTests` target compiles **only** `App/Core/Season.swift` plus `Tests/` (see `project.yml`), not the whole app. Tests can only cover what lives in `Season.swift`; to test other code, add its file to that target's sources. The tests hardcode 2026 solar-term dates.
- SourceKit reports "No such module 'XCTest'" in `Tests/`; it is a false positive, `xcodebuild test` builds fine.
- Settings are `UserDefaults` keys defined in `Config` (`App/Core/Support.swift`), shared by `SettingsView` and the generator. The API key is in the Keychain (service `io.damao.macchiato`), and the `MACCHIATO_OPENAI_API_KEY` environment variable overrides it.
- User-visible strings go in `App/Localizable.xcstrings` with both `en` and `zh-Hans`. Solar terms and styles are looked up dynamically as `term.<name>` and `style.<name>` (`AppModel.themeTitle`), so adding a term or style requires adding those keys.
- The login item is registered on first launch only in non-`DEBUG` builds.
- `App/AppIcon.icon` is an Icon Composer document; rendering notes are in `design/README.md`.
- `CONTRIBUTING.md` asks for one change per PR, an English imperative commit subject, a description that says how it was checked, and no API keys, generated images or signing settings in commits.
