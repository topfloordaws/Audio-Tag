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

struct FileMetadata: Identifiable, Hashable {
    let url: URL
    var title:        String = ""
    var artist:       String = ""
    var album:        String = ""
    var albumArtist:  String = ""
    var track:        String = ""
    var genre:        String = ""
    var yearRecorded: String = ""
    var comment:      String = ""
    var artwork:      NSImage? = nil
    var artworkURL:   URL?      = nil
    
    // new
    var dateCreated: Date? = nil
    var dateModified: Date? = nil
    //var dateCreated: Date = .distantPast
    //var dateModified: Date = .distantPast

    
    var dateCreatedString: String {
        guard let dateCreated else { return "" }
        return DateFormatter.localizedString(from: dateCreated, dateStyle: .short, timeStyle: .none)
    }
    var dateModifiedString: String {
        guard let dateModified else { return "" }
        return DateFormatter.localizedString(from: dateModified, dateStyle: .short, timeStyle: .none)
    }

    var id: URL { url }
}

// NSImage to JPEG Data helper for artwork copying
extension NSImage {
    func toJPEGData(compression: CGFloat = 0.95) -> Data? {
        guard let tiff = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compression])
    }
}

struct ContentView: View {
    @State private var fileItems:           [FileMetadata] = []
    @State private var selectedIDs:         Set<URL>       = []
    @State private var status:              String         = ""
    @State private var isShowingCoverPicker                = false
    @State private var coverTargetURL:      URL?           = nil
    @State private var currentFolder:       URL?           = nil
    @State private var copiedTags: FileMetadata?           = nil
    @State private var sortOrder:           [KeyPathComparator<FileMetadata>] = []
    // for loading popup
    @State private var isLoading = false
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage: String = ""
    @State private var filesLoaded = 0
    @State private var filesTotal = 0
    // for search
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    // for output folder saving
    @State private var outputFolder: URL? = nil

    private let tagger    = AudioConverter()
    private let converter = AudioConverter()
    
