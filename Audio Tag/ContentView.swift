// ContentView.swift
// Audio Tag
//
//  Created by Dawson Pham on 6/24/25.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var fileURL: URL?
    @State private var titleText = ""
    @State private var artistText = ""
    @State private var albumText = ""
    @State private var yearText = ""
    @State private var coverArtURL: URL? = nil
    @State private var trackNumber: String = ""
    @State private var albumArtist: String = ""
    @State private var genre: String = ""
    @State private var status = ""
    @State private var isShowingCoverPicker = false

    private let converter = AudioConverter()
    private let tagger = AudioConverter() // same wrapper

    var body: some View {
        VStack(spacing: 20) {
            // 1) File picker
            Button("Choose Audio File…") {
                let panel = NSOpenPanel()
                panel.allowedFileTypes = ["mp3", "m4a", "wav"]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false

                if panel.runModal() == .OK {
                    fileURL = panel.url
                    status = "Picked: \(panel.url!.lastPathComponent)"
                }
            }

            // 2) Metadata editor
            if let url = fileURL {
                TextField("Title", text: $titleText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Artist", text: $artistText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Album", text: $albumText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Year", text: $yearText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // Album Art picker
                HStack {
                    Button("Select Cover Art…") {
                        showCoverPicker()
                    }
                    Text(coverArtURL?.lastPathComponent ?? "No cover selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Additional metadata fields
                HStack {
                    Text("Track #:")
                    TextField("e.g. 3", text: $trackNumber)
                        .frame(width: 50)
                }
                TextField("Album Artist", text: $albumArtist)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Genre", text: $genre)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Apply Tags") {
                    status = "⏳ Tagging…"
                    tagger.tagMP3(
                        file: url,
                        title: titleText.isEmpty ? nil : titleText,
                        artist: artistText.isEmpty ? nil : artistText,
                        album: albumText.isEmpty ? nil : albumText,
                        year: yearText.isEmpty ? nil : yearText,
                        albumArtist: albumArtist.isEmpty ? nil : albumArtist,
                        trackNumber: trackNumber.isEmpty ? nil : trackNumber,
                        genre: genre.isEmpty ? nil : genre,
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
                    Button("→ MP3") {
                        convert(url, toExt: "mp3")
                    }
                    Button("→ M4A") {
                        convert(url, toExt: "m4a")
                    }
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

    // MARK: – Cover picker binding
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
                    case .failure(let err):
                        status = "❌ Conv. error: \(err.localizedDescription)"
                    }
                }
            }

        case "m4a":
            converter.toM4A(input: url, output: out) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        status = "✅ Saved \(out.lastPathComponent)"
                    case .failure(let err):
                        status = "❌ Conv. error: \(err.localizedDescription)"
                    }
                }
            }

        default:
            break
        }
    }
}

