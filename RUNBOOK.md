# ResetStat Runbook

ResetStat is a native macOS menu bar app built with Swift Package Manager. It targets macOS 13 or newer.

## Run Locally

From the repo root:

```sh
swift run ResetStat
```

This starts the menu bar app directly from SwiftPM. Look for the `S` icon in the macOS menu bar. The app has no Dock icon.

## Test

```sh
swift test
```

## Build the Executable

```sh
swift build -c release
```

The release executable is written under SwiftPM's release build directory. You can inspect the path with:

```sh
swift build -c release --show-bin-path
```

## Build the `.app` Bundle

```sh
Scripts/build-app.sh
```

This generates the icon, builds the release binary, and creates:

```text
.build/ResetStat.app
```

Launch it with:

```sh
open .build/ResetStat.app
```

## OpenCode Go Setup

OpenCode Go usage is scraped from the OpenCode dashboard, because the CLI token does not expose the dashboard usage windows.

To configure it:

```sh
Scripts/configure-opencode-go.sh
```

You will need:

- workspace id from a URL like `https://opencode.ai/workspace/<workspace-id>/go`
- browser cookie value named `auth` for `opencode.ai`

The script writes:

```text
~/.config/opencode/opencode-quota/opencode-go.json
```

Restart ResetStat or click refresh in the popover after configuring it.
