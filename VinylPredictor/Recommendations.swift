//
//  Recommendations.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 19/01/2025.
//

import SwiftUI
import YouTubeKit
import AVFoundation
import Supabase

struct ColorPair: Equatable {
    let start: Color
    let end: Color
}

//#Preview {
//    Recommendations()
//}

struct Recommendations: View {
    
    @State private var hideTabBar = false
    @State private var navigateToStarred = false
    
    @State private var updated_at: String = "in the past"
    @State var artist_recs: [[discogsRelease]]? = []
    
    @State private var tabColours: [ColorPair] = []
    
    @State private var showAlert: Bool = false
    @State private var computeButtonDisabled: Bool = false
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            if let artist_recs = artist_recs {
                
                if artist_recs.isEmpty {
                    loadingView
                } else {
                    recommendationsTabView(artist_recs: artist_recs)
                    
                    
                    NavigationLink(
                        destination: starredAlbumsList(),
                        isActive: $navigateToStarred
                    ) {
                        EmptyView()
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    recommendationsFooter(update_at: updated_at)
                }
            } else {
                rotatingDiskVariants(colourPair: ColorPair(start: .red, end: .orange))
                
                Text("No recommendations, check back soon!")
                    .font(.title)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding()
                    .multilineTextAlignment(.center)
                
                Divider()
                    .padding()
                
                Button {
                    Task {
                        showAlert = true
                        await call_recommendations_edge_function()
                        handleButtonState(buttonPressed: true)
                        
                    }
                } label: {
                    Text(computeButtonDisabled ? "Computing..." :"Compute Recommendations Now")
                }
                .disabled(computeButtonDisabled)
                
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Recalculating Recommendations"),
                        message: Text("Please come back to this page later to see the results!"),
                        dismissButton: .default(Text("Got it!"))
                    )
                }
                
                .buttonStyle(.bordered)
                .foregroundStyle(.primary)
                .tint(.blue)
                .font(.title2)
                
                Spacer()
                
