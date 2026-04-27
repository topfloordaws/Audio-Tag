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

#if !targetEnvironment(simulator)
import TagLib
#endif

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
    var artworkURL:   URL?     = nil
    var artworkData:  Data?    = nil
    var artworkMime:  String?  = nil
    
    // new
    var dateCreated:  Date?    = nil
    var dateModified: Date?    = nil
    //var dateCreated: Date = .distantPast
    //var dateModified: Date = .distantPast

    var sortableDateCreated: Date { dateCreated ?? .distantPast }
    var sortableDateModified: Date { dateModified ?? .distantPast }
    
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
    // for audio playback
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var duration: Double = 0     // seconds
    @State private var currentTime: Double = 0  // seconds
    @State private var isUserSeeking = false    // disables timer update during user drag
    
    // for error handling
    @State private var showingErrorAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // for clear tags safety check
    @State private var showingClearTagsAlert: Bool = false
    @State private var fileToClear: FileMetadata? = nil

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
            // Invisible buttons to act as Native Keyboard Shortcuts for File operations
            Button("") { pickFolder() }
                .keyboardShortcut("o", modifiers: .command)
                .hidden()
            
            Button("") {
                if let folder = currentFolder { Task { await loadFiles(in: folder) } }
            }
            .keyboardShortcut("r", modifiers: .command)
            .hidden()

            HSplitView {
                // Left Pane
                ZStack {
                    Color(NSColor.windowBackgroundColor)
                        .ignoresSafeArea()
                    
                    Group {
                        if currentFolder == nil {
                            VStack {
                                Spacer()
                                Button("Browse Folder", action: pickFolder)
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                                Spacer()
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
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
                                    Spacer()
                                }
                                
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
                                
                                // Centered Conversion Buttons and Output Path
                                VStack(spacing: 8) {
                                    HStack {
                                        Spacer()
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
                                        Button("Set Output") {
                                            let panel = NSOpenPanel()
                                            panel.canChooseFiles = false
                                            panel.canChooseDirectories = true
                                            panel.allowsMultipleSelection = false
                                            if panel.runModal() == .OK, let url = panel.url {
                                                outputFolder = url
                                            }
                                        }
                                        Spacer()
                                    }

                                    if let outputFolder = outputFolder {
                                        Text("Saving to: \(outputFolder.path)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(NSColor.textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .padding(12)
                }
                .frame(width: 320) // Locked width for Xcode-style static sidebar
                
                // Right Pane
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
                                                meta.artworkData = jpeg
                                                meta.artworkMime = "image/jpeg"
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
                                    
                                    Button("Clear Tags") {
                                        fileToClear = item
                                        showingClearTagsAlert = true
                                    }
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
                        TableColumn("Date Created", value: \.sortableDateCreated) { item in
                            Text(item.dateCreatedString)
                        }
                            .width(min: 60, ideal: 80, max: 140)
                        TableColumn("Date Modified", value: \.sortableDateModified) { item in
                            Text(item.dateModifiedString)
                        }
                            .width(min: 60, ideal: 80, max: 140)

                    }
                    .onChange(of: sortOrder) { _, newValue in
                        fileItems.sort(using: newValue)
                    }
                    .onChange(of: selectedIDs) { _, newSelection in
                        if newSelection.count == 1, let url = newSelection.first {
                            Task { await loadArtworkIfNeeded(for: url) }
                        }
                    }
                    .frame(minWidth: 790)
                }
                .frame(minWidth: 600, maxWidth: .infinity)
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
                NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenFolderMenuAction"), object: nil, queue: .main) { _ in
                    pickFolder()
                }
                NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshFolderMenuAction"), object: nil, queue: .main) { _ in
                    if let folder = currentFolder { Task { await loadFiles(in: folder) } }
                }
            }
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView("Indexing Files…", value: Double(filesLoaded), total: Double(filesTotal))
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    Text("\(filesLoaded) of \(filesTotal) files")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
                .shadow(radius: 8)
            }
        }
        .alert("Error Encountered", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {
                if status == "Update failed" || status == "Conversion failed" {
                    status = "Ready"
                }
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Are you sure you want to clear the tags of this file?", isPresented: $showingClearTagsAlert, presenting: fileToClear) { file in
            Button("Yes", role: .destructive) {
                clearTags(for: file)
            }
            Button("No", role: .cancel) {}
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

    // MARK: - CONCURRENT LOADING (Lazy/Parallel Indexing)

    private func loadFiles(in folder: URL) async {
        await MainActor.run {
            self.fileItems = []
            self.filesLoaded = 0
            self.filesTotal = 0
            self.isLoading = true
            self.status = "Locating files..."
        }

        let keys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey]
        let urls = await Task.detached {
            let exts = ["mp3", "m4a", "wav"]
            return (try? FileManager.default
                .contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)
                .filter { exts.contains($0.pathExtension.lowercased()) }
            ) ?? []
        }.value

        await MainActor.run {
            self.filesTotal = urls.count
            self.status = "Indexing..."
        }

        // Isolate state mutation: Aggregate results locally to prevent SwiftUI Table thrashing
        var localItems: [FileMetadata] = []
        localItems.reserveCapacity(urls.count)

        await withTaskGroup(of: FileMetadata?.self) { group in
            let maxConcurrentTasks = 8
            var index = 0
            
            while index < min(maxConcurrentTasks, urls.count) {
                let url = urls[index]
                group.addTask { return await self.extractMetadata(for: url) }
                index += 1
            }
            
            for await result in group {
                if let meta = result {
                    localItems.append(meta)
                    await MainActor.run {
                        self.filesLoaded += 1
                    }
                }
                
                if index < urls.count {
                    let url = urls[index]
                    group.addTask { return await self.extractMetadata(for: url) }
                    index += 1
                }
            }
        }

        // Apply global state mutation exactly once
        await MainActor.run {
            self.fileItems = localItems
            if !self.sortOrder.isEmpty {
                self.fileItems.sort(using: self.sortOrder)
            }
            self.isLoading = false
            self.status = "Ready: \(self.fileItems.count) files"
        }
    }

    private func extractMetadata(for url: URL) async -> FileMetadata? {
        var item = FileMetadata(url: url)
        let resourceKeys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey]
        let resourceValues = try? url.resourceValues(forKeys: Set(resourceKeys))
        item.dateCreated = resourceValues?.creationDate
        item.dateModified = resourceValues?.contentModificationDate

        let ext = url.pathExtension.lowercased()

        if ext == "mp3" {
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                item.title = url.lastPathComponent
                return item
            }
            #endif
            
            #if !targetEnvironment(simulator)
            let tags = MP3Tagger.readAllTags(path: url.path)
            item.title        = tags.title
            item.artist       = tags.artist
            item.album        = tags.album
            item.albumArtist  = tags.albumArtist
            item.track        = tags.track > 0 ? "\(tags.track)" : ""
            item.genre        = tags.genre
            item.yearRecorded = tags.year > 0 ? "\(tags.year)" : ""
            item.comment      = tags.comment
            #endif
        } else {
            let asset = AVURLAsset(url: url)
            if let common = try? await asset.load(.commonMetadata) {
                item.title = (try? await common.first(where: { $0.commonKey == AVMetadataKey.commonKeyTitle })?.load(.stringValue)) ?? ""
                item.artist = (try? await common.first(where: { $0.commonKey == AVMetadataKey.commonKeyArtist })?.load(.stringValue)) ?? ""
                item.album = (try? await common.first(where: { $0.commonKey == AVMetadataKey.commonKeyAlbumName })?.load(.stringValue)) ?? ""
            }
        }
        
        return item
    }

    private func loadArtworkIfNeeded(for url: URL) async {
        guard let idx = fileItems.firstIndex(where: { $0.url == url }),
              fileItems[idx].artwork == nil else { return }
        
        let asset = AVURLAsset(url: url)
        if let common = try? await asset.load(.commonMetadata),
           let it = common.first(where: { $0.commonKey == AVMetadataKey.commonKeyArtwork }),
           let d  = try? await it.load(.dataValue),
           let i  = NSImage(data: d) {
            
            await MainActor.run {
                if let currentIdx = self.fileItems.firstIndex(where: { $0.url == url }) {
                    self.fileItems[currentIdx].artwork = i
                }
            }
        }
    }

    // MARK: – Metadata editor UI

    @ViewBuilder
    private func metadataEditor(for file: FileMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                Text("Title")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.title, in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Artist")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.artist, in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Album")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.album, in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Album Artist")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.albumArtist, in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Track")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.track, in: file))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Group {
                Text("Genre")
                    .font(.subheadline).foregroundColor(.secondary).padding(.leading, 4)
                TextField("", text: binding(for: \.genre, in: file))
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
            
            // Artwork Section
            Group {
                if let img = file.artwork {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200) // Stabilized dimensions
                        .cornerRadius(8)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .contextMenu {
                            Button("Extract Artwork") {
                                extractArtwork(from: file)
                            }
                        }
                } else {
                    // Placeholder for missing artwork
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .frame(width: 200, height: 200)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
            }

            // Grouped Action Controls
            HStack(spacing: 12) {
                Spacer()
                Button("Edit Artwork") {
                    coverTargetURL = file.url
                    isShowingCoverPicker = true
                }
                .buttonStyle(.bordered)
                
                Button("Apply Tags") {
                    applyTags(to: file)
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(.top, 4)

            Spacer()
            
            // AUDIO PLAYER UI
            let audioURL = file.url
            HStack {
                Button(action: {
                    if isPlaying {
                        player?.pause()
                    } else {
                        if player == nil || (player?.currentItem?.asset as? AVURLAsset)?.url != audioURL {
                            player = AVPlayer(url: audioURL)
                            if let item = player?.currentItem {
                                Task {
                                    let durationSeconds = try? await item.asset.load(.duration).seconds
                                    await MainActor.run {
                                        duration = durationSeconds ?? 0
                                    }
                                }
                            }
                        }
                        player?.play()
                    }
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                Button(action: {
                    player?.pause()
                    player = nil
                    isPlaying = false
                    currentTime = 0
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            Slider(value: Binding(
                get: { currentTime },
                set: { newValue in
                    isUserSeeking = true
                    currentTime = newValue
                }
            ), in: 0...max(duration, 1), onEditingChanged: { editing in
                if !editing, let player = player {
                    let seekTime = CMTime(seconds: currentTime, preferredTimescale: 600)
                    player.seek(to: seekTime)
                    isUserSeeking = false
                }
            })
            .accentColor(.blue)
            .disabled(duration == 0)
            
            HStack {
                Text(timeString(currentTime)).font(.caption.monospacedDigit())
                Spacer()
                Text(timeString(duration)).font(.caption.monospacedDigit())
            }

        }
        .fileImporter(isPresented: $isShowingCoverPicker,
                      allowedContentTypes: [.image],
                      allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result,
                  let picked = urls.first,
                  let idx = fileItems.firstIndex(where: { $0.url == coverTargetURL })
            else { return }

            // 1. Request strict system permission to read the selected file
            guard picked.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource.")
                return
            }
            // Ensure we relinquish the permission when done
            defer { picked.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: picked),
               let img  = NSImage(data: data) {
                
                // 2. Update the UI state
                fileItems[idx].artwork     = img
                fileItems[idx].artworkData = data
                
                let ext = picked.pathExtension.lowercased()
                fileItems[idx].artworkMime = (ext == "png") ? "image/png" : "image/jpeg"
                
                // 3. Cache to a temporary directory so FFmpeg has unrestricted access later
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext == "png" ? "png" : "jpg")
                
                do {
                    try data.write(to: tmpURL)
                    fileItems[idx].artworkURL = tmpURL // Critical fix for FFmpeg
                } catch {
                    print("Failed to write temporary artwork file: \(error)")
                }
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if let player = player, !isUserSeeking {
                currentTime = player.currentTime().seconds
            }
        }
        .onChange(of: file.url) {
            player?.pause()
            player = nil
            isPlaying = false
            currentTime = 0
            duration = 0
        }
    }
    
    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "--:--" }
        let sec = Int(seconds)
        let min = sec / 60
        let rem = sec % 60
        return String(format: "%d:%02d", min, rem)
    }

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

    private func applyTags(to file: FileMetadata) {
        status = "Tagging…"
        player?.pause()
        player = nil

        let ext = file.url.pathExtension.lowercased()
        guard let idx = fileItems.firstIndex(where: { $0.url == file.url }) else { return }
        let current = fileItems[idx]

        switch ext {
        case "mp3":
            let coverData = current.artworkURL.flatMap { try? Data(contentsOf: $0) }
            let finalCoverData = coverData ?? current.artworkData
            
            let coverMime: String? = {
                guard let url = current.artworkURL else {
                    return current.artworkMime ?? "image/jpeg"
                }
                return url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
            }()
            
            #if !targetEnvironment(simulator)
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
                coverData:   finalCoverData,
                coverMime:   finalCoverData != nil ? coverMime : nil
            )
            if success {
                status = "Tags updated"
            } else {
                alertMessage = "MP3 Tag update failed."
                showingErrorAlert = true
                status = "Update failed"
            }
            #endif

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
                    case .success: status = "Tags updated"
                    case .failure(let err):
                        alertMessage = err.localizedDescription
                        showingErrorAlert = true
                        status = "Update failed"
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
                    case .success: status = "Tags updated"
                    case .failure(let err):
                        alertMessage = err.localizedDescription
                        showingErrorAlert = true
                        status = "Update failed"
                    }
                }
            }

        default:
            status = "Unsupported file type: \(ext.uppercased())"
        }
    }
    
    private func clearTags(for target: FileMetadata) {
        guard let idx = fileItems.firstIndex(where: { $0.url == target.url }) else { return }
        fileItems[idx].title = ""; fileItems[idx].artist = ""; fileItems[idx].album = ""
        fileItems[idx].albumArtist = ""; fileItems[idx].track = ""; fileItems[idx].genre = ""
        fileItems[idx].yearRecorded = ""; fileItems[idx].comment = ""; fileItems[idx].artwork = nil
        fileItems[idx].artworkURL = nil; fileItems[idx].artworkData = nil; fileItems[idx].artworkMime = nil
        applyTags(to: fileItems[idx])
    }

    private func pasteTags(onto target: FileMetadata) {
        guard let idx = fileItems.firstIndex(where: { $0.url == target.url }), let source = copiedTags else { return }
        fileItems[idx].title = source.title; fileItems[idx].artist = source.artist; fileItems[idx].album = source.album
        fileItems[idx].albumArtist = source.albumArtist; fileItems[idx].track = source.track; fileItems[idx].genre = source.genre
        fileItems[idx].yearRecorded = source.yearRecorded

        if let img = source.artwork, let data = img.tiffRepresentation, let copiedImg = NSImage(data: data) {
            fileItems[idx].artwork = copiedImg
            let tmpJ = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
            if let jpeg = img.toJPEGData() {
                try? jpeg.write(to: tmpJ)
                fileItems[idx].artworkURL = tmpJ; fileItems[idx].artworkData = jpeg; fileItems[idx].artworkMime = "image/jpeg"
            }
        }
        selectedIDs = [target.url]
    }

    private func convert(_ url: URL, toExt ext: String) {
        let out = outputFolder?.appendingPathComponent(url.deletingPathExtension().lastPathComponent).appendingPathExtension(ext) ?? url.deletingPathExtension().appendingPathExtension(ext)
        status = "⏳ Converting"
        switch (url.pathExtension.lowercased(), ext) {
        case ("wav", "mp3"), ("m4a", "mp3"), ("mp3", "mp3"):
            converter.robustM4AToMP3(input: url, output: out) { res in
                DispatchQueue.main.async {
                    switch res {
                    case .success: status = "Saved \(out.lastPathComponent)"; addConvertedFile(url: out)
                    case .failure(let err):
                        alertMessage = err.localizedDescription; showingErrorAlert = true; status = "Conversion failed"
                    }
                }
            }
        case ("m4a", "m4a"):
            converter.toM4A(input: url, output: out) { res in
                DispatchQueue.main.async {
                    switch res {
                    case .success: status = "Saved \(out.lastPathComponent)"; addConvertedFile(url: out)
                    case .failure(let err):
                        alertMessage = err.localizedDescription; showingErrorAlert = true; status = "Conversion failed"
                    }
                }
            }
        default: break
        }
    }
    
    private func addConvertedFile(url: URL) {
        guard let folder = currentFolder, url.deletingLastPathComponent() == folder else { return }
        if !fileItems.contains(where: { $0.url == url }) {
            var newItem = FileMetadata(url: url)
            let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            newItem.dateCreated = resourceValues?.creationDate
            newItem.dateModified = resourceValues?.contentModificationDate
            fileItems.append(newItem); fileItems.sort(using: sortOrder)
        }
    }
    
    private func extractArtwork(from file: FileMetadata) {
        guard let imgData = file.artworkData ?? file.artwork?.toJPEGData() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = file.title.isEmpty ? "CoverArt" : "\(file.title)_CoverArt"
        panel.allowedContentTypes = file.artworkMime == "image/png" ? [.png] : [.jpeg]
        if panel.runModal() == .OK, let url = panel.url {
            try? imgData.write(to: url)
        }
    }
}

