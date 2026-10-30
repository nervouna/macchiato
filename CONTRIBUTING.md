# Contributing

Macchiato is a personal project. Bug reports and fixes are welcome; for a new feature, open an issue first so we can agree on it before you write code.

## Development

You need Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
scripts/build.sh debug      # generates the Xcode project and builds build/Macchiato.app
xcodebuild -project Macchiato.xcodeproj -scheme Macchiato -destination 'platform=macOS' test
```

`project.yml` is the source of truth for the project; `Macchiato.xcodeproj` and `Config/Info.plist` are generated and ignored by Git. The tests cover the solar-term calculation and the prompt rules in `App/Core/Season.swift`, and CI runs them on every push and pull request. Changes to the prompts, the palettes or the date logic should come with a test.

Strings that users see go in `App/Localizable.xcstrings` with both English and Simplified Chinese.

## Pull requests

Keep a pull request to one change, write the commit subject in English in the imperative mood, and say in the description how you checked it. Do not commit API keys, generated images or signing settings.