    var filteredItems: [FileMetadata] {
        if searchText.isEmpty { return fileItems }
        let q = searchText.lowercased()
        return fileItems.filter { file in
            file.url.lastPathComponent.lowercased().contains(q)
            || file.title.lowercased().contains(q)
            || file.artist.lowercased().contains(q)
            || file.album.lowercased().contains(q)
            || file.albumArtist.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            HSplitView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button("Browse Folder", action: pickFolder)
                        if currentFolder != nil {
                            Button("Refresh") { Task { await loadFiles(in: currentFolder!) } }
                        }
                    }
                    Divider()
                    if selectedIDs.count == 1, let sel = selectedIDs.first,
                       let file = fileItems.first(where: { $0.id == sel }) {
                        metadataEditor(for: file)
                    } else if selectedIDs.count > 1 {
                        BatchMetadataEditor(
                            selected: selectedIDs,
                            fileItems: $fileItems,
                            onApply: { status = "Updated \(selectedIDs.count) files." },
                            applyTags: { file in
                                applyTags(to: file)
                            }
                        )
                    } else {
                        Text("Select a file in the table to view/edit its tags.")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(status).foregroundColor(.secondary)
                    if isSearching {
                            HStack {
                                TextField("Search...", text: $searchText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit { isSearching = false }
                                    .onExitCommand {
                                        isSearching = false
                                        searchText = ""
                                    }
                                Button("Cancel") {
                                    isSearching = false
                                    searchText = ""
                                }
                            }
                        }
                    HStack {
                        Button("→ MP3") {
                            for url in fileItems.filter({ selectedIDs.contains($0.id) }).map(\.url) {
                                convert(url, toExt: "mp3")
                            }
                        }
                        Button("→ M4A") {
                            for url in fileItems.filter({ selectedIDs.contains($0.id) }).map(\.url) {
                                convert(url, toExt: "m4a")
                            }
                        }
                        Button("Set Output Folder") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                outputFolder = url
                            }
                        }
                        if let outputFolder = outputFolder {
                            Text("Saving to: \(outputFolder.path)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding()
                .frame(minWidth: 210)
                
                VStack {
                    Table(filteredItems, selection: $selectedIDs, sortOrder: $sortOrder) {
                        TableColumn("Filename", value: \.url.lastPathComponent) { item in
                            Text(item.url.lastPathComponent)
                                .contextMenu {
                                    Button("Copy Tags") {
                                        // Deep copy artwork as well
                                        var meta = item
                                        if let img = item.artwork,
                                           let data = img.tiffRepresentation,
                                           let copiedImg = NSImage(data: data)
                                        {
                                            meta.artwork = copiedImg
                                            // Save a deep-copied image to temp and set artworkURL
                                            let tmpJ = FileManager.default.temporaryDirectory
                                                .appendingPathComponent(UUID().uuidString)
                                                .appendingPathExtension("jpg")
                                            if let jpeg = img.toJPEGData() {
                                                try? jpeg.write(to: tmpJ)
                                                meta.artworkURL = tmpJ
                                            } else {
                                                meta.artworkURL = nil
                                            }
                                        }
                                        copiedTags = meta
                                    }
                                    Button("Paste Tags") {
                                        if let copied = copiedTags, copied.url != item.url {
                                            pasteTags(onto: item)
                                        }
                                    }
                                    .disabled(copiedTags == nil || copiedTags?.url == item.url)
                                }
                        }
                            .width(min: 100, ideal: 200, max: 300)
                        TableColumn("Title",         value: \.title)
                        TableColumn("Artist",        value: \.artist)
                        TableColumn("Album",         value: \.album)
                        TableColumn("Album Artist",  value: \.albumArtist)
                        TableColumn("Track",         value: \.track)
                            .width(min: 40, ideal: 52, max: 60)
                        TableColumn("Genre",         value: \.genre)
                            .width(min: 60, ideal: 70, max: 80)
                        TableColumn("Year Recorded", value: \.yearRecorded)
                            .width(min: 60, ideal: 90, max: 140)
                        TableColumn("Date Created") { item in
                            Text(item.dateCreatedString)
                        }
                            .width(min: 60, ideal: 80, max: 140)
                        TableColumn("Date Modified") { item in
                            Text(item.dateModifiedString)
                        }
                            .width(min: 60, ideal: 80, max: 140)

                    }
                    .onChange(of: sortOrder) { fileItems.sort(using: $0) }
                    .frame(minWidth: 790)
                }
            }
            .frame(minWidth: 1000, minHeight: 500)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
                        isSearching = true
                        return nil // Prevents default handling
                    }
                    if isSearching && event.keyCode == 53 { // 53 is Escape key
                        isSearching = false
                        searchText = ""
                        return nil
                    }
                    return event
                }
            }
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView("Loading files…")
                    Text("\(filesLoaded) of \(filesTotal) files")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                .shadow(radius: 8)
            }
        }
    }

    // MARK: – Folder picker

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles           = false
        panel.canChooseDirectories     = true
        panel.allowsMultipleSelection  = false
        panel.allowedContentTypes      = [.folder]
        if panel.runModal() == .OK, let url = panel.url {
            currentFolder = url
            Task { await loadFiles(in: url) }
        }
    }

    // MARK: – Load files & extract metadata

    private func loadFiles(in folder: URL) async {
        let exts = ["mp3","m4a","wav"]
        let urls = (try? FileManager.default
            .contentsOfDirectory(at: folder,
                                 includingPropertiesForKeys: nil,
                                 options: .skipsHiddenFiles)
            .filter { exts.contains($0.pathExtension.lowercased()) }
        ) ?? []

        var items: [FileMetadata] = urls.map { FileMetadata(url: $0) }
        let total = items.count
        
        await MainActor.run {
            isLoading = true
            loadingProgress = 0
            loadingMessage = "Loading files..."
            //filesLoaded = 0
            filesTotal = urls.count
        }

        // Read metadata for each file
        for idx in items.indices {
            let url = items[idx].url
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey]
            let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys))
            items[idx].dateCreated = resourceValues?.creationDate
            items[idx].dateModified = resourceValues?.contentModificationDate

            let ext = url.pathExtension.lowercased()

            if ext == "mp3" {
                // Use TagLib/MP3Tagger for all fields except artwork
                items[idx].title        = MP3Tagger.readTitle(path: url.path)
                items[idx].artist       = MP3Tagger.readArtist(path: url.path)
                items[idx].album        = MP3Tagger.readAlbum(path: url.path)
                items[idx].albumArtist  = MP3Tagger.readAlbumArtist(path: url.path)
                let trackNum            = MP3Tagger.readTrack(path: url.path)
                items[idx].track        = trackNum > 0 ? "\(trackNum)" : ""
                items[idx].genre        = MP3Tagger.readGenre(path: url.path)
                let yearNum             = MP3Tagger.readYear(path: url.path)
                items[idx].yearRecorded = yearNum > 0 ? "\(yearNum)" : ""
                items[idx].comment      = MP3Tagger.readComment(path: url.path)

                // Still use AVAsset for artwork only
                let asset = AVURLAsset(url: url)
                if let common = try? await asset.load(.commonMetadata) {
                    if let it = common.first(where: { $0.commonKey == .commonKeyArtwork }),
                       let d  = try? await it.load(.dataValue),
                       let i  = NSImage(data: d)
                    {
                        items[idx].artwork = i
                        if let jpeg = i.toJPEGData() {
                            let tmpJ = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension("jpg")
                            try? jpeg.write(to: tmpJ)
                            items[idx].artworkURL = tmpJ
                        }
                    }
                }
            } else {
                // m4a, wav, etc. - use AVAsset as before
                let asset = AVURLAsset(url: url)
                if let common = try? await asset.load(.commonMetadata) {
                    if let it = common.first(where: { $0.commonKey == .commonKeyTitle }),
                       let s  = try? await it.load(.stringValue) {
                        items[idx].title = s
                    }
                    if let it = common.first(where: { $0.commonKey == .commonKeyArtist }),
                       let s  = try? await it.load(.stringValue) {
                        items[idx].artist = s
                    }
                    if let it = common.first(where: { $0.commonKey == .commonKeyAlbumName }),
                       let s  = try? await it.load(.stringValue) {
                        items[idx].album = s
                    }
                    if let it = common.first(where: { $0.commonKey == .commonKeyArtwork }),
                       let d  = try? await it.load(.dataValue),
                       let i  = NSImage(data: d)
                    {
                        items[idx].artwork = i
                        if let jpeg = i.toJPEGData() {
                            let tmpJ = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension("jpg")
                            try? jpeg.write(to: tmpJ)
                            items[idx].artworkURL = tmpJ
                        }
                    }
                }
            }
            let progress = Double(idx + 1) / Double(total)
            await MainActor.run {
                loadingProgress = progress
                filesLoaded = idx + 1
            }
        }

        await MainActor.run {
            fileItems   = items
            selectedIDs = []
            status      = "Found \(urls.count) files"
            isLoading = false
            loadingProgress = 0
            loadingMessage = ""
        }
    }

    // MARK: – Metadata editor UI

    @ViewBuilder
    private func metadataEditor(for file: FileMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                Text("Title")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.title,        in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Artist")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.artist,       in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Album")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.album,        in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Album Artist")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.albumArtist,  in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Track")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.track,        in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Genre")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.genre,        in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Year")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.yearRecorded, in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Comment")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.comment, in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            if let img = file.artwork {
                Image(nsImage: img)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .padding(.vertical, 8)
            }
            HStack {
                Spacer()
                Button("Change Cover") {
                    coverTargetURL       = file.url
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
            guard case .success(let urls) = result,
                  let picked = urls.first,
                  let idx    = fileItems.firstIndex(where: { $0.url == coverTargetURL })
            else { return }
            if let ns = NSImage(contentsOf: picked) {
                fileItems[idx].artwork    = ns
                fileItems[idx].artworkURL = picked
            }
        }
    }

    // MARK: – Two-way binding helper

    private func binding<Value>(
        for keyPath: WritableKeyPath<FileMetadata, Value>,
        in element: FileMetadata
    ) -> Binding<Value> {
        guard let idx = fileItems.firstIndex(of: element) else {
            return .constant(element[keyPath: keyPath])
        }
        return Binding(
            get:  { fileItems[idx][keyPath: keyPath] },
            set:  { fileItems[idx][keyPath: keyPath] = $0 }
        )
    }

    // MARK: – Tag dispatch

    private func applyTags(to file: FileMetadata) {
        status = "Tagging…"
        let ext = file.url.pathExtension.lowercased()

        guard let idx = fileItems.firstIndex(where: { $0.url == file.url }) else { return }
        let current = fileItems[idx]

        switch ext {
        case "mp3":
            let coverData = current.artworkURL.flatMap { try? Data(contentsOf: $0) }
            let coverMime: String? = {
                guard let url = current.artworkURL else { return nil }
                return url.pathExtension.lowercased() == "png"
                    ? "image/png" : "image/jpeg"
            }()
            let success = MP3Tagger.updateTags(
                path:        current.url.path,
                title:       current.title.isEmpty        ? nil : current.title,
                artist:      current.artist.isEmpty       ? nil : current.artist,
                album:       current.album.isEmpty        ? nil : current.album,
                albumArtist: current.albumArtist.isEmpty  ? nil : current.albumArtist,
                track:       Int(current.track),
                year:        Int(current.yearRecorded),
                genre:       current.genre.isEmpty        ? nil : current.genre,
                comment:     current.comment.isEmpty      ? nil : current.comment,
                coverData:   coverData,
                coverMime:   coverData != nil ? coverMime : nil
            )
            status = success ? "Tags updated" : "Error: Tag update failed"

        case "m4a":
            tagger.tagM4A(
                file:        file.url,
                title:       current.title.isEmpty        ? nil : current.title,
                artist:      current.artist.isEmpty       ? nil : current.artist,
                album:       current.album.isEmpty        ? nil : current.album,
                year:        current.yearRecorded.isEmpty ? nil : current.yearRecorded,
                albumArtist: current.albumArtist.isEmpty  ? nil : current.albumArtist,
                trackNumber: current.track.isEmpty        ? nil : current.track,
                genre:       current.genre.isEmpty        ? nil : current.genre,
                coverArt:    current.artworkURL
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        status = "Tags updated"
                    case .failure(let err):
                        status = "Error: \(err.localizedDescription)"
                    }
                }
            }

        case "wav":
            tagger.tagWAV(
                file:        file.url,
                title:       current.title.isEmpty        ? nil : current.title,
                artist:      current.artist.isEmpty       ? nil : current.artist,
                album:       current.album.isEmpty        ? nil : current.album,
                year:        current.yearRecorded.isEmpty ? nil : current.yearRecorded,
                albumArtist: current.albumArtist.isEmpty  ? nil : current.albumArtist,
                trackNumber: current.track.isEmpty        ? nil : current.track,
                genre:       current.genre.isEmpty        ? nil : current.genre
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        status = "Tags updated"
                    case .failure(let err):
                        status = "Error: \(err.localizedDescription)"
                    }
                }
            }

        default:
            status = "Unsupported file type: \(ext.uppercased())"
        }
    }

    private func pasteTags(onto target: FileMetadata) {
        guard let idx = fileItems.firstIndex(where: { $0.url == target.url }),
              let source = copiedTags
        else { return }

        // Only copy actual tag fields, not URLs or dates
        fileItems[idx].title        = source.title
        fileItems[idx].artist       = source.artist
        fileItems[idx].album        = source.album
        fileItems[idx].albumArtist  = source.albumArtist
        fileItems[idx].track        = source.track
        fileItems[idx].genre        = source.genre
        fileItems[idx].yearRecorded = source.yearRecorded

        // Deep copy artwork
        if let img = source.artwork,
           let data = img.tiffRepresentation,
           let copiedImg = NSImage(data: data)
        {
            fileItems[idx].artwork = copiedImg
            let tmpJ = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            if let jpeg = img.toJPEGData() {
                try? jpeg.write(to: tmpJ)
                fileItems[idx].artworkURL = tmpJ
            } else {
                fileItems[idx].artworkURL = nil
            }
        } else {
            fileItems[idx].artwork = nil
            fileItems[idx].artworkURL = nil
        }

        // Optionally, select the target file so that the sidebar shows its tags
        selectedIDs = [target.url]
    }

    // MARK: – Conversion dispatch

    private func convert(_ url: URL, toExt ext: String) {
        let out: URL
        if let folder = outputFolder {
            out = folder.appendingPathComponent(url.deletingPathExtension().lastPathComponent)
                        .appendingPathExtension(ext)
        } else {
            out = url.deletingPathExtension().appendingPathExtension(ext)
        }
        status = "⏳ Converting"
        switch (url.pathExtension.lowercased(), ext) {
        case ("wav", "mp3"):
            converter.toMP3(input: url, output: out) { res in
                DispatchQueue.main.async {
                    switch res {
                    case .success:
                        status = "Saved \(out.lastPathComponent)"
                    case .failure(let err):
                        status = "Conversion error: \(err.localizedDescription)"
                    }
                }
            }
            
        case ("m4a", "mp3"):
            converter.m4aToMP3WithJPEGCover(inputM4A: url, outputMP3: out) { res in
                DispatchQueue.main.async {
                    switch res {
                    case .success:
                        status = "Saved \(out.lastPathComponent)"
                    case .failure(let err):
                        status = "Conversion error: \(err.localizedDescription)"
                    }
                }
            }

        case ("mp3", "mp3"):
            converter.toMP3(input: url, output: out) { res in
                DispatchQueue.main.async {
                    switch res {
                    case .success:
                        status = "Saved \(out.lastPathComponent)"
                    case .failure(let err):
                        status = "Conversion error: \(err.localizedDescription)"
                    }
                }
            }

        case ("m4a", "m4a"):
            converter.toM4A(input: url, output: out) { res in
                DispatchQueue.main.async {
                    switch res {
                    case .success:
                        status = "Saved \(out.lastPathComponent)"
                    case .failure(let err):
                        status = "Conversion error: \(err.localizedDescription)"
                    }
                }
            }

        default:
            break
        }
    }
}

