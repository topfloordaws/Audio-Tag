# AGENTS.md

Shared instructions for every AI coding tool used on this repo (Claude Code, Codex, Gemini).
`CLAUDE.md` and `GEMINI.md` point here, so keep this file as the single source of truth.

## Project

Audio Tag is a macOS SwiftUI app for editing audio metadata (title, artist, album,
album artist, track, genre, year, comment, artwork) and converting between formats.

- **MP3 tags:** read and written with TagLib via an Obj-C++ wrapper
  (`Audio Tag/TagLibWrapper.h/.mm`, called from `Audio Tag/TagLib.swift`). Writes ID3v2.3 only.
- **M4A / WAV tags and all conversions:** FFmpegKit (`Audio Tag/AudioConverter.swift`).
- **UI:** almost everything is in `Audio Tag/ContentView.swift` (file table, sidebar editor,
  batch editor, audio player).

## Layout

| Path | What it is |
|---|---|
| `Audio Tag/` | App source (Swift, Obj-C++ wrapper, assets) |
| `Audio Tag.xcodeproj` | Xcode project |
| `Packages/swift-taglib` | Vendored TagLib (third-party, do not edit) |
| `*.framework`, `Audio Tag/bundle-apple-framework-macos/` | Vendored FFmpegKit binaries (do not edit) |
| `TagLibBridge/` | Old, stale copy of the TagLib wrapper. Not the live one |
| `Resources/ffmpeg` | 80 MB standalone binary, appears unused |
| `docs/code-review.md` | Code review: known bugs and the cleanup plan |

## Build and test

```bash
xcodebuild -project "Audio Tag.xcodeproj" -scheme "Audio Tag" -configuration Debug build
```

```bash
xcodebuild -project "Audio Tag.xcodeproj" -scheme "Audio Tag" test
```

The test targets are still empty templates.

## Rules for agents

- Read `docs/code-review.md` before starting work. It lists known bugs and the agreed priority order.
- Only edit app source in `Audio Tag/`. Never edit vendored code in `Packages/` or the frameworks.
- Work on a branch, never directly on `main`. Keep one task per branch.
- Only one agent edits a given branch at a time. Other agents may review but should not edit.
- Build with `xcodebuild` after changes and report whether it succeeded.
- When you finish a task from `docs/code-review.md`, tick it off there.
