# Repository Guidelines

## Project Structure & Module Organization

The Xcode project contains one macOS application target. Production Swift code lives in `Bitcoin-Monitoring/`, grouped by responsibility: `Core/` owns app startup and the menu-bar controller, `Views/` contains SwiftUI screens, `Windows/` manages AppKit windows, `Managers/` handles settings and price retrieval, `Models/` defines domain and API types, and `Utils/` contains URL and icon helpers. App icons, audio, entitlements, and asset catalogs belong in `Resources/`; keep Xcode previews in `Preview Content/`. Repository-level screenshots used by `README.md` live in `assets/`.

## Build, Test, and Development Commands

- `open "Bitcoin Monitoring.xcodeproj"` opens the project in Xcode. Select the **Bitcoin Monitoring** scheme and use Cmd+R for local development.
- `xcodebuild -project "Bitcoin Monitoring.xcodeproj" -scheme "Bitcoin Monitoring" -configuration Debug build` performs a command-line debug build.
- `xcodebuild -project "Bitcoin Monitoring.xcodeproj" -scheme "Bitcoin Monitoring" -configuration Release archive` creates a release archive.
- `xcodebuild -project "Bitcoin Monitoring.xcodeproj" -scheme "Bitcoin Monitoring" clean` removes Xcode build products.

The app requires macOS and network access to Binance's public API. Do not treat simulator-service warnings as app failures; this target runs on macOS.

## Coding Style & Naming Conventions

Follow existing Swift conventions: four-space indentation, one primary type per file, `UpperCamelCase` for types, and `lowerCamelCase` for properties and functions. Name files after their main type, such as `PriceManager.swift`. Keep UI work on the main actor, prefer `async`/`await` for network operations, and organize longer files with `// MARK:` sections. No formatter or linter is configured, so use Xcode formatting and keep diffs focused.

## Testing Guidelines

There is currently no test target or coverage threshold. Before submitting, build the Debug configuration and manually verify menu-bar display, refresh behavior, preferences persistence, proxy settings, custom-symbol validation, and Option-click actions. For logic-heavy changes, add an XCTest target and name tests `test_<behavior>_<expectedResult>()`.

## Commit & Pull Request Guidelines

Recent history favors short, imperative subjects, commonly prefixed with `feat:`; use similarly scoped prefixes such as `fix:`, `docs:`, or `refactor:`. Keep each commit to one coherent change. Pull requests should explain user-visible behavior, list manual verification steps, link relevant issues, and include screenshots for menu or preferences UI changes. Never commit proxy credentials, local Xcode user data, or build artifacts.