// MARK: – Batch Editor (now calls applyTags for each file!)
struct BatchMetadataEditor: View {
    let selected: Set<URL>
    @Binding var fileItems: [FileMetadata]
    var onApply: () -> Void
    var applyTags: (FileMetadata) -> Void

    @State private var title: String = ""
    @State private var artist: String = ""
    @State private var album: String = ""
    @State private var albumArtist: String = ""
    @State private var track: String = ""
    @State private var genre: String = ""
    @State private var yearRecorded: String = ""
    @State private var artwork: NSImage? = nil
    @State private var showCoverPicker = false
    @State private var comment: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Editing \(selected.count) files").font(.headline)
            Group {
                Text("Title").font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("Leave blank to skip", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Artist").font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("Leave blank to skip", text: $artist)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Album").font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("Leave blank to skip", text: $album)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Album Artist").font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("Leave blank to skip", text: $albumArtist)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Track").font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("Leave blank to skip", text: $track)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Genre").font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("Leave blank to skip", text: $genre)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Year").font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("Leave blank to skip", text: $yearRecorded)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Comment").font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("Leave blank to skip", text: $comment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            if let img = artwork {
                Image(nsImage: img)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .padding(.vertical, 8)
            }
            HStack {
                Spacer()
                Button("Change Cover") { showCoverPicker = true }
                Spacer()
            }
            HStack {
                Spacer()
                Button("Apply to All") {
                    applyBatchTags()
                    onApply()
                }
                Spacer()
            }
        }
        .padding(.top, 16)
        .fileImporter(
            isPresented: $showCoverPicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result,
                  let picked = urls.first,
                  let ns = NSImage(contentsOf: picked)
            else { return }
            artwork = ns
        }
    }

    private func applyBatchTags() {
        for url in selected {
            if let idx = fileItems.firstIndex(where: { $0.url == url }) {
                if !title.isEmpty        { fileItems[idx].title        = title }
                if !artist.isEmpty       { fileItems[idx].artist       = artist }
                if !album.isEmpty        { fileItems[idx].album        = album }
                if !albumArtist.isEmpty  { fileItems[idx].albumArtist  = albumArtist }
                if !track.isEmpty        { fileItems[idx].track        = track }
                if !genre.isEmpty        { fileItems[idx].genre        = genre }
                if !yearRecorded.isEmpty { fileItems[idx].yearRecorded = yearRecorded }
                if !comment.isEmpty      { fileItems[idx].comment      = comment }
                if let img = artwork     {
                    fileItems[idx].artwork = img
                    let tmpJ = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    if let jpeg = img.toJPEGData() {
                        try? jpeg.write(to: tmpJ)
                        fileItems[idx].artworkURL = tmpJ
                    }
                }
                // Actually persist the tag changes to disk for each file!
                applyTags(fileItems[idx])
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
