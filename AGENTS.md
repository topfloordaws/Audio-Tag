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
| `Audio Tag/bundle-apple-framework-macos/` | Vendored FFmpegKit + FFmpeg libraries embedded in the app (do not edit) |
| `Audio Tag/ffmpegkit.framework` | Second FFmpegKit copy whose headers the build compiles against (first on the framework search path). Not embedded, but needed: removing it breaks the build |
| `docs/code-review.md` | Code review: known bugs and the cleanup plan |

## Build and test

```bash
xcodebuild -project "Audio Tag.xcodeproj" -scheme "Audio Tag" -configuration Debug build
```

```bash
xcodebuild -project "Audio Tag.xcodeproj" -scheme "Audio Tag" test
```

The test targets are still empty templates.

## Behaviors to preserve

- **Spotify picks up re-tagged files immediately.** After Apply Tags, the song shows up in Spotify's Local Files
  right away (as a new entry next to the old one), with no folder refresh needed, unlike Mp3tag. The owner wants this.
  M4A/WAV are written to a temporary `name.tmp.<ext>` file in the same folder and then swapped over the original,
  which creates new-file events Spotify's folder watcher sees. Don't change how files are written (temp file location,
  in-place vs. replace) without checking this still works.
- **⌘S applies tags** (single-file editor and batch editor). It is disabled when there are no unsaved changes, and the
  batch editor asks for confirmation. Don't bind plain Return/Enter to applying tags: Return is pressed by reflex in
  text fields and would write files by accident.

## Rules for agents

- Read `docs/code-review.md` before starting work. It lists known bugs and the agreed priority order.
- Only edit app source in `Audio Tag/`. Never edit vendored code in `Packages/` or the frameworks.
- Work on a branch, never directly on `main`. Keep one task per branch.
- Only one agent edits a given branch at a time. Other agents may review but should not edit.
- Build with `xcodebuild` after changes and report whether it succeeded.
- When you finish a task from `docs/code-review.md`, tick it off there.
