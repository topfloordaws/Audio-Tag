//
//
//  ContentView.swift
//  Audio Tag
//
//  Created by Dawson Pham on 6/24/25.
//

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

// Model for the file and its extracted metadata
struct FileMetadata: Identifiable, Hashable {
    let url: URL
    var title:        String = ""
    var artist:       String = ""
    var album:        String = ""
    var yearRecorded: String = ""
    var track:        String = ""
    var genre:        String = ""
    var albumArtist:  String = ""
    var artwork:      NSImage? = nil
    var artworkURL:   URL?  = nil
    var creationDate: Date? = nil
    var modifiedDate: Date? = nil
    var accessedDate: Date? = nil

    var id: URL { url }
}

struct ContentView: View {
    // State
    @State private var fileItems:    [FileMetadata] = []
    @State private var selectedIDs:  Set<URL>       = []
    @State private var status:       String         = ""
    @State private var isShowingCoverPicker = false
    @State private var coverTargetURL: URL? = nil
    // for refresh button
    @State private var currentFolder: URL?          = nil
    // for sorting files
    @State private var sortOrder: [KeyPathComparator<FileMetadata>] = []

    private let tagger    = AudioConverter()
    private let converter = AudioConverter()

    var body: some View {
        HSplitView {
            // Left pane: folder picker + editor
            VStack(alignment: .leading, spacing: 16) {
                // pick folder (and implicit file group) + refresh
                HStack {
                    Button("Browse Folder", action: pickFolder)
                        if currentFolder != nil {
                            Button("Refresh") {
                                Task {
                                   await loadFiles(in: currentFolder!)
                                }
                        }
                    }
                }
                Divider()
                // metadata editor for the first selected file
                if let selURL = selectedIDs.first,
                   let file   = fileItems.first(where: { $0.id == selURL })
                {
                    metadataEditor(for: file)
                } else {
                    Text("Select a file in the table to view/edit its tags.")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(status).foregroundColor(.secondary)
                
                Button("→ MP3") {
                    // convert every selected file to .mp3
                    for url in fileItems
                      .filter({ selectedIDs.contains($0.id) })
                      .map(\.url)
                    {
                      convert(url, toExt: "mp3")
                    }
                  }
                Button("→ M4A") {
                    // convert every selected file to .m4a
                    for url in fileItems
                      .filter({ selectedIDs.contains($0.id) })
                      .map(\.url)
                    {
                      convert(url, toExt: "m4a")
                    }
                  }
            }
            .padding()
            .frame(minWidth: 210)

            // Right pane: horizontal metadata table
            VStack {
                Table(fileItems, selection: $selectedIDs, sortOrder: $sortOrder) {
                    TableColumn("Filename",      value: \.url.lastPathComponent)
                    TableColumn("Title",         value: \.title)
                    TableColumn("Artist",        value: \.artist)
                    TableColumn("Album",         value: \.album)
                    TableColumn("Album Artist",  value: \.albumArtist)
                    TableColumn("Track",         value: \.track)
                    TableColumn("Genre",         value: \.genre)
                    TableColumn("Year Recorded", value: \.yearRecorded)
                }
                .onChange(of: sortOrder) {
                  fileItems.sort(using: sortOrder)
                }
                .frame(minWidth: 790)
            }
        }
        .frame(minWidth: 1000, minHeight: 500)
    }

    // Folder picker

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles       = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes     = [.folder]
        if panel.runModal() == .OK, let url = panel.url {
            currentFolder = url
            Task { await loadFiles(in: url) }
        }
    }

    // Load files & extract metadata

