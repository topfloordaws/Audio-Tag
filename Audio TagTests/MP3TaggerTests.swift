//
//  MP3TaggerTests.swift
//  Audio TagTests
//
//  Round-trip tests for MP3 tag writing through the TagLib wrapper.
//

import Foundation
import AVFoundation
import Testing
@testable import Audio_Tag

struct MP3TaggerTests {

    /// Writes a tiny but valid MP3: 20 silent MPEG-1 Layer III frames (128 kbps, 44.1 kHz, 417 bytes each).
    private func makeSilentMP3() throws -> URL {
        var frame = Data([0xFF, 0xFB, 0x90, 0x64])
        frame.append(Data(count: 417 - 4))
        var data = Data()
        for _ in 0..<20 { data.append(frame) }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        try data.write(to: url)
        return url
    }

    private func hasArtwork(_ url: URL) async throws -> Bool {
        let metadata = try await AVURLAsset(url: url).load(.commonMetadata)
        return metadata.contains { $0.commonKey == .commonKeyArtwork }
    }

    private func writeAllFields(_ path: String) -> Bool {
        MP3Tagger.updateTags(
            path: path, title: "Title", artist: "Artist", album: "Album", albumArtist: "Album Artist",
            track: 7, year: 2024, genre: "Rock", comment: "Comment",
            coverData: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4]),
            coverMime: "image/png"
        )
    }

    @Test func writesAndReadsAllFields() async throws {
        let url = try makeSilentMP3()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(writeAllFields(url.path))
        let tags = MP3Tagger.readAllTags(path: url.path)
        #expect(tags.title == "Title")
        #expect(tags.artist == "Artist")
        #expect(tags.album == "Album")
        #expect(tags.albumArtist == "Album Artist")
        #expect(tags.track == 7)
        #expect(tags.year == 2024)
        #expect(tags.genre == "Rock")
        #expect(tags.comment == "Comment")
        #expect(try await hasArtwork(url))
    }

    @Test func emptyValuesClearEverything() async throws {
        let url = try makeSilentMP3()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(writeAllFields(url.path))

        // What Clear Tags sends: empty strings, zeros, and the clear-artwork flag.
        #expect(MP3Tagger.updateTags(
            path: url.path, title: "", artist: "", album: "", albumArtist: "",
            track: 0, year: 0, genre: "", comment: "", clearArtwork: true
        ))
        let tags = MP3Tagger.readAllTags(path: url.path)
        #expect(tags.title == "")
        #expect(tags.artist == "")
        #expect(tags.album == "")
        #expect(tags.albumArtist == "")
        #expect(tags.track == 0)
        #expect(tags.year == 0)
        #expect(tags.genre == "")
        #expect(tags.comment == "")
        #expect(try await hasArtwork(url) == false)
    }

    @Test func blankingOneFieldClearsOnlyThatField() async throws {
        let url = try makeSilentMP3()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(writeAllFields(url.path))

        #expect(MP3Tagger.updateTags(
            path: url.path, title: "", artist: nil, album: nil, albumArtist: nil,
            track: nil, year: nil, genre: nil, comment: nil
        ))
        let tags = MP3Tagger.readAllTags(path: url.path)
        #expect(tags.title == "")
        #expect(tags.artist == "Artist")
        #expect(tags.track == 7)
        #expect(tags.year == 2024)
        #expect(try await hasArtwork(url))
    }
}
