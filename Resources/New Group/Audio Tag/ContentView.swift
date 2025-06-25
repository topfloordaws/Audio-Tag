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
    @State private var titleText = ""
    @State private var artistText = ""
    @State private var yearText = ""
    @State private var status = ""

    let converter = AudioConverter()
    let processor = FileMetadataProcessor()

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
                TextField("Year", text: $yearText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Apply Tags") {
                    Task {
                        do {
                            try await processor.updateTags(
                                on: url,
                                changes: MetadataChanges(
                                    title: titleText,
                                    artist: artistText,
                                    album: nil,
                                    year: yearText
                                )
                            )
                            status = "✅ Tags updated!"
                        } catch {
                            status = "❌ Tag error: \(error.localizedDescription)"
                        }
                    }
                }

                Divider().padding(.vertical)

                // 3) Format conversions
                HStack(spacing: 30) {
                    Button("→ MP3") {
                        let out = url.deletingPathExtension()
                            .appendingPathExtension("mp3")
                        do {
                            try converter.toMP3(input: url, output: out)
                            status = "✅ Saved \(out.lastPathComponent)"
                        } catch {
                            status = "❌ Conv. error: \(error)"
                        }
                    }

                    Button("→ M4A") {
                        let out = url.deletingPathExtension()
                            .appendingPathExtension("m4a")
                        do {
                            try converter.toM4A(input: url, output: out)
                            status = "✅ Saved \(out.lastPathComponent)"
                        } catch {
                            status = "❌ Conv. error: \(error)"
                        }
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
