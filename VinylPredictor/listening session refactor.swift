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
    
    @StateObject private var userCollection: AlbumCollectionModel = AlbumCollectionModel()
    @EnvironmentObject var Shazam: ShazamViewModel
    
    @State private var tracklistHistory: [DetectedSong] = []
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                
                NowPlaying()
                    .padding([.top, .leading, .trailing])
                
                songHistoryList
                
                Spacer()
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .navigationBarTitle("Listening Session")
        }
        .environment(userCollection)
        .onAppear(perform: loadUserCollection)
    }
    
    // MARK: - Components
    @ViewBuilder
    private var songHistoryList: some View {
        List {
            Group {
                if tracklistHistory.isEmpty {
                    emptyHistoryView
                } else {
                    ForEach(tracklistHistory) { song in
                        songRow(for: song)
                    }
                    .onDelete(perform: deleteSong)
                    .onChange(of: Shazam.detectedSongs) {
                        withAnimation {
                            updateTracklistHistory()
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) {
            topListGradient
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(alignment: .leading) {
            Text("No Previous Songs...")
                .bold()
                .foregroundStyle(.primary)
            
            Text("As you spin new tracks, as they get recognised, they'll appear here!")
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private func songRow(for song: DetectedSong) -> some View {
        VStack(alignment: .leading) {
            Text(song.appleMusic.title) // the current song as detected by Shazam
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(song.album_title()) // gets the correct album title based on the users collection
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .transition(.identity)
    }
    
    private var topListGradient: some View { // makes sure the list doesn't cut off at the top
        Rectangle()
            .foregroundStyle(Gradient(colors: [.black, .clear]))
            .frame(height: 30)
    }
    
    // MARK: - Methods
    private func deleteSong(at offsets: IndexSet) {
        Shazam.detectedSongs.remove(atOffsets: offsets)
    }
    
    private func updateTracklistHistory() {
        var updatedList = Shazam.detectedSongs
        _ = updatedList.popLast() // Remove the last element (now playing)
        tracklistHistory = updatedList.reversed()
    }
    
    private func loadUserCollection() {
        Task {
            if case .success(let collection) = await fetchCollection() {
                userCollection.array = collection
                Shazam.userCollection = collection
                print("loading user collection finished \(userCollection.array.count)")
                userCollection.loading = false
            }
        }
    }
}

// MARK: - NowPlaying View
struct NowPlaying: View {
    
    @EnvironmentObject var Shazam: ShazamViewModel
    
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
    private let timerInterval: TimeInterval = 0.03
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
//
//// MARK: - Preview
//#Preview {
//    let shazamViewModel = ShazamViewModel()
//    return Listening_Session()
//        .environmentObject(shazamViewModel)
//}
