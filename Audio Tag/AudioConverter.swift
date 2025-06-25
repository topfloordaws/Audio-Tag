//
//  AudioConverter.swift
//  Audio Tag
//
//  Created by Dawson Pham on 6/24/25.
//

import Foundation

/// Wraps your bundled `ffmpeg` for all conversions and metadata copying.
struct AudioConverter {
    private var ffmpegURL: URL {
        Bundle.main.url(forResource: "ffmpeg", withExtension: nil)!
    }

    private func runFFmpeg(_ arguments: [String]) throws {
        let task = Process()
        task.executableURL = ffmpegURL
        task.arguments     = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = pipe

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            let data   = pipe.fileHandleForReading.readDataToEndOfFile()
            // ← use UTF8.self here
            let output = String(decoding: data, as: UTF8.self)
            throw NSError(
                domain: "FFmpegError",
                code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }
    }

    /// Format conversions

    func toMP3(input: URL, output: URL) throws {
        try runFFmpeg([
            "-y", "-i", input.path,
            "-codec:a", "libmp3lame", "-qscale:a", "2",
            output.path
        ])
    }

    func toM4A(input: URL, output: URL) throws {
        try runFFmpeg([
            "-y", "-i", input.path,
            "-codec:a", "aac", "-b:a", "192k",
            output.path
        ])
    }

    func wavToMP3(input: URL, output: URL) throws {
        try toMP3(input: input, output: output)
    }

    func mp3ToWAV(input: URL, output: URL) throws {
        try runFFmpeg([
            "-y", "-i", input.path,
            output.path
        ])
    }

    /// In‐place metadata tagging for MP3 (and likewise M4A if you want)
    func tagMP3(
      file: URL,
      title: String?,
      artist: String?,
      album: String?,
      year: String?
    ) throws {
        // Build -metadata arguments
        var args = ["-y", "-i", file.path]
        if let t = title  { args += ["-metadata", "title=\(t)"] }
        if let a = artist { args += ["-metadata", "artist=\(a)"] }
        if let al = album { args += ["-metadata", "album=\(al)"] }
        if let y = year   { args += ["-metadata", "date=\(y)"] }

        // copy streams so we don't re-encode
        let tmp = file.deletingPathExtension()
                      .appendingPathExtension("tmp.mp3")
        args += ["-codec", "copy", tmp.path]

        // Run ffmpeg
        try runFFmpeg(args)

        // Replace original
        try FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: tmp, to: file)
    }
}
