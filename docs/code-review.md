# Code review: cleanup plan

Review of the app source in `Audio Tag/` (vendored TagLib and FFmpegKit excluded).
Work through the sections in order. Tick items off as they are fixed, and note the branch that fixed them.

## 1. Bugs

- [ ] **Clear Tags doesn't clear MP3 text fields.** The C wrapper treats `""` as "clear" and `NULL` as
  "leave unchanged", but `TagLib.swift` (`isNilOrEmpty ? nil : …`) and `ContentView.applyTags`
  (`isEmpty ? nil : …`) turn empty strings into `nil`. Only track and year clear (because `Int("")` → 0).
  Artwork is never cleared. Blanking a single field in the editor also does nothing.
- [ ] **"→ M4A" only works on M4A input.** `ContentView.convert` handles only `("m4a","m4a")`; WAV/MP3 → M4A
  hit `default: break` and the status stays on "⏳ Converting" forever.
- [ ] **Filenames containing quotes break FFmpeg commands.** Commands are built by string-joining paths in
  `'…'` or `"…"` (e.g. `Don't Stop.m4a`). Use `FFmpegKit.executeWithArgumentsAsync` with an argument array.
- [ ] **Batch artwork picker skips `startAccessingSecurityScopedResource`** (`BatchMetadataEditor` fileImporter),
  so it can silently fail to read the image in the sandbox.
- [ ] **M4A/WAV indexing reads only title, artist and album** (`extractMetadata`). Album artist, track, genre,
  year and comment always appear blank for those formats.

## 2. Repo hygiene

- [ ] FFmpeg frameworks are committed twice: repo root `lib*.framework` (~29 MB) and
  `Audio Tag/bundle-apple-framework-macos/` (~30 MB). Keep one.
- [ ] `Resources/ffmpeg` (80 MB binary) appears unused; the app uses FFmpegKit in-process. Remove it and its
  Xcode project reference.
- [ ] `TagLibBridge/` is a stale copy of the wrapper but still referenced in the Xcode project. Remove it.
- [ ] Consider replacing vendored `Packages/swift-taglib` with a remote Swift Package dependency.
- [ ] Add a `.gitignore` (`xcuserdata/`, `.DS_Store`, `DerivedData/`) and untrack committed `xcuserdata/`.
- [ ] Replace the template test stubs with real tests (e.g. MP3 tag read/write round-trip).

## 3. Dead code

- [ ] `AudioConverter.swift`: commented-out `toMP3` and `m4aToMP3WithJPEGCover`; unused `tagMP3`
  (MP3 goes through TagLib); `NSImage.jpegData` only used by the commented-out code.
- [ ] `Shell.swift` (`runShell`) is unused.
- [ ] `copyCString` in `TagLibWrapper.mm` is unused (and would leak: `strdup` with no `free`).
- [ ] Commented-out properties in `FileMetadata`; stray `// need to force id3v2.3f` in the `.mm` file.
- [ ] `#if !targetEnvironment(simulator)` guards do nothing in a macOS-only app.

## 4. Duplicated code

- [ ] `tagM4A`, `tagWAV`, `tagMP3` are near-copies: merge into one function with a format setting.
- [ ] FFmpeg result handling is written 6 times with inconsistent main-thread hops and error codes
  (-1, 1, 2). Extract one helper.
- [ ] Two JPEG helpers (`jpegData`, `toJPEGData`) do the same thing.
- [ ] "Encode JPEG → write temp file → set artworkURL/data/mime" appears 3 times (Copy Tags, Paste Tags,
  batch apply). The batch copy forgets `artworkData` and `artworkMime`.
- [ ] `ContentView` has two `AudioConverter()` instances (`tagger`, `converter`); one is enough.
- [ ] The success/failure status closure is repeated 4 times in `applyTags` and `convert`.
- [ ] `metadataEditor` has 8 identical `Group { Text; TextField }` blocks: make a `LabeledField` view or loop
  over key paths. `clearTags`, `pasteTags`, `applyBatchTags` copy fields one by one the same way.
- [ ] `isEmpty ? nil : value` is repeated ~20 times: add a helper (and fix the empty-vs-nil rule, see §1).
- [ ] `TagLib.swift` nests 8 levels of `withCString` and calls `TLTagMP3` twice: flatten.

## 5. TagLib wrapper (`TagLibWrapper.mm`)

- [ ] Every field is written twice (`v2->setTitle()` then `setTextFrame(...)`); `setTitle` already writes TIT2.
- [ ] `removeFrames` re-queries `frameList` each loop pass; use `tag->removeFrames(fid)`.
- [ ] `strip(ID3v1|APE)` then `save(..., StripNone, v3)`: save with the strip-others option in one step.
- [ ] Reader repeats the `stringWithUTF8String:…to8Bit(true).c_str()] ?: @""` conversion 7 times: add a helper.

## 6. ContentView structure and performance

- [ ] At ~970 lines it is too big: split out sidebar editor, audio player, table, loading overlay, batch editor;
  move file operations into an `ObservableObject` view model.
- [ ] MP3 tag writes run synchronously on the main thread (UI freezes).
- [ ] Batch apply starts one FFmpeg job per file at once; they race to update `status`.
- [ ] `Timer.publish(...).autoconnect()` is created inside `body` and fires even when nothing plays;
  use `AVPlayer.addPeriodicTimeObserver`.
- [ ] Key monitor and NotificationCenter observers added in `onAppear` are never removed.
- [ ] ⌘O / ⌘R are defined twice (menu commands and hidden buttons); menu talks to the view via untyped
  `NSNotification.Name` strings.
- [ ] `binding(for:in:)` uses `firstIndex(of:)` (whole-struct compare incl. NSImage) and captures an index that
  goes stale after sort/filter. Look up by `id`.
- [ ] `filteredItems` lowercases 5 strings per row per redraw; use `localizedCaseInsensitiveContains`.
- [ ] Copy Tags round-trips artwork through TIFF and writes a temp JPEG; Paste does it again.
- [ ] Temp artwork files are never deleted.
- [ ] `DateFormatter.localizedString` runs per cell per render; cache a formatter or use `Date.FormatStyle`.
- [ ] `loadFiles` hops to the main actor once per file for progress; batch the updates.
- [ ] MP3 artwork is read via AVFoundation although TagLib already opens the file; return it from the reader.

## Suggested order

1 (bugs) → 2 (hygiene) → 4 + 5 (tagging dedup) → 6 (split ContentView).