    private func loadFiles(in folder: URL) async {
        // Gatherx all .mp3, .m4a, and .wav files in the folder
        let audioExts = ["mp3","m4a","wav"]
        let urls = (try? FileManager.default
            .contentsOfDirectory(at: folder,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles)
            .filter { audioExts.contains($0.pathExtension.lowercased()) }
        ) ?? []

        // Seed model
        let items = urls.map { FileMetadata(url: $0) }


        // Publish preliminary list
        await MainActor.run {
            self.fileItems   = items
            self.selectedIDs = []
            self.status      = "Found \(items.count) files"
        }

        // Load metadata for each file
        for idx in items.indices {
            let url = items[idx].url

                // 2a) grab fs dates:
                if let rv = try? url.resourceValues(
                     forKeys: [.creationDateKey,
                               .contentModificationDateKey,
                               .contentAccessDateKey])
                {
                    await MainActor.run {
                        self.fileItems[idx].creationDate = rv.creationDate
                        self.fileItems[idx].modifiedDate = rv.contentModificationDate
                        self.fileItems[idx].accessedDate = rv.contentAccessDate
                    }
                }
            
            let asset = AVURLAsset(url: items[idx].url)

            // common tags and artwork
            if let common = try? await asset.load(.commonMetadata) {
                if let t = common.first(where: { $0.commonKey == .commonKeyTitle }),
                   let s = try? await t.load(.stringValue) {
                    await MainActor.run { self.fileItems[idx].title = s }
                }
                if let a = common.first(where: { $0.commonKey == .commonKeyArtist }),
                   let s = try? await a.load(.stringValue) {
                    await MainActor.run { self.fileItems[idx].artist = s }
                }
                if let al = common.first(where: { $0.commonKey == .commonKeyAlbumName }),
                   let s = try? await al.load(.stringValue) {
                    await MainActor.run { self.fileItems[idx].album = s }
                }
                
                
                if let art = common.first(where: { $0.commonKey == .commonKeyArtwork }),
                   let rawData = try? await art.load(.dataValue),
                   let nsImage = NSImage(data: rawData)
                {
                    // display in-memory
                    await MainActor.run {
                        self.fileItems[idx].artwork = nsImage
                    }

                    // write same `rawData` to disk while still in scope
                    let tmp = FileManager.default
                        .temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    do {
                        try rawData.write(to: tmp)
                        await MainActor.run {
                            self.fileItems[idx].artworkURL = tmp
                        }
                    } catch {
                        print("couldn’t write cover-art:", error)
                    }
                }

                
                if fileItems[idx].yearRecorded.isEmpty,
                   let cd = common.first(where: { $0.commonKey == .commonKeyCreationDate }),
                   let raw = try? await cd.load(.stringValue)
                    
                {
                    let yearOnly = String(raw.prefix(4))
                    await MainActor.run {
                        self.fileItems[idx].yearRecorded = yearOnly
                    }
                }
                if self.fileItems[idx].yearRecorded.isEmpty {
                    if let mp4Items = try? await asset.loadMetadata(for: .iTunesMetadata),
                       let rd = mp4Items.first(where: { $0.identifier == .iTunesMetadataReleaseDate }),
                       let raw = try? await rd.load(.stringValue)
                    {
                        let yearOnly = String(raw.prefix(4))
                        await MainActor.run {
                            self.fileItems[idx].yearRecorded = yearOnly
                        }
                    }
                }
            }

            // ID3 frames for “Year Recorded” (TDRC), track & genre & album artist (TPE2)
            if let id3Items = try? await asset.loadMetadata(for: .id3Metadata) {
                // Year Recorded (TDRC)
                if let rc = id3Items.first(where: { $0.identifier == .id3MetadataRecordingTime }),
                   let raw = try? await rc.load(.stringValue)
                {
                    let yearOnly = String(raw.prefix(4))
                    await MainActor.run { self.fileItems[idx].yearRecorded = yearOnly }
                }
                // Year Recorded "TYLER" frame
                if self.fileItems[idx].yearRecorded.isEmpty,
                    let y2 = id3Items.first(where: { $0.identifier == .id3MetadataYear }),
                    let raw2 = try? await y2.load(.stringValue)
                {
                    let yearOnly2 = String(raw2.prefix(4))
                    await MainActor.run { self.fileItems[idx].yearRecorded = yearOnly2 }
                }

                // Track number
                if let tn = id3Items.first(where: { $0.identifier == .id3MetadataTrackNumber }),
                   let s  = try? await tn.load(.stringValue)
                {
                    await MainActor.run { self.fileItems[idx].track = s }
                }

                // Genre
                if let gr = id3Items.first(where: { $0.identifier == .id3MetadataContentType }),
                   let s  = try? await gr.load(.stringValue)
                {
                    await MainActor.run { self.fileItems[idx].genre = s }
                }

                // Album Artist (TPE2 frame via ID3)
                let tpe2Items = AVMetadataItem.metadataItems(
                    from: id3Items,
                    withKey: "TPE2",
                    keySpace: .id3
                )
                if let aaItem = tpe2Items.first,
                   let aa = try? await aaItem.load(.stringValue) {
                    await MainActor.run {
                        self.fileItems[idx].albumArtist = aa
                    }
                }
            }
        }
    }

    // Metadata editor UI

