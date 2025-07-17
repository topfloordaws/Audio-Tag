//
//  AudioConverter.swift
//  Audio Tag
//
//  Created by Dawson Pham on 6/24/25.
//

import AppKit
import Foundation
import ffmpegkit

struct AudioConverter {

    // In-place metadata tagging for MP3 (embedded album art + tags)
    func tagMP3(
        file: URL,
        title: String?,
        artist: String?,
        album: String?,
        year: String?,
        albumArtist: String?,
        trackNumber: String?,
        genre: String?,
        coverArt: URL?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var args = ["-y", "-i", file.path]

        if let cover = coverArt {
            args += ["-i", cover.path, "-map", "0:a", "-map", "1:v"]
        }

        if let t = title      { args += ["-metadata", "title=\(t)"] }
        if let a = artist     { args += ["-metadata", "artist=\(a)"] }
        if let al = album     { args += ["-metadata", "album=\(al)"] }
        if let y = year       { args += ["-metadata", "date=\(y)"] }
        if let aa = albumArtist { args += ["-metadata", "album_artist=\(aa)"] }
        if let tn = trackNumber { args += ["-metadata", "track=\(tn)"] }
        if let g = genre      { args += ["-metadata", "genre=\(g)"] }

        args += ["-codec", "copy"]

        if coverArt != nil {
            args += [
                "-metadata:s:v", "title=Album cover",
                "-metadata:s:v", "comment=Cover (front)",
                "-disposition:v", "attached_pic"
            ]
        }

        let tmp = file.deletingPathExtension()
                      .appendingPathExtension("tmp.mp3")
        args += [tmp.path]

        let cmd = args.map { "\"\($0)\"" }.joined(separator: " ")
        FFmpegKit.executeAsync(cmd) { session in
            guard let session = session else {
                try? FileManager.default.removeItem(at: tmp)
                return completion(.failure(NSError(domain: "FFmpegKit", code: -1)))
            }
            if session.getReturnCode()?.isValueSuccess() == true {
                do {
                    try FileManager.default.removeItem(at: file)
                    try FileManager.default.moveItem(at: tmp, to: file)
                    completion(.success(()))
                } catch {
                    try? FileManager.default.removeItem(at: tmp)
                    completion(.failure(error))
                }
            } else {
                try? FileManager.default.removeItem(at: tmp)
                let logs = session.getAllLogsAsString() ?? ""
                let code = Int(session.getReturnCode()?.getValue() ?? -1)
                let err = NSError(
                    domain: "FFmpegKit",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: logs]
                )
                completion(.failure(err))
            }
        }
    }

    // Converts any audio file (WAV and M4A) → MP3 (libmp3lame VBR quality 2)
    func toMP3(
        input: URL,
        output: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // preserves best quality to MP3
        let cmd = """
        -y -i '\(input.path)' \
        -codec:a libmp3lame -b:a 320k \
        '\(output.path)'
        """
        FFmpegKit.executeAsync(cmd) { session in
            guard let session = session else {
                return completion(.failure(NSError(domain: "FFmpegKit", code: -1)))
            }
            if session.getReturnCode()?.isValueSuccess() == true {
                completion(.success(()))
            } else {
                let logs = session.getAllLogsAsString() ?? ""
                let code = Int(session.getReturnCode()?.getValue() ?? -1)
                let err  = NSError(
                    domain: "FFmpegKit",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: logs]
                )
                completion(.failure(err))
            }
        }
    }

    // Converts any audio file (WAV and MP3) → M4A (AAC 192 kbps)
    func toM4A(
        input: URL,
        output: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let cmd = """
        -y -i '\(input.path)' \
        -codec:a aac -b:a 192k \
        '\(output.path)'
        """
        FFmpegKit.executeAsync(cmd) { session in
            guard let session = session else {
                return completion(.failure(NSError(domain: "FFmpegKit", code: -1)))
            }
            if session.getReturnCode()?.isValueSuccess() == true {
                completion(.success(()))
            } else {
                let logs = session.getAllLogsAsString() ?? ""
                let code = Int(session.getReturnCode()?.getValue() ?? -1)
                let err  = NSError(
                    domain: "FFmpegKit",
                    code: code,
                    userInfo: [NSLocalizedDescriptionKey: logs]
                )
                completion(.failure(err))
            }
        }
    }

    // Converts an M4A ➔ MP3 with PNG→JPEG conversion for embedded art
    func m4aToMP3WithJPEGCover(
        inputM4A: URL,
        outputMP3: URL,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let tmpDir    = FileManager.default.temporaryDirectory
        let coverPNG  = tmpDir.appendingPathComponent(UUID().uuidString)
                               .appendingPathExtension("png")
        let coverJPEG = tmpDir.appendingPathComponent(UUID().uuidString)
                               .appendingPathExtension("jpg")

        // 1) Copy embedded art to PNG without decoding
        let extractCmd = """
        -y -i '\(inputM4A.path)' -map 0:1 -c copy '\(coverPNG.path)'
        """
        FFmpegKit.executeAsync(extractCmd) { exSession in
            guard let ex = exSession,
                  ex.getReturnCode()?.isValueSuccess() == true
            else {
                let logs = exSession?.getAllLogsAsString() ?? "art extraction failed"
                return completion(.failure(NSError(
                    domain: "FFmpegKit",
                    code: Int(exSession?.getReturnCode()?.getValue() ?? -1),
                    userInfo: [NSLocalizedDescriptionKey: logs]
                )))
            }

            // 2) Convert the PNG to JPEG in Swift
            var finalCoverURL = coverPNG
            if let image = NSImage(contentsOf: coverPNG),
               let data  = image.jpegData()
            {
                do {
                    try data.write(to: coverJPEG)
                    finalCoverURL = coverJPEG
                } catch {
                    print("⚠️ JPEG write failed, using PNG: \(error)")
                }
            }

            // 3) Convert audio + embed only the JPEG
            let convertCmd = """
            -y \
            -i '\(inputM4A.path)' \
            -i '\(finalCoverURL.path)' \
            -map 0:a -map 1:v \
            -c:a libmp3lame -qscale:a 2 \
            -c:v copy \
            -disposition:v attached_pic \
            -id3v2_version 3 \
            '\(outputMP3.path)'
            """
            FFmpegKit.executeAsync(convertCmd) { cvSession in
                guard let cv = cvSession,
                      cv.getReturnCode()?.isValueSuccess() == true
                else {
                    let logs = cvSession?.getAllLogsAsString() ?? "conversion failed"
                    return completion(.failure(NSError(
                        domain: "FFmpegKit",
                        code: Int(cvSession?.getReturnCode()?.getValue() ?? -1),
                        userInfo: [NSLocalizedDescriptionKey: logs]
                    )))
                }
                completion(.success(()))
            }
        }
    }

    // In-place metadata tagging for M4A
    func tagM4A(
        file: URL,
        title: String?,
        artist: String?,
        album: String?,
        year: String?,
        albumArtist: String?,
        trackNumber: String?,
        genre: String?,
        coverArt: URL?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var args = ["-y", "-i", file.path]
        if let cover = coverArt {
            args += ["-i", cover.path, "-map", "0", "-map", "1"]
        }
        if let t = title       { args += ["-metadata", "title=\(t)"] }
        if let a = artist      { args += ["-metadata", "artist=\(a)"] }
        if let al = album      { args += ["-metadata", "album=\(al)"] }
        if let y = year        { args += ["-metadata", "date=\(y)"] }
        if let aa = albumArtist{ args += ["-metadata", "album_artist=\(aa)"] }
        if let tn = trackNumber{ args += ["-metadata", "track=\(tn)"] }
        if let g = genre       { args += ["-metadata", "genre=\(g)"] }

        args += ["-c", "copy"]
        let tmp = file.deletingPathExtension()
                   .appendingPathExtension("tmp.m4a")
        args += [tmp.path]

        let cmd = args.map { "\"\($0)\"" }.joined(separator: " ")
        FFmpegKit.executeAsync(cmd) { session in
            guard let s = session, s.getReturnCode()?.isValueSuccess() == true else {
                try? FileManager.default.removeItem(at: tmp)
                let log = session?.getAllLogsAsString() ?? "unknown"
                return completion(.failure(NSError(
                    domain: "FFmpegKit", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: log]
                )))
            }
            do {
                _ = try FileManager.default.replaceItemAt(file, withItemAt: tmp)
                completion(.success(()))
            } catch {
                try? FileManager.default.removeItem(at: tmp)
                completion(.failure(error))
            }
        }
    }

    // In-place metadata tagging for WAV (RIFF INFO tags)
    func tagWAV(
        file: URL,
        title: String?,
        artist: String?,
        album: String?,
        year: String?,
        albumArtist: String?,
        trackNumber: String?,
        genre: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var args = ["-y", "-i", file.path]
        if let t = title       { args += ["-metadata", "title=\(t)"] }
        if let a = artist      { args += ["-metadata", "artist=\(a)"] }
        if let al = album      { args += ["-metadata", "album=\(al)"] }
        if let y = year        { args += ["-metadata", "date=\(y)"] }
        if let tn = trackNumber{ args += ["-metadata", "track=\(tn)"] }
        if let g = genre       { args += ["-metadata", "genre=\(g)"] }

        args += ["-c", "copy"]
        let tmp = file.deletingPathExtension()
                   .appendingPathExtension("tmp.wav")
        args += [tmp.path]

        let cmd = args.map { "\"\($0)\"" }.joined(separator: " ")
        FFmpegKit.executeAsync(cmd) { session in
            guard let s = session, s.getReturnCode()?.isValueSuccess() == true else {
                try? FileManager.default.removeItem(at: tmp)
                let log = session?.getAllLogsAsString() ?? "unknown"
                return completion(.failure(NSError(
                    domain: "FFmpegKit", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: log]
                )))
            }
            do {
                _ = try FileManager.default.replaceItemAt(file, withItemAt: tmp)
                completion(.success(()))
            } catch {
                try? FileManager.default.removeItem(at: tmp)
                completion(.failure(error))
            }
        }
    }
}

// NSImage → JPEG helper
extension NSImage {
    /// Converts the image to JPEG data.
    func jpegData(compressionQuality: CGFloat = 0.92) -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
    }
}
