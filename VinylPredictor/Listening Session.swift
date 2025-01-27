//
//  Listening Session.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 02/12/2024.
//

import SwiftUI
import MusicKit
import MarqueeText

// MARK: - Listening_Session View
struct Listening_Session: View {
    
    @EnvironmentObject var userCollection: AlbumCollectionModel
    @EnvironmentObject var Shazam: ShazamViewModel
    
    @State private var tracklistHistory: [DetectedSong] = []
    
    @State private var processingTracklistHistory = false
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(alignment: .leading) {
                    
                    NowPlaying()
                        .padding([.top, .leading, .trailing])
                        .padding(.bottom, 4)
                    
                    List {
                        if tracklistHistory.isEmpty {
                            
                            VStack(alignment: .leading) {
                                Text("No Previous Songs...")
                                    .bold()
                                    .foregroundStyle(.primary)
                                Text("As you spin new tracks, as they get recognised, they'll appear here!")
                                    .foregroundStyle(.secondary)
                            }
                            
                        } else {
                            
                            ForEach(tracklistHistory) { song in
                                songRow(song: song)
                            }
                            .onDelete(perform: deleteSong)
                        }
                    }
                    .onChange(of: Shazam.detectedSongs) {
                        withAnimation {
                            updateTracklistHistory()
                        }
                    }
                    
                    .listStyle(.plain)
                    .scrollIndicators(.hidden)
                    
                    .overlay(
                        Rectangle()
                            .foregroundStyle(Gradient(colors: [.black, .clear]))
                            .frame(height: 22),
                        alignment: .top
                    )
                    
                    Spacer()
                }
                .ignoresSafeArea(.all, edges: .bottom)
                .navigationBarTitle("Listening Session")
                .toolbar(processingTracklistHistory ? .hidden: .visible, for: .tabBar)
            }
            .onAppear {
                Shazam.userCollection = userCollection.array
            }
            
            .onChange(of: Shazam.isListening) {
                if !Shazam.isListening && tracklistHistory.count > 0 {
                    processingTracklistHistory = true
                    
                    // added a delay so it doesn't just flash on the screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        processListeningSession()
                    }
                }
            }
            
            if processingTracklistHistory {
                ProcessingOverlay()
            }
        }
        .onAppear() {
            Shazam.userCollection = userCollection.array
        }
    }
    
    private func deleteSong(at offsets: IndexSet) {
        Shazam.detectedSongs.remove(atOffsets: offsets)
    }
    
    private func updateTracklistHistory() {
        tracklistHistory = Shazam.detectedSongs.reversed()
    }
    
    private func processListeningSession() {
        Task {
            print("Updating users listening history")
            Shazam.processBufferedDetections()
            
            var durationByAlbum: [Album: TimeInterval] = [:]
            for song in Shazam.detectedSongs {
                if let album = song.discogsAlbum {
                    durationByAlbum[album, default: 0] += song.appleMusic.duration
                }
            }
            
            print(durationByAlbum.map { "\($0.key.title): \(String(format: "%.2f", $0.value)) seconds" })
            
            for (album, time_listen) in durationByAlbum {
                if case .success(let updated) = await updateListeningHistory(for: album, listening_time_seconds: time_listen) {
                    
                    let updatedIndex = userCollection.array.firstIndex(where: { $0.id == updated.discogs_id })
                    userCollection.listened_to_seconds[updatedIndex ?? 0] = updated.listened_to_seconds ?? 0
                    
                    print("Updated listening history for: \(album.title) - \(time_listen) seconds.")
                }
            }
            
            print("Finished processing durationByAlbum")
            print("Proceed to delete listening session")
            Shazam.clear_session()
            
            // Hide the loading overlay after processing
            DispatchQueue.main.async {
                processingTracklistHistory = false
            }
        }
    }
}


struct ProcessingOverlay: View {
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Processing Listening Session...")
                    .foregroundColor(.white)
                    .bold()
            }
            .padding()
            
            .background(Color.gray.opacity(0.75))
            .cornerRadius(8)
        }
    }
}

struct songRow: View {
    
    @EnvironmentObject var Shazam: ShazamViewModel
    
    let song: DetectedSong
    @State private var showingNoDiscogsAlert = false
    
    @State private var overrideRequired: Bool = false
    @State private var detectedSongOverrideRequired: DetectedSong?
    
