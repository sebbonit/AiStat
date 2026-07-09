# ResetStat — AI Coding Usage Tracker for macOS

> **Track your AI coding assistant usage and quotas in the macOS menu bar.** ResetStat is a native, lightweight macOS menu bar app that monitors usage limits, reset windows, billing cycles, and renewal dates for Codex, Cursor, Devin, and OpenCode Go — all in one glance.

[![Swift 6.0](https://img.shields.io/badge/swift-6.0-orange.svg)](https://swift.org)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue.svg)](https://apple.com/macos)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Tests: 104](https://img.shields.io/badge/tests-104-brightgreen.svg)](#testing)

<img src="Resources/ResetStat.icns" width="96" height="96" alt="ResetStat — macOS menu bar AI usage tracker app icon" />

<!-- TODO: Add screenshots -->
<!-- <img src="docs/screenshots/menu-bar-overview.png" alt="ResetStat menu bar overview showing AI coding usage for Codex, Cursor, Devin, and OpenCode Go" width="460" /> -->

---

## Table of Contents

- [Overview](#overview)
- [Supported AI Coding Providers](#supported-ai-coding-providers)
- [Features](#features)
- [Menu Bar Display Modes](#menu-bar-display-modes)
- [Notifications](#notifications)
- [Usage Pace Projection](#usage-pace-projection)
- [Provider Health Diagnostics](#provider-health-diagnostics)
- [Installation](#installation)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Development](#development)
- [Testing](#testing)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

ResetStat is a **native macOS menu bar app** (no Dock icon) that aggregates usage data from multiple AI coding assistants into a single, color-coded popover. It runs quietly in the background, fetching usage data on a configurable interval and rendering live progress rings, countdown timers, and detailed metrics directly in your menu bar.

**Who is it for?** Developers who use multiple AI coding tools (Codex, Cursor, Devin, OpenCode Go) and want to avoid hitting rate limits or billing surprises. ResetStat gives you a single dashboard to monitor all of them at once.

**Key design principles:**
- **No accounts, no cloud, no telemetry** — everything runs locally on your Mac
- **Native Swift/SwiftUI** — not Electron, not a web wrapper
- **Privacy-first** — provider names can be hidden throughout the UI
- **Zero-config** — auto-detects installed providers on first launch

---

## Supported AI Coding Providers

ResetStat connects to four AI coding tools and displays their usage limits, reset windows, billing cycles, and renewal dates.

| Provider | What it tracks |
|----------|---------------|
| **Codex** (OpenAI) | Rate limits (primary/secondary windows), reset credits with per-credit expiry, token usage, daily streaks |
| **Cursor** | Plan usage in dollars, auto/API sub-limits, billing cycle, plan type |
| **Devin** (Windsurf) | Daily & weekly quota bars, overage balance, plan cycle, multi-tier local cache |
| **OpenCode Go** | Rolling / weekly / monthly usage windows, billing balance, card info, payment history |

Each provider can be individually enabled or disabled. Disabled providers are not fetched and do not appear in the menu bar.

---

## Features

### Core Usage Tracking
- **Multi-provider dashboard** — monitor Codex, Cursor, Devin, and OpenCode Go in one place
- **Live progress rings** — color-coded usage arcs in the menu bar (green → orange → red)
- **Countdown timers** — time-remaining text that updates every minute without re-fetching
- **Billing cycle tracking** — renewal dates with urgency coloring (red/orange/yellow/green)
- **Reset credit monitoring** — per-credit expiry tracking for Codex reset credits
- **Token usage metrics** — lifetime tokens, peak daily, current streaks

### Menu Bar Display
- **Logos mode** — colored progress rings with provider icons
- **Countdowns mode** — compact pills with time-remaining text (`1h30m`, `2d`, `now`)
- **Hidden/privacy mode** — anonymizes all provider names to "Provider 1–4"
- **Stale state indicator** — orange badge when cached data is shown after a fetch failure

### Notifications (macOS native)
- **Critical usage alerts** — fired when usage crosses a configurable threshold
- **Billing expiring alerts** — notified before plans renew or expire
- **Provider unavailable alerts** — notified when a provider can't be reached
- **Per-provider notification toggles** — enable/disable notifications for each provider independently
- **Custom per-provider thresholds** — set custom critical usage percentages per provider (default 90%)
- **Daily digest notification** — once-per-day summary consolidating all providers at a configurable hour
- **Quiet hours** — suppress notifications during specified hours (e.g. 22:00–07:00)
- **Test notification button** — verify macOS notification permissions are granted

### Usage Pace Projection
- **Linear pace projection** — predicts when you'll exhaust your quota or hit reset based on your current usage rate
- **"On track to exhaust" warnings** — alerts if your pace will exhaust usage before the reset window
- **"On pace to reset with X% to spare"** — reassuring message when usage is sustainable
- **Collecting state** — shows "Collecting pace data..." while gathering the two samples needed for projection

### Provider Health Diagnostics
- **Last fetch timestamp** — see when each provider was last successfully fetched
- **Connection status** — green/red/gray dot per provider (connected/failed/idle)
- **Path validation** — checks if configured executable/database paths exist
- **Last error display** — shows the most recent error message per provider
- **Test connection button** — manually trigger a connection test with elapsed-time reporting

### Refresh Configuration
- **Configurable refresh interval** — 1m, 3m, 5m, 15m, 30m, or custom (1–60 min)
- **Retry on failure** — automatic retry with configurable max attempts
- **Per-provider refresh** — refresh individual providers on demand
- **System wake handling** — clears stuck refresh state after sleep/wake

### Settings & Configuration
- **Auto-detection** — detects installed providers on first launch
- **Custom paths** — configure executable and database paths per provider
- **File picker integration** — browse for files directly from Settings
- **Automatic persistence** — settings save to disk automatically
- **Reset to defaults** — one-click reset button
- **Corrupt config recovery** — invalid configs are backed up and replaced with defaults

---

## Menu Bar Display Modes

The menu bar indicators support three display modes, configurable from Settings:

### Logos
Colored progress rings with provider icons inside. Each ring shows usage as a clockwise arc:
- **Green/blue gradients** for low usage (< 50%)
- **Orange** for moderate usage (50–70%)
- **Red** for critical usage (≥ 70%)

<!-- TODO: Add screenshot -->
<!-- <img src="docs/screenshots/menu-bar-logos.png" alt="ResetStat menu bar in logos mode showing colored progress rings for AI coding providers" width="460" /> -->

### Countdowns
Compact pills with time-remaining text (e.g. `1h30m`, `2d`, `now`) and progress-based colored borders that fill from left to right as usage grows.

### Hidden
Anonymizes all provider names to "Provider 1" through "Provider 4" throughout the UI, help text, and error messages. Menu bar icons switch to a generic symbol.

---

## Notifications

ResetStat uses native macOS notifications (UserNotifications framework) to alert you about important usage events. No push servers, no cloud — all notifications are scheduled locally.

### Notification types

| Notification | Trigger | Configurable |
|-------------|---------|-------------|
| **Critical usage** | Usage crosses the critical threshold (default 90%) | Per-provider custom threshold |
| **Billing expiring** | Plan renewal within 7 days | Toggle on/off |
| **Provider unavailable** | Provider fetch fails | Toggle on/off |
| **Daily digest** | Once per day at a configured hour | Toggle + hour picker |

### Per-provider thresholds

Set custom critical usage thresholds for each provider. For example, you can be notified when Codex hits 50% but only when Cursor hits 90%.

### Quiet hours

Suppress all notifications during specified hours. Useful for avoiding alerts late at night or during focus sessions.

### Daily digest

A once-per-day summary notification that consolidates all enabled providers into a single alert. Shows critical/warning providers and any billing renewals coming soon. Configure the delivery hour in Settings.

---

## Usage Pace Projection

ResetStat computes a **linear projection** of your usage pace by comparing two consecutive usage snapshots. This tells you whether you're on track to exhaust your quota before the reset window, or if you'll reset with usage to spare.

- **"On track to exhaust in ~3h"** — your current pace will exhaust the quota before reset (shown in orange)
- **"On pace to reset with ~15% to spare"** — your usage is sustainable through the reset window
- **"Usage stable"** — usage is not increasing or is declining
- **"Collecting pace data..."** — shown after the first sample while waiting for a second sample to compute the projection

The projection requires at least 30 seconds between samples and updates on every refresh cycle.

---

## Provider Health Diagnostics

A dedicated diagnostics section in Settings helps troubleshoot connection issues:

- **Status dot** — green (connected), red (failed), orange (path missing), gray (idle/disabled)
- **Last fetch** — timestamp of the most recent successful fetch
- **Path status** — whether the configured executable or database path exists on disk
- **Last error** — the most recent error message (if any)
- **Test connection** — button to manually trigger a fetch and report success/failure with elapsed time in milliseconds

---

## Installation

### Prerequisites

- macOS 13 (Ventura) or later
- Xcode 15+ or Swift 6.0 toolchain

### Run from source

```sh
git clone https://github.com/sebbonit/AiStat.git
cd AiStat

# Run directly from SwiftPM
swift run ResetStat
```

### Build the app bundle

```sh
Scripts/build-app.sh
open .build/ResetStat.app
```

This generates the icon, builds the release binary, and creates a standalone `.app` bundle you can drag to your Applications folder.

---

## Configuration

On first launch, ResetStat auto-detects which providers have valid paths and enables only those. You can adjust everything from the Settings tab.

### Configuration file

Settings are persisted to:

```
~/Library/Application Support/ResetStat/config.json
```

If the file becomes corrupted, it is renamed to `config.invalid.json` and defaults are loaded.

### OpenCode Go setup

OpenCode Go usage is scraped from the web dashboard because the CLI token does not expose usage windows. On first launch, ResetStat shows Settings the first time you open the popover, with an OpenCode Go dashboard form.

You will need:
- Your workspace ID from a URL like `https://opencode.ai/workspace/<workspace-id>/go`
- The browser cookie named `auth` for `opencode.ai`

The form writes `~/.config/opencode/opencode-quota/opencode-go.json`, enables OpenCode Go, and refreshes usage. `Scripts/configure-opencode-go.sh` remains available for terminal setup.

---

## Architecture

### Modules

| Module | Type | Purpose |
|--------|------|---------|
| `ResetStat` | Executable | SwiftUI app, menu bar rendering, configuration UI, notifications |
| `ResetStatCore` | Library | Provider clients, API models, usage formatting, pace projection |

### Data flow

```
User launches ResetStat
        │
        ▼
UsageViewModel.start()
        │
        ├─► Refresh loop (configurable interval, default 5 min)
        │       │
        │       ├─► CodexAppServerClient  ──► codex binary (JSON-RPC over stdio)
        │       ├─► BackendCodexAccountClient  ──► chatgpt.com API
        │       ├─► BackendResetCreditClient   ──► chatgpt.com API
        │       ├─► CursorUsageClient     ──► cursor.sh API (via SQLite auth)
        │       ├─► DesktopQuotaClient    ──► codeium.com / local protobuf / SQLite
        │       └─► OpenCodeGoUsageClient ──► opencode.ai dashboard (HTML scraping)
        │
        ├─► Notification coordinator
        │       └─► Evaluates usage summaries + billing → delivers macOS notifications
        │
        └─► Clock loop (every 1 min)
                └─► Updates @Published now for live countdowns
```

### Provider details

**Codex** — Launches the local `codex` binary in `app-server --stdio` mode and communicates via JSON-RPC over stdin/stdout. Backend APIs (`accounts/check`, reset credits) are called over HTTPS using the auth token from `~/.codex/auth.json`.

**Cursor** — Reads the auth token from the Cursor SQLite state database via the `sqlite3` CLI, then calls the Cursor gRPC-Transcoding API at `api2.cursor.sh`. Handles auto/api split limits and billing cycle tracking.

**Devin** — Uses a three-tier fallback strategy: remote protobuf API at `server.codeium.com`, local Devin language server (discovered via `ps`/`lsof`), and a local SQLite cache. Includes a hand-rolled minimal protobuf parser to avoid external dependencies.

**OpenCode Go** — Scrapes the OpenCode dashboard HTML, supporting both SolidJS reactive store (`$R[]`) and `data-slot` attribute formats. Billing is scraped from a separate billing page. Auth is read from a local JSON config or environment variables.

### Concurrency

- `UsageViewModel` is `@MainActor` for safe SwiftUI binding
- Provider clients use `async`/`await` and are `@unchecked Sendable`
- All enabled providers are fetched in parallel via `withTaskGroup`
- Refresh calls are gated with an `isRefreshing` flag to prevent overlap
- The menu bar image is rendered into an `NSImage` via `lockFocus()` / `unlockFocus()` with explicit `NSGraphicsContext` save/restore for clip operations

---

## Development

### Build

```sh
# Debug build
swift build

# Release build
swift build -c release

# Show release binary path
swift build -c release --show-bin-path
```

### Test

```sh
# Run all tests
swift test
```

### Project structure

```
AiStat/
├── Package.swift
├── Sources/
│   ├── ResetStat/               # App target
│   │   ├── ResetStatApp.swift          # @main, MenuBarExtra entry point
│   │   ├── ResetStatPopover.swift      # Popover with tab bar and content switching
│   │   ├── UsageViewModel.swift        # State management, refresh loops, diagnostics
│   │   ├── UsageViewModel+MenuBar.swift # Menu bar status derivation
│   │   ├── UsageViewModel+Summary.swift # Provider summary aggregation
│   │   ├── ResetStatConfiguration.swift       # Config models, auto-detect, migration
│   │   ├── ResetStatConfigurationStore.swift  # JSON persistence
│   │   ├── SettingsSection.swift       # Settings tab UI (providers, refresh, notifications, diagnostics)
│   │   ├── OverviewSection.swift       # Overview tab with all-provider summary
│   │   ├── CodexSection.swift          # Codex provider tab
│   │   ├── CursorSection.swift         # Cursor provider tab
│   │   ├── DevinSection.swift          # Devin provider tab
│   │   ├── OpenCodeGoSection.swift     # OpenCode Go provider tab
│   │   ├── SharedViews.swift           # Shared UI components (PaceProjectionLine, StatusLine, etc.)
│   │   ├── UsageNotifications.swift    # Notification coordinator and delivery
│   │   ├── MenuBarStatusModels.swift   # Menu bar status types and diagnostic models
│   │   ├── MenuBarStatusLabel.swift    # Menu bar label view
│   │   └── MenuBarStatusImageRenderer.swift # NSImage rendering for menu bar
│   └── ResetStatCore/           # Library target
│       ├── CodexAppServerClient.swift        # Codex JSON-RPC over stdio
│       ├── BackendCodexAccountClient.swift    # Codex account/renewal API
│       ├── BackendResetCreditClient.swift     # Codex reset credits API
│       ├── CodexModels.swift                  # Shared models across all providers
│       ├── CodexUsageError.swift              # Error types
│       ├── CursorUsageClient.swift            # Cursor API + SQLite auth
│       ├── DesktopQuotaClient.swift           # Devin protobuf + SQLite
│       ├── OpenCodeGoUsageClient.swift        # OpenCode dashboard scrapers
│       ├── UsageFormatting.swift              # Time, money, number formatting
│       └── UsagePaceProjection.swift          # Linear pace projection logic
├── Tests/
│   ├── ResetStatTests/
│   │   ├── MenuBarStatusTests.swift           # Menu bar display mode tests
│   │   ├── UsageNotificationTests.swift       # Notification coordinator tests
│   │   ├── ResetStatConfigurationTests.swift  # Config persistence + migration tests
│   │   ├── ProviderDiagnosticsTests.swift     # Provider diagnostics tests
│   │   └── UsageViewModelTests.swift          # View model + pace projection tests
│   └── ResetStatCoreTests/
│       ├── ResetStatCoreTests.swift           # Parsing + formatting tests
│       ├── UsagePaceProjectionTests.swift     # Pace projection unit tests
│       └── Fixtures/                          # JSON/HTML test fixtures
├── docs/
│   └── screenshots/                           # Screenshots for README
├── Resources/
│   ├── Info.plist
│   └── ResetStat.icns
├── Scripts/
│   ├── build-app.sh                # Build .app bundle
│   ├── configure-opencode-go.sh    # Terminal fallback for OpenCode Go config
│   └── generate-icon.swift         # Generate .icns from source
├── AGENTS.md                       # Agent guidelines
└── README.md
```

### Refresh lifecycle

- The view model starts two async loops on launch
- **Refresh loop**: fetches all enabled providers on a configurable interval (default 5 minutes) using `withTaskGroup` for parallelism
- **Clock loop**: updates the `now` property every minute so countdown timers stay accurate without re-fetching
- **Notification coordinator**: evaluates usage summaries and billing expiries after each refresh, delivering macOS notifications as needed
- Disabling a provider clears its cached snapshot and marks its state as `.disabled`

### Severity system

Menu bar indicators use four severity levels, derived from usage percentage:

| Severity | Threshold | Ring color | Countdown pill color |
|----------|-----------|------------|---------------------|
| Unavailable | No data | Gray slash | Gray pill |
| Healthy | < 70% | Provider gradient | Provider color |
| Warning | 70–89% | Orange | Orange |
| Critical | ≥ 90% | Red | Red |

When a provider fetch fails but cached data exists, the indicator shows a **stale** state with an orange badge and the cached severity level.

---

## Testing

ResetStat includes 104 tests across 8 test suites:

| Suite | Tests | Covers |
|-------|-------|--------|
| Core parsing & formatting | ~25 | JSON fixtures for all four providers, HTML scraping, protobuf decoding, billing parsing |
| Usage pace projection | 8 | Exhaustion projection, stable usage, spare calculation, short elapsed |
| Menu bar status indicators | 12 | Loading/warning/critical/stale/unavailable states, privacy mode, countdown mode |
| Notification coordinator | 20+ | Critical usage, billing, unavailable, per-provider thresholds, daily digest, quiet hours |
| ResetStat configuration | 15+ | Save/reload, auto-detection, legacy migration, bad JSON, daily digest clamping |
| Refresh configurability | 5+ | Interval changes, retry, per-provider refresh gating, overlap prevention |
| Provider diagnostics | 2 | Connection test success/failure results |
| Dashboard deep links | 3 | Tab navigation from overview |

```sh
swift test
```

---

## FAQ

**Does ResetStat send any data to a server?**
No. ResetStat runs entirely locally. It fetches usage data directly from provider APIs and dashboards using credentials already on your machine. No telemetry, no analytics, no phone-home.

**Does ResetStat store my passwords or tokens?**
ResetStat reads auth tokens from existing locations (e.g. `~/.codex/auth.json`, Cursor's SQLite database) but does not store or transmit them. The only thing saved to disk is your configuration file at `~/Library/Application Support/ResetStat/config.json`.

**Why does OpenCode Go require a cookie?**
The OpenCode Go CLI token does not expose usage windows. ResetStat scrapes the web dashboard, which requires the `auth` cookie from your browser session. This cookie is stored locally and never transmitted anywhere except opencode.ai.

**Will pace projection work immediately?**
Pace projection needs two usage samples taken at least 30 seconds apart. After the first refresh, you'll see "Collecting pace data..." — the actual projection appears after the next refresh cycle.

**Can I hide provider names for screenshots?**
Yes. Enable "Hidden" display mode in Settings to anonymize all provider names to "Provider 1–4" throughout the UI, help text, and error messages.

**How do I report a bug or request a feature?**
Open an issue on [GitHub](https://github.com/sebbonit/AiStat/issues).

---

## Contributing

Pull requests are welcome. Please keep commits focused, add tests for new behavior, and verify with `swift test` before opening a PR.

### Adding a new provider

1. Create a client conforming to an async fetch protocol in `Sources/ResetStatCore/`
2. Add models and parsing logic with JSON/HTML fixtures in `Tests/ResetStatCoreTests/Fixtures/`
3. Add a `ProviderTab` case and a section view in `Sources/ResetStat/`
4. Wire up the view model refresh path and notification coordinator
5. Add tests in both `ResetStatTests` and `ResetStatCoreTests`

---

## License

MIT