                Spacer()
            }
        }
        
        .navigationTitle("Recommendations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(hideTabBar ? .hidden : .automatic, for: .tabBar)
        
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        navigateToStarred = true
                    } label: {
                        Label("Starred", systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    // --------------------------------------------------------------
                    Button {
                        Task {
                            showAlert = true
                            await call_recommendations_edge_function()
                            handleButtonState(buttonPressed: true)
                        }
                    } label: {
                        Label("Recalculate Recommendations", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(computeButtonDisabled)
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("Recalculating Recommendations"),
                            message: Text("Please come back to this page later to see the results!"),
                            dismissButton: .default(Text("Got it!"))
                        )
                    }
                } label: {
                    Label("", systemImage: "ellipsis.circle")
                }
            }
        }
        
        .task {
            artist_recs = await fetch_and_organise_recommendations()
        }
        
         
        .onAppear {
            handleButtonState(buttonPressed: false)
            hideTabBar = true
        }
        .onDisappear {
            hideTabBar = false
        }
    }
    
    private func handleButtonState(buttonPressed: Bool = false) {
        let now = Date()
        let userDefaultsKey = "computeButtonPressTime"

        if let lastPress = UserDefaults.standard.object(forKey: userDefaultsKey) as? Date {
            let timeSinceLastPress = now.timeIntervalSince(lastPress)

            // Disable the button if less than 30 minutes have passed
            computeButtonDisabled = timeSinceLastPress < 30 * 60 // 30 minutes in seconds

            // If the button is being pressed and it's allowed, update the timestamp
            if buttonPressed && !computeButtonDisabled {
                UserDefaults.standard.set(now, forKey: userDefaultsKey)
                computeButtonDisabled = true
            }
        } else {
            // No previous press exists
            computeButtonDisabled = false

            // If the button is being pressed, set the timestamp
            if buttonPressed {
                UserDefaults.standard.set(now, forKey: userDefaultsKey)
                computeButtonDisabled = true
            }
        }
    }
    
    private func fetch_and_organise_recommendations() async -> [[discogsRelease]]? {
        
        switch await fetchRecommendations() {
            
        case .success(let recs_metadata):
            updated_at = recs_metadata.updated_at
            
            let artist_ids = recs_metadata.recommendations
            var all_possible_recs = [[discogsRelease]](repeating: [], count: artist_ids.count)
            
            for (i, artist_id) in artist_ids.enumerated() {
                
                let result = await discogsFetchArtistReleases(id: artist_id)
                
                switch result {
                case .success(let releases):
                    all_possible_recs[i] = releases
                case .failure(let error):
                    print("Failed to fetch releases for artist \(artist_id): \(error)")
                }
            }
            
            return all_possible_recs
            
        case .failure(let error):
            print(error)
            
            return nil
        }
    }
    
    private var loadingView: some View {
        ProgressView()
            .scaleEffect(3)
            .padding(.bottom, 200)
    }
    
    private func recommendationsTabView(artist_recs: [[discogsRelease]]) -> some View {
        TabView {
            ForEach(artist_recs.indices, id: \.self) { i in
                if i < tabColours.count,
                   let topRec = artist_recs[i].first {
                    
                    NavigationLink(
                        destination: detailRecommendationView(rec: topRec)
                    ) {
                        artistRecommendationView(topRec: topRec, colourPair: tabColours[i])
                    }
                    .foregroundStyle(.primary)
                    
                } else {
                    
                    Text("Error: Unable to load the artist recommendation!")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                    
                }
            }
        }
        .tabViewStyle(.page)
        .onAppear {
            setupTabColours(artist_recs: artist_recs)
        }
    }
    
    private func recommendationsFooter(update_at: String) -> some View {
        VStack(alignment: .leading) {
            Divider()
            
            Text("Behind each record there can be **multiple songs you can preview** from the album and artist recommended to you...\n")
                .font(.title3)
            
            Text("Last Updated: **\(formatShortDate(from: update_at))**")
                .font(.title3)
                .italic()
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    func formatShortDate(from isoDateString: String) -> String {
        
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        inputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = inputFormatter.date(from: isoDateString) else {
            return "Invalid date"
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .short
        outputFormatter.timeStyle = .none
        
        return outputFormatter.string(from: date)
    }
    
    private func artistRecommendationView(topRec: discogsRelease, colourPair: ColorPair) -> some View {
        VStack {
            rotatingDiskVariants(colourPair: colourPair)
                .padding(50)
            
            Text(topRec.artist_name)
                .font(.title)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .bold()
        }
        .padding(.bottom, 110)
    }

    
    private func setupTabColours(artist_recs: [[discogsRelease]]) {
        guard tabColours.count != artist_recs.count else { return }
        
        let possiblePairs: [ColorPair] = [
            ColorPair(start: .red, end: .orange),
            ColorPair(start: .blue, end: .green),
            ColorPair(start: .purple, end: .pink),
            ColorPair(start: .yellow, end: .mint),
            ColorPair(start: .indigo, end: .teal)
        ]
        
        tabColours = (0..<artist_recs.count).map { _ in
            possiblePairs.randomElement() ?? ColorPair(start: .red, end: .orange)
        }
    }

}

struct starredAlbumsList: View {
    
    @State private var starredAlbumsIDs: [Int] = []
    
    var body: some View {
        VStack {
            Text("\(starredAlbumsIDs)")
            
            List {
//                ForEach(starredAlbumsIDs, id: \.self) { id in
//                    Text(id)
//                }
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        
        .task {
            starredAlbumsIDs = await fetchStarredAlbums()
        }
    }
}

struct rotatingDiskVariants: View {
    
    let colourPair: ColorPair
    
    @State private var isDiskRotating = false
    
    var body: some View {
        ZStack {
            Image("Disk")
                .shadow(radius: 10)
            
            Circle()
                .foregroundStyle(
                    Gradient(colors: [colourPair.start, colourPair.end])
                )
                .frame(width: 108, height: 108)
            
            Circle()
                .frame(width: 10, height: 10)
        }
        .rotationEffect(Angle.degrees(isDiskRotating ? 360 : 0))
        .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: isDiskRotating)
        
        .onAppear {
            isDiskRotating = true
        }
    }
}

struct detailRecommendationView: View {
    
    // The discogs release passed from the Recommendations view
    @State var rec: discogsRelease
    
    // State variables for album data and related states
    @State private var album: Album?
    @State private var starredAlbums: [Int] = []
    @State private var isLoadingAlbum = false
    @State private var albumErrorMessage: String?
    
    @State private var isLoadingStream = false
    @State private var streamErrorMessage: String?
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    @State private var selectedVideoIndex: Int = 0
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Album details or loading/error indicators
            if isLoadingAlbum {
                ProgressView("Loading album details…")
                    .scaleEffect(1.5)
            } else if let albumError = albumErrorMessage {
                Text(albumError)
                    .foregroundColor(.red)
                    .padding()
                    .multilineTextAlignment(.center)
            } else if let album = album {
                ScrollView {
                    VStack(spacing: 20) {
                        // Album Cover
                        pictureAsyncFetch(url: album.cover_image_URL)
                            .frame(width: 350, height: 350)
                            .cornerRadius(12)
                        // Album Title and Artist
                        albumDetailsView(album: album)
                        
                        // Swipeable Audio Previews
                        audioPreviewsSection(album: album)
                        
                        // Album Genres
                        genresSection(album: album)
                    }
                    .padding()
                }
            } else {
                Text("No album data available.")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .navigationTitle("Recommendation")
        .navigationBarTitleDisplayMode(.inline)

        
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let album = album {
                        Task { await toggleStarredAlbum(album_id: album.id) }
                    }
                } label: {
                    let stared = starredAlbums.contains(where: { $0 == album?.id })
                    
                    Image(systemName: stared ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                }
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        
        .task {
            starredAlbums = await fetchStarredAlbums()
            await fetchAlbum()
        }
        .onDisappear {
            // Stop playback when view is dismissed
            pause()
            player = nil
        }
    }
    
    func toggleStarredAlbum(album_id: Int) async {
        
        if starredAlbums.contains(album_id) {
            // Remove the album if it already exists
            starredAlbums.removeAll { $0 == album_id }
            print("Album removed from starred list")
        } else {
            // Add the album if it doesn't exist
            starredAlbums.append(album_id)
            print("Album added to starred list")
        }

        // Update the database
        do {
            let user_id = supabase.auth.currentUser?.id
            
            // Update the `starred_recs` column in Supabase
            try await supabase
                .from("user_matrices")
                .update([
                    "starred_recs": starredAlbums
                ])
                .eq("user_id", value: user_id)
                .execute()

            print("Successfully updated starred albums in the database")
        } catch {
            print("Failed to update starred albums: \(error)")
        }
    }
    
    // MARK: - Album Details
    private func albumDetailsView(album: Album) -> some View {
        VStack(spacing: 8) {
            Text(album.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            
            Text(album.artist)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Audio Previews
    private func audioPreviewsSection(album: Album) -> some View {
        VStack {
            if let videoURLs = album.videoURLs, !videoURLs.isEmpty {
                ZStack {
                    // Box Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 350, height: 175)
                        .shadow(radius: 5)
                    
                    // Content inside the box
                    VStack {
                        TabView(selection: $selectedVideoIndex) {
                            ForEach(videoURLs.indices, id: \.self) { index in
                                VStack(spacing: 20) {
                                    Text("Preview \(index + 1) of \(videoURLs.count)")
                                        .font(.headline)
                                    
                                    if isLoadingStream {
                                        HStack(spacing: 16) {
                                            Text("Loading Preview")
                                                .foregroundStyle(.secondary)
                                                .font(.title3)
                                            ProgressView()
                                                .scaleEffect(1.5)
                                        }
                                    } else if let streamError = streamErrorMessage {
                                        Text(streamError)
                                            .foregroundColor(.red)
                                            .padding()
                                    } else {
                                        playbackControls()
                                    }
                                }
                                .tag(index)
                                .padding()
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                        .frame(height: 200)
                        .onChange(of: selectedVideoIndex) {
                            Task {
                                await loadStream(at: selectedVideoIndex)
                            }
                        }
                        .onAppear {
                            // Load the first stream when the TabView appears
                            Task {
                                await loadStream(at: selectedVideoIndex)
                            }
                        }
                    }
                    .padding(.vertical)
                    .offset(y: -22)
                    
                }
            } else {
                // Box for "No audio previews available" message
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 250)
                    .shadow(radius: 5)
                    .overlay(
                        Text("No audio previews available for this album.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Playback Controls
    private func playbackControls() -> some View {
        HStack(spacing: 40) {
            Button(action: play) {
                Label("Play", systemImage: "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPlaying || player == nil)
            
            Button(action: pause) {
                Label("Pause", systemImage: "pause.fill")
                    .font(.title2)
            }
            .buttonStyle(.bordered)
            .disabled(!isPlaying)
        }
    }
    
    // MARK: - Album Genres
    private func genresSection(album: Album) -> some View {
        VStack(spacing: 8) {
            Text("Genre(s) of this album:")
                .font(.headline)
                .bold()
            
            Text(album.styles.joined(separator: ", "))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Fetch Album Data
    private func fetchAlbum() async {
        isLoadingAlbum = true
        albumErrorMessage = nil
        
        let result = await discogsFetch(id: rec.master_id, is_master: true)
        
        switch result {
        case .success(let fetchedAlbum):
            DispatchQueue.main.async {
                self.album = fetchedAlbum
            }
        case .failure(let error):
            DispatchQueue.main.async {
                self.albumErrorMessage = "Failed to load album details: \(error.localizedDescription)"
            }
        }
        
        isLoadingAlbum = false
    }
    
    // MARK: - Load Audio Stream for Selected Preview
    private func loadStream(at index: Int) async {
        guard let album = album, let videoURLs = album.videoURLs, index < videoURLs.count else {
            DispatchQueue.main.async {
                self.streamErrorMessage = "Invalid video URL index."
            }
            return
        }
        
        let videoURL = videoURLs[index]
        
        isLoadingStream = true
        streamErrorMessage = nil
        
        // Pause any existing playback
        pause()
        
        do {
            let streams = try await YouTube(url: videoURL).streams
            if let audioOnlyStream = streams
                .filterAudioOnly()
                .filter({ $0.fileExtension == .m4a })
                .highestAudioBitrateStream() {
                DispatchQueue.main.async {
                    self.player = AVPlayer(url: audioOnlyStream.url)
                    self.isPlaying = false
                }
            } else {
                DispatchQueue.main.async {
                    self.streamErrorMessage = "No audio-only streams found for this preview."
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.streamErrorMessage = "Error fetching stream: \(error.localizedDescription)"
            }
        }
        
        isLoadingStream = false
    }
    
    // MARK: - Playback Controls
    private func play() {
        player?.play()
        isPlaying = true
    }
    
    private func pause() {
        player?.pause()
        isPlaying = false
    }
}

//.onAppear() {
//    Task {
//        switch await fetchRecommendations() {
//        case .success(let recommendations): print(recommendations)
//            
//            artist_ids = recommendations.recommendations
//            
//            for recommendation in recommendations.recommendations {
//                
//                var result = await discogsFetchArtist(id: recommendation)
//                print(result)
//            }
//            
//        case .failure(let error):
//            print(error)
//        }
//    }
//}

//#Preview {
//
//    let mockRelease = discogsRelease(
//        artist_name: "Daft Punk",
//        album_name: "Random Access Memories",
//        type: "master",
//        popularity: 999,
//        master_id: 556257
//    )
//
//    detailRecommendationView(rec: mockRelease)
//}