    var body: some View {
        HStack {
            SongInfoView(song: song)
            
            Spacer()
            
            if song.discogsAlbum == nil {
                InfoButton(showingAlert: $showingNoDiscogsAlert)
            }
        }
        .foregroundStyle((song.discogsAlbum == nil) ? .orange : .primary)
        .transition(.identity)
        .alert(
            "Album Not Found in Collection",
            isPresented: $showingNoDiscogsAlert
        ) {
            AlertButtons(
                song: song,
                overrideRequired: $overrideRequired,
                detectedSongOverrideRequired: $detectedSongOverrideRequired
            )
        } message: {
            Text("This song has been detected but doesn't seem to match any albums in your collection. This could be a mistake.")
        }
        .sheet(isPresented: $overrideRequired) {
            OverrideSheet(
                song: song,
                overrideRequired: $overrideRequired,
                detectedSongOverrideRequired: $detectedSongOverrideRequired
            )
        }
    }
}

struct SongInfoView: View {
    let song: DetectedSong
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(song.appleMusic.title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(song.album_title())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct InfoButton: View {
    @Binding var showingAlert: Bool
    
    var body: some View {
        Button {
            showingAlert.toggle()
        } label: {
            Image(systemName: "info.circle")
        }
    }
}

struct AlertButtons: View {
    let song: DetectedSong
    @Binding var overrideRequired: Bool
    @Binding var detectedSongOverrideRequired: DetectedSong?
    
    var body: some View {
        Button("Override", role: .destructive) {
            print("Override of song requested")
            detectedSongOverrideRequired = song
            overrideRequired = true
        }
        Button("Got it!", role: .cancel) {}
    }
}

struct OverrideSheet: View {
    @EnvironmentObject var Shazam: ShazamViewModel
    
    var song: DetectedSong
    
    @Binding var overrideRequired: Bool
    @Binding var detectedSongOverrideRequired: DetectedSong?
    
    var body: some View {
        
        NavigationView {
            
            VStack(alignment: .leading) {
                Text("Please select an album from your collection to assign this song to...")
                    .padding(.horizontal)
                
                List(Shazam.userCollection ?? []) { album in
                    Button {
                        updateDetectedSong(album: album)
                        
                        overrideRequired = false
                        detectedSongOverrideRequired = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.title)
                                .font(.headline)
                                .bold()
                            Text(album.artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Override Detection")
        }
    }
    
    private func updateDetectedSong(album: Album) {
        // Locate the song by its ID in Shazam.detectedSongs
        if let index = Shazam.detectedSongs.firstIndex(where: { $0.id == song.id }) {
            Shazam.detectedSongs[index].discogsAlbum = album
        }
    }
}

// MARK: - NowPlaying View
struct NowPlaying: View {
    
    @EnvironmentObject var Shazam: ShazamViewModel
    @State private var showListeningSessionAlert = false
    
    @State private var artworkOffset: CGFloat = 0
    @State private var artworkVisible = false
    
    // Constants
    private let animationDuration = 1.25
    private let artworkFadeDuration = 0.5
    private let artworkSize: CGFloat = 90
    
    var body: some View {
        VStack(spacing: 0) {
            nowPlayingBackground
                .overlay(nowPlayingContent)
            
            listeningToggle
        }
    }
    
    // MARK: - Components
    private var nowPlayingBackground: some View {
        Rectangle()
            .foregroundStyle(.background.secondary)
            .frame(maxWidth: .infinity, maxHeight: 110)
            .clipShape(
                .rect(
                    topLeadingRadius: 8,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 8
                )
            )
    }
    
    @ViewBuilder
    private var nowPlayingContent: some View {
        
        GeometryReader { geometry in
            HStack(alignment: .center) {
                ZStack {
                    SpinningVinyl()
                        .frame(width: artworkSize, height: artworkSize)
                        .offset(x: artworkOffset)
                    
                    pictureAsyncFetch(url: Shazam.nowPlayingSong?.album_artwork())
                        .frame(width: 90, height: 90)
                        .background(Color.gray)
                        .opacity(artworkVisible ? 1: 0)
                        .transition(.opacity) // Add a fade transition when the artwork changes
                }
                .shadow(radius: 8)
                .padding(.trailing, 8)
                
                if Shazam.nowPlayingSong == nil {
                    placeholderText
                } else {
                    nowPlayingText(width: geometry.size.width)
                }
                
                Spacer()
            }
            .padding(10)
            .onChange(of: Shazam.isListening) { animateArtwork() }
            .onChange(of: Shazam.nowPlayingSong) { animateArtwork() }
        }
    
    }

    
    private var placeholderText: some View {
        VStack(alignment: .leading) {
            Text("Waiting for a song...")
                .bold()
                .foregroundStyle(.primary)
            
            Text("Start a session and spin your records! 🕺")
                .foregroundStyle(.secondary)
        }
    }
    
    private func nowPlayingText(width: CGFloat) -> some View {
        
        let song_title = Shazam.nowPlayingSong?.appleMusic.title
        let album_title = Shazam.nowPlayingSong?.album_title()
        
        return VStack(alignment: .leading) {
            MarqueeText(
                text: song_title ?? "-------------",
                font: UIFont.preferredFont(forTextStyle: .body),
                leftFade: 5,
                rightFade: 16,
                startDelay: 3
            )
            .frame(width: width - artworkSize - 30 - artworkOffset, alignment: .leading)
            .bold()
            .foregroundStyle(.primary)
            
            MarqueeText(
                text: album_title ?? "-----------------------",
                font: UIFont.preferredFont(forTextStyle: .body),
                leftFade: 5,
                rightFade: 16,
                startDelay: 3
            )
            .frame(width: width - artworkSize - 30 - artworkOffset, alignment: .leading)
            .foregroundStyle(.secondary)
        }
        .offset(x: artworkOffset)
    }
    
    private var listeningToggle: some View {
        Toggle("Listening Session Active", isOn: $Shazam.isListening)
            .toggleStyle(.switch)
            .tint(.yellow)
            .bold()
            .shadow(radius: 2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green)
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 8,
                    bottomTrailingRadius: 8,
                    topTrailingRadius: 0
                )
            )
            .onChange(of: Shazam.isListening) {
                if Shazam.isListening {
                    showListeningSessionAlert = true
                }
            }
            .alert(isPresented: $showListeningSessionAlert) {
                Alert(
                    title: Text("Listening Session Started"),
                    message: Text("Make sure you have added all the vinyls you have to your collection."),
                    primaryButton: .default(Text("Continue")),
                    secondaryButton: .destructive(Text("Oops, I'll add them now")) {
                        Shazam.isListening = false
                    }
                )
            }
    }
    
    // MARK: - Methods
    private func animateArtwork() {
        if Shazam.isListening && Shazam.nowPlayingSong != nil {
            withAnimation(.easeInOut(duration: animationDuration)) {
                artworkOffset = 35
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: artworkFadeDuration)) {
                    artworkVisible = true
                }
            }
        } else {
            withAnimation(.easeInOut(duration: artworkFadeDuration)) {
                artworkVisible = false
            }
            withAnimation(.easeInOut(duration: animationDuration)) {
                artworkOffset = 0
            }
        }
    }
}

// MARK: - SpinningVinyl View
struct SpinningVinyl: View {
    
