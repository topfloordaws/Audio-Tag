//
//  ContentView.swift
//  Audio Tag
//
//  Created by Dawson Pham on 6/24/25.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var fileURL: URL?
    @State private var titleText  = ""
    @State private var artistText = ""
    @State private var albumText  = ""
    @State private var yearText   = ""
    @State private var status     = ""

    private let converter = AudioConverter()
    private let tagger    = AudioConverter()  // same type used for tagging

    var body: some View {
        VStack(spacing: 20) {
            // 1) File picker
            Button("Choose Audio File…") {
                let panel = NSOpenPanel()
                panel.allowedFileTypes        = ["mp3","m4a","wav"]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories    = false

                if panel.runModal() == .OK {
                    fileURL = panel.url
                    status  = "Picked: \(panel.url!.lastPathComponent)"
                }
            }

            // 2) Metadata editor
            if let url = fileURL {
                TextField("Title",  text: $titleText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Artist", text: $artistText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Album",  text: $albumText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Year",   text: $yearText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Apply Tags") {
                    status = "⏳ Tagging…"
                    tagger.tagMP3(
                        file:   url,
                        title:  titleText.isEmpty  ? nil : titleText,
                        artist: artistText.isEmpty ? nil : artistText,
                        album:  albumText.isEmpty  ? nil : albumText,
                        year:   yearText.isEmpty   ? nil : yearText
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
        .frame(minWidth: 400, minHeight: 300)
    }

    // MARK: – Helpers

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
