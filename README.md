# Audio Tag

A macOS app for editing the metadata of your audio files and converting between formats.

## Features

- Open a folder and see every MP3, M4A and WAV file in a sortable, searchable table (⌘O to open, ⌘R to refresh, ⌘F to search)
- Edit title, artist, album, album artist, track, genre, year and comment, then press ⌘S to apply (the editor shows when there are unsaved changes)
- Add, replace or extract cover artwork
- Edit many files at once with the batch editor (asks for confirmation before writing)
- Copy tags from one file and paste them onto another, or clear a file's tags
- Convert to MP3 (LAME VBR) or M4A (AAC 192 kbps), optionally into a separate output folder
- Preview files with the built-in player

## Requirements

- macOS with Xcode installed
- Swift Package Manager (for the bundled TagLib package)

## Building

Open `Audio Tag.xcodeproj` in Xcode and run the **Audio Tag** scheme, or build from the terminal:

```bash
xcodebuild -project "Audio Tag.xcodeproj" -scheme "Audio Tag" -configuration Debug build
```

## How it works

- **MP3** tags are read and written with [TagLib](https://taglib.org) through a small Objective-C++ wrapper, and saved as ID3v2.3.
- **M4A and WAV** tags and all format conversions use [FFmpegKit](https://github.com/arthenica/ffmpeg-kit).

## Contributing

See `AGENTS.md` for project layout and rules, and `docs/code-review.md` for known issues and the cleanup plan.