    @EnvironmentObject var Shazam: ShazamViewModel
    
    @State private var rotationAngle: Double = 0.0
    @State private var isAnimating = false
    
    // Constants
    private let rotationIncrement = 2.0
    private let timerInterval: TimeInterval = 0.05
    private let additionalSpin: Double = 150
    
    var body: some View {
        Image("Disk")
            .resizable()
            .rotationEffect(Angle.degrees(rotationAngle))
            .onChange(of: Shazam.isListening) {
                Shazam.isListening ? startRotating() : stopRotating()
            }
            .onAppear {
                if Shazam.isListening {
                    startRotating()
                }
            }
    }
    
    // MARK: - Methods
    private func startRotating() {
        isAnimating = true
        Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { timer in
            if isAnimating {
                rotationAngle += rotationIncrement
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func stopRotating() {
        isAnimating = false
        let targetAngle = rotationAngle + additionalSpin
        
        Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { timer in
            let remainingAngle = targetAngle - rotationAngle
            if rotationAngle < targetAngle {
                let increment = min(rotationIncrement, remainingAngle / 10)
                rotationAngle += increment
            } else {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    // Sample test data
    let sampleSongs: [DetectedSong] = [
        DetectedSong(
            id: UUID(),
            artist: "Artist 1",
            title: "Song Title 1",
            album: "Album Title 1",
            duration: 210,
            artworkURL: URL(string: "https://via.placeholder.com/300")!
        ),
        DetectedSong(
            id: UUID(),
            artist: "Artist 2",
            title: "Song Title 2",
            album: "Album Title 2",
            duration: 180,
            artworkURL: URL(string: "https://via.placeholder.com/300")!
        )
    ]
    
    // Mock ViewModel with sample data
    let shazamViewModel = ShazamViewModel()

    // Listening session with pre-populated tracklistHistory
    return Listening_Session()
        .environmentObject(AlbumCollectionModel())
        .environmentObject(shazamViewModel)
    
}
