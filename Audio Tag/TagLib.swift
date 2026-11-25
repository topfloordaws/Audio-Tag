//
//  TagLib.swift
//  Audio Tag
//
//  Created by Dawson Pham on 7/11/25.
//

import Foundation

class MP3Tagger {
    /// Writes ID3v2 tags to an MP3 file.
    ///
    /// - Text fields: `nil` leaves the field unchanged, `""` clears it.
    /// - `track` / `year`: `nil` leaves unchanged, `0` clears.
    /// - Artwork: non-empty `coverData` replaces it; otherwise `clearArtwork` removes it;
    ///   otherwise it is left unchanged.
    static func updateTags(
        path: String,
        title: String?,
        artist: String?,
        album: String?,
        albumArtist: String?,
        track: Int?,
        year: Int?,
        genre: String?,
        comment: String?,
        coverData: Data? = nil,
        coverMime: String? = nil,
        clearArtwork: Bool = false
    ) -> Bool {
        // C copies stay valid for the whole call; nil stays NULL ("leave unchanged").
        let c = [title, artist, album, albumArtist, genre, comment, coverMime].map { $0.flatMap { strdup($0) } }
        defer { c.forEach { free($0) } }

        let trackValue = Int32(clamping: track ?? -1)
        let yearValue  = Int32(clamping: year ?? -1)
        let cover = (coverData?.isEmpty == false) ? coverData : nil

        return path.withCString { pathC in
            func write(_ bytes: UnsafeRawPointer?, _ count: Int) -> Bool {
                TLTagMP3(pathC, c[0], c[1], c[2], c[3], trackValue, c[4], yearValue, c[5],
                         bytes, Int32(count), bytes == nil ? nil : c[6], clearArtwork)
            }
            guard let cover else { return write(nil, 0) }
            return cover.withUnsafeBytes { write($0.baseAddress, $0.count) }
        }
    }

    // MARK: - Unified Reading

    static func readAllTags(path: String) -> AudioTags {
        return path.withCString { pathC in
            return TLReadAllTags(pathC)
        }
    }
}
