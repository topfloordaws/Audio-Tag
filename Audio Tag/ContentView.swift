// ContentView.swift
// Audio Tag
//
//  Created by Dawson Pham on 6/24/25.
//

import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var fileURL: URL?
    @State private var titleText = ""
    @State private var artistText = ""
    @State private var albumText = ""
    @State private var yearText = ""
    @State private var trackNumber = ""
    @State private var albumArtist = ""
    @State private var genre = ""
    @State private var coverArtURL: URL? = nil
    @State private var status = ""
    @State private var isShowingCoverPicker = false

    private let converter = AudioConverter()
    private let tagger    = AudioConverter()

    var body: some View {
        VStack(spacing: 20) {
            // File picker
            Button("Choose Audio File…") {
              let panel = NSOpenPanel()
              // configure panel
              if panel.runModal() == .OK, let picked = panel.url {
                fileURL = picked
                status = "Loading tags…"
                Task {
                  do {
                    try await loadMetadata(from: picked)
                    status = "✅ Tags loaded"
                  } catch {
                    status = "❌ Failed to load tags: \(error.localizedDescription)"
                  }
                }
              }
            }

            // Metadata editor
            if let url = fileURL {
                HStack {
                  Text("Title:")
                    .frame(width: 80, alignment: .trailing)
                  TextField("", text: $titleText)
                    .frame(width:150)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                  Text("Album")
                    .frame(width: 80, alignment: .trailing)
                  TextField("", text: $albumText)
                    .frame(width:150)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                  Text("Year")
                    .frame(width: 80, alignment: .trailing)
                  TextField("", text: $yearText)
                    .frame(width:150)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                  Text("Track Number")
                    .frame(width: 80, alignment: .trailing)
                  TextField("", text: $trackNumber)
                    .frame(width:150)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                  Text("Album Artist")
                    .frame(width: 80, alignment: .trailing)
                  TextField("", text: $albumArtist)
                    .frame(width:150)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                  Text("Genre")
                    .frame(width: 80, alignment: .trailing)
                  TextField("", text: $genre)
                    .frame(width:150)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Display existing cover art
                if let cover = coverArtURL,
                   let nsImage = NSImage(contentsOf: cover) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .padding(.vertical)
                }

                // Album Art picker
                HStack {
                    Button("Select Cover Art…") {
                        showCoverPicker()
                    }
                    Text(coverArtURL?.lastPathComponent ?? "No cover selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Apply tags button
                Button("Apply Tags") {
                    status = "⏳ Tagging…"
                    tagger.tagMP3(
                        file: url,
                        title: titleText.isEmpty   ? nil : titleText,
                        artist: artistText.isEmpty ? nil : artistText,
                        album:  albumText.isEmpty  ? nil : albumText,
                        year:   yearText.isEmpty   ? nil : yearText,
                        albumArtist: albumArtist.isEmpty ? nil : albumArtist,
                        trackNumber: trackNumber.isEmpty ? nil : trackNumber,
                        genre: genre.isEmpty        ? nil : genre,
                        coverArt: coverArtURL
                    ) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                status = "✅ Tags updated!"
                            case .failure(let err):
                                status = "❌ Tag error: \(err.localizedDescription)"
                            }
                        }
                    }
                }

                Divider().padding(.vertical)

                // 3) Format conversions
                HStack(spacing: 30) {
                    Button("→ MP3")  { convert(url, toExt: "mp3") }
                    Button("→ M4A")  { convert(url, toExt: "m4a") }
                }
            }

            // 4) Feedback
            Text(status)
                .foregroundColor(.secondary)
                .padding(.top, 10)

            Spacer()
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 400)
        .fileImporter(
            isPresented: $isShowingCoverPicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result {
                coverArtURL = urls.first
            }
        }
    }

    // MARK: – Cover picker
    private func showCoverPicker() {
        isShowingCoverPicker = true
    }

    // MARK: – Conversion helper
    private func convert(_ url: URL, toExt ext: String) {
        let out = url.deletingPathExtension()
                     .appendingPathExtension(ext)
        status = "⏳ Converting…"
        switch ext {
        case "mp3":
            converter.toMP3(input: url, output: out) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        status = "✅ Saved \(out.lastPathComponent)"
                    case .failure(let error):
                        status = "❌ Conv. error: \(error.localizedDescription)"
                    }
                }
            }
        case "m4a":
            converter.toM4A(input: url, output: out) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        status = "✅ Saved \(out.lastPathComponent)"
                    case .failure(let error):
                        status = "❌ Conv. error: \(error.localizedDescription)"
                    }
                }
            }
        default:
            break
        }
    }

    // MARK: – Load existing metadata (synchronous)
    // MARK: – Load existing metadata (async/await, no deprecations)
    private func loadMetadata(from url: URL) async throws {
        let asset = AVURLAsset(url: url)

        // Preloads and capturesthe commonMetadata array with no deprecations
        let common = try await asset.load(.commonMetadata)

        // Helper to fetch a single string tag
        func getString(forKey key: AVMetadataKey,
                       keySpace: AVMetadataKeySpace = .common) async throws -> String? {
            guard let item = AVMetadataItem
                    .metadataItems(
                       from: common,
                       withKey: key.rawValue,
                       keySpace: keySpace
                     )
                     .first
            else { return nil }
            return try await item.load(.stringValue)
        }

        // Common tags
        titleText   = try await getString(forKey: .commonKeyTitle)        ?? ""
        artistText  = try await getString(forKey: .commonKeyArtist)       ?? ""
        albumText   = try await getString(forKey: .commonKeyAlbumName)    ?? ""
        yearText    = try await getString(forKey: .commonKeyCreationDate) ?? ""
        //genre       = try await getString(forKey: .commonKeyGenre) ?? ""
        
        // Preloads & reads ID3 frames (track number + album artist + genre via TPE2)
        let id3Items = try await asset.loadMetadata(for: .id3Metadata)
        
        if let tnItem = id3Items.first(where: { $0.identifier == .id3MetadataTrackNumber }) {
            trackNumber = try await tnItem.load(.stringValue) ?? ""
        }
        // Album Artist with ID3 and TPE2 frame
        if let aaItem = AVMetadataItem
              .metadataItems(
                from: id3Items,
                withKey: "TPE2",
                keySpace: .id3
              )
              .first {
           albumArtist = try await aaItem.load(.stringValue) ?? ""
        }
        // Genre (ID3 fallback via TCON)
        if let grItem = id3Items.first(where: { $0.identifier == .id3MetadataContentType }),
           let value = try await grItem.load(.stringValue) {
            genre = value
        }
        // Artwork ID3
        if let artItem = AVMetadataItem
              .metadataItems(
                from: common,
                withKey: AVMetadataKey.commonKeyArtwork.rawValue,
                keySpace: .common
              )
              .first,
           let data = try await artItem.load(.dataValue) {
            let tmp = FileManager.default.temporaryDirectory
                       .appendingPathComponent("cover.jpg")
            try data.write(to: tmp)
            coverArtURL = tmp
        }
    }
}
