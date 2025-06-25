import Foundation
import AVFoundation
import ID3TagEditor

protocol MetadataProcessor {
  func updateTags(on file: URL, changes: MetadataChanges) async throws
}

struct FileMetadataProcessor: MetadataProcessor {
  /// Dispatches to MP4 or MP3 helper based on extension
  func updateTags(on file: URL, changes: MetadataChanges) async throws {
    switch file.pathExtension.lowercased() {
    case "m4a", "mp4", "aac":
      try await updateMP4Metadata(at: file, changes: changes)
    case "mp3":
      try updateMP3Metadata(at: file, changes: changes)
    default:
      throw NSError(
        domain: "FileMetadataProcessor",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Unsupported format"]
      )
    }
  }

  // –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // MARK: – M4A via AVAssetExportSession (macOS 15+ async / fallback)
  // –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  private func updateMP4Metadata(
    at url: URL,
    changes: MetadataChanges
  ) async throws {
    let asset = AVURLAsset(url: url)
    guard let exporter = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetPassthrough
    ) else {
      throw NSError(domain: "FileMetadataProcessor", code: -1, userInfo: nil)
    }

    // write into a temp file
    let tempURL = url
      .deletingLastPathComponent()
      .appendingPathComponent("temp.m4a")
    exporter.outputURL      = tempURL
    exporter.outputFileType = .m4a

    // build metadata items
    var items = [AVMutableMetadataItem]()
    func add(_ key: AVMetadataKey, _ v: String?) {
      guard let v = v else { return }
      let item = AVMutableMetadataItem()
      item.keySpace = .common
      item.key      = key as NSString
      item.value    = v as NSString
      items.append(item)
    }
    add(.commonKeyTitle,        changes.title)
    add(.commonKeyArtist,       changes.artist)
    add(.commonKeyAlbumName,    changes.album)
    add(.commonKeyCreationDate, changes.year)
    exporter.metadata = items

    // **macOS 15+**: use new async export API; **fallback** to old callback for earlier OS
    if #available(macOS 15.0, *) {
      // new async/await export (throws on error) :contentReference[oaicite:0]{index=0}
      try await exporter.export(to: tempURL, as: .m4a)
    } else {
      // old API—still works, though deprecated
      let sem = DispatchSemaphore(value: 0)
      exporter.exportAsynchronously { sem.signal() }
      sem.wait()
      if let err = exporter.error { throw err }
    }

    // replace original file
    try FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: tempURL, to: url)
  }

  // –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // MARK: – MP3 via ID3TagEditor (builder pattern)
  // –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    private func updateMP3Metadata(at file: URL, changes: MetadataChanges) throws {
      let editor  = ID3TagEditor()
        // … inside your updateMP3Metadata(at:changes:) …

        var builder = ID32v4TagBuilder()

        // title
        if let t = changes.title {
          builder = builder.title(
            frame: ID3FrameWithStringContent(content: t)
          )
        }

        // artist
        if let a = changes.artist {
          builder = builder.artist(
            frame: ID3FrameWithStringContent(content: a)
          )
        }

        // album
        if let al = changes.album {
          builder = builder.album(
            frame: ID3FrameWithStringContent(content: al)
          )
        }

        // year → use the proper Date/Time frame
        // 4) Year → TDRC frame (v2.4)
        if let yearString = changes.year,
           let yearInt    = Int(yearString)
        {
          // 1) Build a RecordingDate (year, optional month/day)
          //    RecordingDate(year: Int, month: Int?, day: Int?)
            let recDate = RecordingDate(day: yearInt,
                                        month:   nil,
                                        year:     nil)

          // 2) Wrap it in a RecordingDateTime (date + optional time)
          let recDateTimeFrame = ID3FrameRecordingDateTime(
            recordingDateTime: RecordingDateTime(date: recDate,
                                                 time: nil)
          )

          // 3) Mutate your builder
          builder = builder.recordingDateTime(frame: recDateTimeFrame)
        }

        let tag = builder.build()
        try editor.write(tag: tag, to: file.path)
    }
}