    @ViewBuilder
    private func metadataEditor(for file: FileMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Title")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
              TextField("", text: binding(for: \.title, in: file))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            VStack(alignment: .leading, spacing: 4) {
              Text("Artist")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
              TextField("", text: binding(for: \.artist, in: file))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            VStack(alignment: .leading, spacing: 4) {
              Text("Album")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
              TextField("", text: binding(for: \.album, in: file))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            VStack(alignment: .leading, spacing: 4) {
              Text("Album Artist")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
              TextField("", text: binding(for: \.albumArtist, in: file))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
           // TextField("Artist",      text: binding(for: \.artist,       in: file))
          //  TextField("Album",       text: binding(for: \.album,        in: file))
           // TextField("Album Artist",text: binding(for: \.albumArtist, in: file))
            
            VStack(alignment: .leading, spacing: 4) {
              Text("Track Number")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
              TextField("", text: binding(for: \.track, in: file))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
              Text("Year Recorded")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
              TextField("", text: binding(for: \.yearRecorded, in: file))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            /*
            HStack {
                TextField("Track",        text: binding(for: \.track,        in: file))
                    .frame(width: 60)
                TextField("Year Recorded",text: binding(for: \.yearRecorded,in: file))
                    .frame(width: 80)
            }
            */
            
            VStack(alignment: .leading, spacing: 4) {
              Text("Genre")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
              TextField("", text: binding(for: \.genre, in: file))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            if let img = file.artwork {
                HStack {
                    Spacer()
                    Image(nsImage: img)
                      .resizable()
                      .scaledToFit()
                      .frame(maxWidth: .infinity, maxHeight: 200)
                }
                .padding(.vertical, 8)
            }
            
            HStack{
                Spacer()
                Button("Change Cover") {
                    coverTargetURL = file.url
                    isShowingCoverPicker = true
                }
                Spacer()
            }
            
            HStack {
                Spacer()
                Button("Apply Tags") { applyTags(to: file) }
                Spacer()
            }
        }
        .padding(.top, 16)
        .fileImporter(
              isPresented: $isShowingCoverPicker,
              allowedContentTypes: [.image],
              allowsMultipleSelection: false
            ) { result in
              guard
                case .success(let urls) = result,
                let picked = urls.first,
                let idx = fileItems.firstIndex(where: { $0.url == coverTargetURL })
              else { return }

              // update both artwork & artworkURL
              if let ns = NSImage(contentsOf: picked) {
                fileItems[idx].artwork = ns
                fileItems[idx].artworkURL = picked
              }
            }
    }

    // Two-way binding into `fileItems`
    private func binding<Value>(
        for keyPath: WritableKeyPath<FileMetadata,Value>,
        in element: FileMetadata
    ) -> Binding<Value> {
        guard let idx = fileItems.firstIndex(of: element) else {
            return .constant(element[keyPath: keyPath])
        }
        return Binding(
            get: { fileItems[idx][keyPath: keyPath] },
            set: { fileItems[idx][keyPath: keyPath] = $0 }
        )
    }

    // Tagging

    private func applyTags(to file: FileMetadata) {
      status = "Tagging"
      tagger.tagMP3(
        file:         file.url,
        title:        file.title.isEmpty       ? nil : file.title,
        artist:       file.artist.isEmpty      ? nil : file.artist,
        album:        file.album.isEmpty       ? nil : file.album,
        year:         file.yearRecorded.isEmpty ? nil : file.yearRecorded,  //  fixed
        albumArtist:  file.albumArtist.isEmpty ? nil : file.albumArtist,
        trackNumber:  file.track.isEmpty       ? nil : file.track,
        genre:        file.genre.isEmpty       ? nil : file.genre,
        coverArt:     file.artworkURL
      ) { result in
        DispatchQueue.main.async {
          self.status = result.isSuccess
            ? "Tags updated"
            : "\(result.error!.localizedDescription)"
        }
      }
    }

    // call your AudioConverter under the hood
    private func convert(_ url: URL, toExt ext: String) {
        let out = url.deletingPathExtension()
            .appendingPathExtension(ext)
        status = "⏳ Converting…"
        switch ext {
        case "mp3":
            converter.toMP3(input: url, output: out) { result in
                DispatchQueue.main.async {
                    status = result.isSuccess
                    ? "✅ Saved \(out.lastPathComponent)"
                    : "❌ Conv. error: \(result.error!.localizedDescription)"
                }
            }
        case "m4a":
            converter.toM4A(input: url, output: out) { result in
                DispatchQueue.main.async {
                    status = result.isSuccess
                    ? "✅ Saved \(out.lastPathComponent)"
                    : "❌ Conv. error: \(result.error!.localizedDescription)"
                }
            }
        default:
        break
        }
    }
}

// convenience helpers on Result
private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    var error: Error? {
        if case .failure(let e) = self { return e }
        return nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
