//
//  TagLib.swift
//  Audio Tag
//
//  Created by Dawson Pham on 7/11/25.
//

import Foundation

class MP3Tagger {
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
        coverMime: String? = nil
    ) -> Bool {
        let trackValue = Int32(track ?? 0)
        let yearValue  = Int32(year ?? 0)
        var result: Bool = false

        // All CStrings must be valid for the call—so *nest* the closures:
        return path.withCString { pathC in
            (title ?? "").withCString { titleC in
                (artist ?? "").withCString { artistC in
                    (album ?? "").withCString { albumC in
                        (albumArtist ?? "").withCString { albumArtistC in
                            (genre ?? "").withCString { genreC in
                                (comment ?? "").withCString { commentC in
                                    (coverMime ?? "").withCString { mimeC in
                                        if let coverData = coverData, !coverData.isEmpty {
                                            result = coverData.withUnsafeBytes { raw in
                                                TLTagMP3(
                                                    pathC,
                                                    title.isNilOrEmpty ? nil : titleC,
                                                    artist.isNilOrEmpty ? nil : artistC,
                                                    album.isNilOrEmpty ? nil : albumC,
                                                    albumArtist.isNilOrEmpty ? nil : albumArtistC,
                                                    trackValue,
                                                    genre.isNilOrEmpty ? nil : genreC,
                                                    yearValue,
                                                    comment.isNilOrEmpty ? nil : commentC,
                                                    raw.baseAddress,
                                                    Int32(raw.count),
                                                    coverMime.isNilOrEmpty ? nil : mimeC
                                                )
                                            }
                                        } else {
                                            result = TLTagMP3(
                                                pathC,
                                                title.isNilOrEmpty ? nil : titleC,
                                                artist.isNilOrEmpty ? nil : artistC,
                                                album.isNilOrEmpty ? nil : albumC,
                                                albumArtist.isNilOrEmpty ? nil : albumArtistC,
                                                trackValue,
                                                genre.isNilOrEmpty ? nil : genreC,
                                                yearValue,
                                                comment.isNilOrEmpty ? nil : commentC,
                                                nil,
                                                0,
                                                nil
                                            )
                                        }
                                        return result
                                    }}}}}}}
        }
    }

    // MARK: - Unified Reading
    
    static func readAllTags(path: String) -> AudioTags {
        return path.withCString { pathC in
            return TLReadAllTags(pathC)
        }
    }
}

// Optional String helper
fileprivate extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}
