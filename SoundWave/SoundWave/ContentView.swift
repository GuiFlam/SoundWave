import SwiftUI
import AVFoundation
import MediaPlayer

struct SongMetadata: Identifiable {
    let id = UUID()
    let fileName: String
    let title: String
    let artist: String
    let artwork: UIImage?
}

struct ContentView: View {
    @State private var audioPlayer: AVAudioPlayer?
    @State private var selectedFile: URL?
    @State private var savedSongs: [SongMetadata] = []
    @State private var currentSong: SongMetadata?
    @State private var isPlayerExpanded = false
    @State private var playbackTime: Double = 0
    @State private var isPlaying = false
    @State private var seekToTime: Double = 0

    var body: some View {
        VStack {
            if isPlayerExpanded {
                PlayerView(
                    isExpanded: $isPlayerExpanded,
                    song: $currentSong,
                    audioPlayer: $audioPlayer,
                    isPlaying: $isPlaying
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3))
                .gesture(DragGesture()
                    .onChanged { value in
                        if value.translation.height > 50 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPlayerExpanded = false
                            }
                        }
                    })
            } else {
                // Minimized view
                Button(action: {
                    
                    selectedFile = nil // Reset selected file before opening picker
                                    UIApplication.shared.windows.first?.rootViewController?.present(
                                        UIHostingController(rootView: DocumentPicker(selectedFile: $selectedFile)), animated: true)
                }, label: {
                    Text("Add a song")
                })
                List {
                    ForEach(savedSongs) { song in
                        if song.fileName != "temp.mp3" {
                            Button(action: {
                                if let data = fetchMP3File(fileName: song.fileName) {
                                    audioPlayer?.stop()
                                    playMP3(data: data)
                                    currentSong = song
                                    isPlaying = true
                                }
                            }) {
                                HStack {
                                    if let artwork = song.artwork {
                                        Image(uiImage: artwork)
                                            .resizable()
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                    } else {
                                        Image(systemName: "music.note")
                                            .resizable()
                                            .frame(width: 50, height: 50)
                                    }
                                    VStack(alignment: .leading) {
                                        Text(song.title)
                                            .font(.headline)
                                        Text(song.artist)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteSongs)
                }
                
                HStack {
                    if let song = currentSong {
                        if let artwork = song.artwork {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        } else {
                            Image(systemName: "music.note")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                        }
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                            Text(song.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No song playing")
                    }
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPlayerExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isPlayerExpanded ? "chevron.down" : "chevron.up")
                            .padding()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .shadow(radius: 5)
            }
        }
        .onAppear {
            configureAudioSession()
            savedSongs = fetchAllSavedSongs()
            if let player = audioPlayer {
                playbackTime = player.currentTime
                isPlaying = player.isPlaying
            }
        }
        .onChange(of: selectedFile) { newValue in
            if let url = newValue {
                importMP3File(from: url)
            }
        }
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func deleteSongs(at offsets: IndexSet) {
        for index in offsets {
            let fileName = savedSongs[index].fileName
            let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
            do {
                try FileManager.default.removeItem(at: fileURL)
                savedSongs.remove(at: index)
            } catch {
                print("Error deleting file: \(error)")
            }
        }
    }

    func fetchAllSavedSongs() -> [SongMetadata] {
        var songs: [SongMetadata] = []
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil)
            let mp3Files = fileURLs.filter { $0.pathExtension == "mp3" }

            for fileURL in mp3Files {
                let fileName = fileURL.lastPathComponent
                let metadata = extractMetadata(from: fileURL)
                let song = SongMetadata(
                    fileName: fileName,
                    title: metadata.title,
                    artist: metadata.artist,
                    artwork: metadata.artwork != nil ? UIImage(data: metadata.artwork!) : nil
                )
                songs.append(song)
            }
        } catch {
            print("Error fetching saved songs: \(error)")
        }
        return songs
    }

    func saveMP3File(data: Data, fileName: String) {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            print("File saved: \(fileURL)")
        } catch {
            print("Error saving file: \(error)")
        }
    }

    func fetchMP3File(fileName: String) -> Data? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let data = try Data(contentsOf: fileURL)
            return data
        } catch {
            print("Error fetching file: \(error)")
            return nil
        }
    }

    func playMP3(data: Data) {
        do {
            // Initialize AVAudioPlayer
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            // Save data to temporary file
            let tempURL = getDocumentsDirectory().appendingPathComponent("temp.mp3")
            try data.write(to: tempURL)
            
            // Extract metadata
            let metadata = extractMetadata(from: tempURL)
            
            // Update now playing info with metadata
            updateNowPlayingInfo(metadata: metadata)
            
            // Setup remote command center
            setupRemoteCommandCenter()
        } catch {
            print("Error playing MP3: \(error)")
        }
    }

    func extractMetadata(from url: URL) -> (title: String, artist: String, album: String, artwork: Data?) {
        let asset = AVAsset(url: url)
        var title: String = "Unknown Title"
        var artist: String = "Unknown Artist"
        var album: String = "Unknown Album"
        var artwork: Data? = nil

        for item in asset.commonMetadata {
            if item.commonKey == .commonKeyTitle {
                title = item.stringValue ?? "Unknown Title"
            } else if item.commonKey == .commonKeyArtist {
                artist = item.stringValue ?? "Unknown Artist"
            } else if item.commonKey == .commonKeyAlbumName {
                album = item.stringValue ?? "Unknown Album"
            } else if item.commonKey == .commonKeyArtwork, let data = item.dataValue {
                artwork = data
            }
        }

        return (title, artist, album, artwork)
    }

    func importMP3File(from url: URL) {
        do {
            // Start accessing the security-scoped resource.
            guard url.startAccessingSecurityScopedResource() else {
                print("Error: Couldn't access security scoped resource")
                return
            }
            
            defer {
                // Stop accessing the security-scoped resource.
                url.stopAccessingSecurityScopedResource()
            }
            
            let data = try Data(contentsOf: url)
            saveMP3File(data: data, fileName: url.lastPathComponent)
        } catch {
            print("Error importing file: \(error)")
        }
    }

    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [self] event in
            self.audioPlayer?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [self] event in
            self.audioPlayer?.pause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [self] event in
            self.playNextTrack()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [self] event in
            self.restartCurrentTrack()
            return .success
        }
    }

    func updateNowPlayingInfo(metadata: (title: String, artist: String, album: String, artwork: Data?)) {
           var nowPlayingInfo: [String: Any] = [
               MPMediaItemPropertyTitle: metadata.title,
               MPMediaItemPropertyArtist: metadata.artist,
               MPMediaItemPropertyAlbumTitle: metadata.album,
               MPMediaItemPropertyPlaybackDuration: audioPlayer?.duration ?? 0,
               MPNowPlayingInfoPropertyElapsedPlaybackTime: audioPlayer?.currentTime ?? 0
           ]

           if let artworkData = metadata.artwork, let image = UIImage(data: artworkData) {
               let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                   return image
               }
               nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
           }

           MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
       }

    func restartCurrentTrack() {
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
        isPlaying = true
    }

    func playNextTrack() {
        // Implement play next track functionality
    }
}
