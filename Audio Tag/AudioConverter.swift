// AudioConverter.swift
// Audio Tag
//
//  Created by Dawson Pham on 6/24/25.
//

import Foundation
import ffmpegkit

struct AudioConverter {

    /// In-place metadata tagging for MP3 (embedded album art + tags)
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

        // album art as second input
        if let cover = coverArt {
            args += ["-i", cover.path, "-map", "0:a", "-map", "1:v"]
        }

        // metadata fields
        if let t = title      { args += ["-metadata", "title=\(t)"] }
        if let a = artist     { args += ["-metadata", "artist=\(a)"] }
        if let al = album     { args += ["-metadata", "album=\(al)"] }
        if let y = year       { args += ["-metadata", "date=\(y)"] }
        if let aa = albumArtist { args += ["-metadata", "album_artist=\(aa)"] }
        if let tn = trackNumber { args += ["-metadata", "track=\(tn)"] }
        if let g = genre      { args += ["-metadata", "genre=\(g)"] }

        // copy streams to temp file
        args += ["-codec", "copy"]

        // if album art, embed it
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
                completion(.failure(NSError(domain: "FFmpegKit", code: -1)))
                return
            }
            if session.getReturnCode()?.isValueSuccess() == true {
                do {
                    try FileManager.default.removeItem(at: file)
                    try FileManager.default.moveItem(at: tmp, to: file)
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
            } else {
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

    /// Convert any audio file → MP3 (libmp3lame VBR quality 2)
    func toMP3(input: URL, output: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let cmd = """
        -y -i '\(input.path)' \
        -codec:a libmp3lame -qscale:a 2 \
        '\(output.path)'
        """
        FFmpegKit.executeAsync(cmd) { session in
            guard let session = session else {
                completion(.failure(NSError(domain: "FFmpegKit", code: -1)))
                return
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

    /// Convert any audio file → M4A (AAC 192 kbps)
    func toM4A(input: URL, output: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let cmd = """
        -y -i '\(input.path)' \
        -codec:a aac -b:a 192k \
        '\(output.path)'
        """
        FFmpegKit.executeAsync(cmd) { session in
            guard let session = session else {
                completion(.failure(NSError(domain: "FFmpegKit", code: -1)))
                return
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
}
