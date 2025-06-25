import SwiftUI
import AppKit

struct ContentView: View {
    @State private var fileURL: URL?
    @State private var titleText  = ""
    @State private var artistText = ""
    @State private var albumText  = ""
    @State private var yearText   = ""
    @State private var status     = ""

    let converter = AudioConverter()
    let tagger    = AudioConverter()  // uses the same converter for tagging

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
                    tagMP3(
                        url: url,
                        title:  titleText,
                        artist: artistText,
                        album:  albumText,
                        year:   yearText
                    )
                }

                Divider().padding(.vertical)

                // 3) Format conversions
                HStack(spacing: 30) {
                    Button("→ MP3") { convert(url, toExt: "mp3") }
                    Button("→ M4A") { convert(url, toExt: "m4a") }
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

    private func tagMP3(
        url: URL,
        title: String,
        artist: String,
        album: String,
        year: String
    ) {
        do {
            try converter.tagMP3(
                file: url,
                title:  title.isEmpty  ? nil : title,
                artist: artist.isEmpty ? nil : artist,
                album:  album.isEmpty  ? nil : album,
                year:   year.isEmpty   ? nil : year
            )
            status = "✅ Tags updated!"
        } catch {
            status = "❌ Tag error: \(error.localizedDescription)"
        }
    }

    private func convert(_ url: URL, toExt ext: String) {
        let out = url.deletingPathExtension().appendingPathExtension(ext)
        do {
            switch ext {
            case "mp3": try converter.toMP3(input: url, output: out)
            case "m4a": try converter.toM4A(input: url, output: out)
            default:    break
            }
            status = "✅ Saved \(out.lastPathComponent)"
        } catch {
            status = "❌ Conv. error: \(error.localizedDescription)"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