struct BatchMetadataEditor: View {
    let selected: Set<URL>
    @Binding var fileItems: [FileMetadata]
    var onApply: () -> Void
    var applyTags: (FileMetadata) -> Void

    @State private var title = ""; @State private var artist = ""; @State private var album = ""
    @State private var albumArtist = ""; @State private var track = ""; @State private var genre = ""
    @State private var yearRecorded = ""; @State private var comment = ""
    @State private var artwork: NSImage? = nil; @State private var showCoverPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Editing \(selected.count) files").font(.headline)
            Group {
                TextField("Title (blank to skip)", text: $title).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Artist (blank to skip)", text: $artist).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Album (blank to skip)", text: $album).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Album Artist (blank to skip)", text: $albumArtist).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Track (blank to skip)", text: $track).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Genre (blank to skip)", text: $genre).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Year (blank to skip)", text: $yearRecorded).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Comment (blank to skip)", text: $comment).textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Group {
                if let img = artwork {
                    Image(nsImage: img).resizable().scaledToFit().frame(width: 200, height: 200).cornerRadius(8).padding(.vertical, 8).frame(maxWidth: .infinity)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.windowBackgroundColor)).frame(width: 200, height: 200)
                        Image(systemName: "music.note").font(.system(size: 64)).foregroundColor(.secondary.opacity(0.3))
                    }.padding(.vertical, 8).frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 12) {
                Spacer()
                Button("Edit Artwork") { showCoverPicker = true }.buttonStyle(.bordered)
                Button("Apply to All") { applyBatchTags(); onApply() }.buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding(.top, 16)
        .fileImporter(isPresented: $showCoverPicker, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let picked = urls.first, let ns = NSImage(contentsOf: picked) { artwork = ns }
        }
    }

    private func applyBatchTags() {
        for url in selected {
            if let idx = fileItems.firstIndex(where: { $0.url == url }) {
                if !title.isEmpty { fileItems[idx].title = title }; if !artist.isEmpty { fileItems[idx].artist = artist }
                if !album.isEmpty { fileItems[idx].album = album }; if !albumArtist.isEmpty { fileItems[idx].albumArtist = albumArtist }
                if !track.isEmpty { fileItems[idx].track = track }; if !genre.isEmpty { fileItems[idx].genre = genre }
                if !yearRecorded.isEmpty { fileItems[idx].yearRecorded = yearRecorded }; if !comment.isEmpty { fileItems[idx].comment = comment }
                if let img = artwork {
                    fileItems[idx].artwork = img
                    let tmpJ = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
                    if let jpeg = img.toJPEGData() { try? jpeg.write(to: tmpJ); fileItems[idx].artworkURL = tmpJ }
                }
                applyTags(fileItems[idx])
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
