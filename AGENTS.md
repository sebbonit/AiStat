# Repository Guidelines

## Project Structure & Module Organization

ResetStat is a Swift Package Manager project for a native macOS 13+ menu bar app.

- `Sources/ResetStat/` contains the executable app target, SwiftUI views, app entry point, and configuration UI/state.
- `Sources/ResetStatCore/` contains provider clients, API models, usage formatting, and shared business logic.
- `Tests/ResetStatTests/` covers app-level behavior such as menu bar status and configuration.
- `Tests/ResetStatCoreTests/` covers core parsing/client behavior; JSON fixtures live in `Tests/ResetStatCoreTests/Fixtures/`.
- `Resources/` contains app bundle resources such as `Info.plist` and the icon.
- `Scripts/` contains local setup and packaging helpers.

## Build, Test, and Development Commands

Run commands from the repository root.

- `swift run ResetStat` starts the menu bar app from SwiftPM.
- `swift test` runs all package tests.
- `swift build -c release` builds an optimized executable.
- `swift build -c release --show-bin-path` prints the release binary directory.
- `Scripts/build-app.sh` generates the icon, builds release, and creates `.build/ResetStat.app`.
- `Scripts/configure-opencode-go.sh` writes OpenCode Go quota configuration for local testing.

## Coding Style & Naming Conventions

Use idiomatic Swift with 4-space indentation. Keep UI-specific code in `ResetStat` and provider/client logic in `ResetStatCore`. Name types with `UpperCamelCase`, methods and properties with `lowerCamelCase`, and files after the primary type or feature, for example `DesktopQuotaClient.swift` or `ResetStatConfigurationStore.swift`.

Prefer small, testable structs/classes and explicit error types. Keep provider-specific models and parsing close to the matching client.

## Testing Guidelines

The project uses SwiftPM/XCTest test targets. Add tests next to the behavior being changed: core logic in `ResetStatCoreTests`, app/configuration behavior in `ResetStatTests`. Name tests with clear behavior statements, such as `testFormatsUsageWindow()` or `testDisabledProviderIsHidden()`.

When adding or changing JSON parsing, include compact fixture files under `Tests/ResetStatCoreTests/Fixtures/` and load them from the test target resources. Run `swift test` before opening a PR.

## Commit & Pull Request Guidelines

Recent history uses short, imperative commit subjects such as `Add menu bar status indicators and tests`. Keep commits focused and mention tests when relevant.

Pull requests should include a brief description, screenshots for visible UI changes, linked issues when applicable, and notes about local verification such as `swift test` or `Scripts/build-app.sh`.

## Security & Configuration Tips

Do not commit local provider credentials, cookies, generated configs, or files from `~/Library/Application Support/ResetStat/`. Keep `.build/` artifacts out of commits.
