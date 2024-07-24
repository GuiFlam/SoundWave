import SwiftUI
import AVFoundation
import MediaPlayer

struct PlayerView: View {
    @Binding var isExpanded: Bool
    @Binding var song: SongMetadata?
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var isPlaying: Bool
    @State private var playbackTime: Double = 0
    @State private var seekToTime: Double = 0
    @State private var timer: Timer?
    private let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        VStack {
            if isExpanded {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .padding()
                                .foregroundStyle(.white)
                        }
                    }
                    
                    if let song = song {
                        VStack {
                            if let artwork = song.artwork {
                                Image(uiImage: artwork)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 300)
                                    .padding()
                            } else {
                                Image(systemName: "music.note")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 300)
                                    .padding()
                            }
                            Text(song.title)
                                .font(.largeTitle)
                                .padding(.bottom, 2)
                            Text(song.artist)
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(formatTime(playbackTime))
                                    .font(.subheadline)
                                Spacer()
                                Text(formatTime((audioPlayer?.duration ?? 0) - playbackTime))
                                    .font(.subheadline)
                            }
                            .padding(.horizontal)
                            
                            Slider(value: $playbackTime, in: 0...(audioPlayer?.duration ?? 0), onEditingChanged: { editing in
                                if !editing {
                                    seekToTime = playbackTime
                                    audioPlayer?.currentTime = seekToTime
                                }
                            })
                            .accentColor(.white)
                            .padding()
                            
                            HStack {
                                Button(action: {
                                    // Handle previous track
                                    restartCurrentTrack()
                                }) {
                                    Image(systemName: "backward.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Button(action: {
                                    // Handle play/pause
                                    togglePlayPause()
                                }) {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Button(action: {
                                    // Handle next track
                                    playNextTrack()
                                }) {
                                    Image(systemName: "forward.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding()
                        }
                        .padding()
                    } else {
                        Text("No song playing")
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2))
                .gesture(DragGesture()
                    .onChanged { value in
                        if value.translation.height > 50 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded = false
                            }
                        }
                    })
            } else {
                HStack {
                    if let song = song {
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
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
            if let player = audioPlayer {
                playbackTime = player.currentTime
                isPlaying = player.isPlaying
            }
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    func formatTime(_ time: Double) -> String {
        return formatter.string(from: time) ?? "00:00"
    }
    
    func togglePlayPause() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        isPlaying.toggle()
    }

    func playNextTrack() {
        // Implement play next track functionality
    }

    func restartCurrentTrack() {
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
        isPlaying = true
        playbackTime = 0
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let player = audioPlayer {
                playbackTime = player.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
    }
}
