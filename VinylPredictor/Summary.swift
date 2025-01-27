//
//  Summary.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 03/11/2024.
//

import SwiftUI
import MarqueeText

struct Summary: View {

    @EnvironmentObject var userCollection: AlbumCollectionModel

    // Array containing tuples of album and listening time
    @State var albumData: [(Album, Int)] = []
    
    @State var total_time: Int?
    @State var artists_distinct: (Int, Int)? // (total albums, distinct artists)
    @State var top_artist: (String, Int)? // Top artist and listening time in minutes
    @State var top_genres: [(String, Int)]? // Top genres and their listening times

    var body: some View {
        NavigationView {
            VStack {
                // If the total listening time is less than 30 minutes, don't show anything to stop it from breaking
                if computeTotalTimeListened(from: albumData) < 1800 {
                    VStack {
                        Spacer()
                        Text("Summary only available when listening time is over 30 minutes")
                            .multilineTextAlignment(.center)
                            .font(.title)
                            .fontWeight(.light)
                            .padding(.vertical)
                        Spacer()
                    }
                } else {
                    // continue only if all computations are available
                    if let total_time = total_time,
                       let artists_distinct = artists_distinct,
                       let top_artist = top_artist,
                       let top_genres = top_genres {
                        
                        TopArtistBox(top_artist: top_artist)
                        
                        HStack(alignment: .top) {
                            VStack {
                                if let topAlbum = getTopAlbum(from: albumData) {
                                    TopAlbumBox(album: topAlbum.0, seconds: topAlbum.1)
                                }
                                
                                TotalCollection(artists_distinct: artists_distinct)
                                
                                RecommendationPageLink()
                            }
                            VStack {
                                TotalListening(total_seconds: total_time, albumData: albumData)
                                
                                if let unlovedAlbum = getUnlovedAlbum(from: albumData) {
                                    LowAlbumBox(album: unlovedAlbum.0)
                                }
                                
                                FavouriteGenreBox(top_genres: top_genres)
                            }
                        }
                    } else {
                        // Show spinner while data is loading
                        VStack {
                            Spacer()
                            ProgressView().scaleEffect(2)
                            Spacer()
                        }
                    }
                    Spacer()
                }
            }
            .padding()
            .onAppear {
                albumData = prepareAlbumData(from: userCollection)
                print(albumData)
                
                total_time = computeTotalTimeListened(from: albumData)
                artists_distinct = computeTotalAlbumsDistinctArtists(from: albumData)
                top_artist = computeTopArtistMinutes(from: albumData)
                top_genres = computeTopGenres(from: albumData)
            }
        }
    }
    
    func prepareAlbumData(from collection: AlbumCollectionModel) -> [(Album, Int)] {
        // Map over the enumerated collection to create an array of tuples
        return collection.array.enumerated().map { (index, album) in
            let time = collection.listened_to_seconds[index] // Get the listening time for the current album
            return (album, time) // Create a tuple for each album containing the album and its listening time
        }
    }

    func computeTotalTimeListened(from preparedData: [(Album, Int)] = []) -> Int {
        // Sum the listening time from all albums in the albumData array
        return preparedData.reduce(0) { $0 + $1.1 }
        // $0 is the running total
        // $1.1 [(album, time), therefore 1] is the listening time of the current album
    }

    func computeTopArtistMinutes(from preparedData: [(Album, Int)] = []) -> (String, Int)? {
        // Compute the total listening time for each artist
        var artistListeningTime: [String: Int] = [:] // Dictionary to store artist name with their cumulative listening times
        for (album, time) in preparedData {
            let artist = album.artist
            artistListeningTime[artist, default: 0] += time // Add the listening time to the corresponding artist
        }
        
        // Find the artist with the highest cumulative listening time
        if let topArtist = artistListeningTime.max(by: { $0.value < $1.value }) {
            return (topArtist.key, topArtist.value / 60) // Return the artist name and their total time in minutes
        }
        
        return nil // fallback
    }

    func computeTotalAlbumsDistinctArtists(from preparedData: [(Album, Int)] = []) -> (Int, Int) {
        // Compute the total number of albums and the total number of distinct artists
        
        let totalAlbums = preparedData.count // Count the total number of albums
        let uniqueArtists = Set(preparedData.map { $0.0.artist }) // Set means only one of each element therefore, unique
        let totalArtists = uniqueArtists.count // Count the number of unique artists
        
        return (totalAlbums, totalArtists) // Return the total number of albums and distinct artists
    }

    func computeTopGenres(from preparedData: [(Album, Int)] = []) -> [(String, Int)] {
        // Compute the total listening time for each genre
        var styleTimes: [String: Int] = [:] // Dictionary to store genres and their cumulative listening times
        
        for (album, time) in preparedData {
            for style in album.styles { // Iterate through all genres (styles) of the current album
                styleTimes[style, default: 0] += time // Add the listening time to the corresponding genre
            }
        }
        
        // Convert the dictionary to a sorted array of tuples, sorted by listening time in descending order
        return styleTimes.sorted { $0.value > $1.value }
    }

    func getTopAlbum(from preparedData: [(Album, Int)] = []) -> (Album, Int)? {
        // Find the album with the highest listening time
        return preparedData.max(by: { $0.1 < $1.1 }) // Return the album and its listening time
    }

    func getUnlovedAlbum(from preparedData: [(Album, Int)] = []) -> (Album, Int)? {
        // Find the album with the lowest listening time
        return preparedData.min(by: { $0.1 < $1.1 }) // Return the album and its listening time
    }
}

//#Preview {
//    TopArtistBox(top_artist: ("Fred Again..", 100))
//}

struct TopAlbumBox: View {
    
    let album: Album
    let seconds: Int
    
    var body: some View {
        
        NavigationLink(destination:
            AlbumDetail(
                accessed_via_collection_search: false,
                selectedAlbumID: album.id
            )
        ) {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background.secondary)
                .frame(maxWidth: .infinity, maxHeight: 250)
            
                .overlay {
                    VStack {
                        Text("Top Album")
                            .font(.title2)
                            .bold()
                        
                        Spacer()
                        
                        pictureAsyncFetch(url: album.cover_image_URL)
                            .frame(width: 125, height: 125)
                            .overlay {
                                ZStack {
                                    Rectangle()
                                        .foregroundStyle(.background.tertiary)
                                        .opacity(0.5)
                                    
                                    VStack {
                                        Text(String(format: "%.1f", Double(seconds) / 3600))
                                            .bold()
                                            .font(.largeTitle)
                                            .foregroundStyle(.secondary)
                                        Text("Hours")
                                            .fontWeight(.light)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Spacer()
    //
    //                    Text(album.title)
    //                        .font(.headline)
    //                    Text(album.artist)
    //                        .font(.subheadline)
                    }
                    .padding()
                    
                }
        }
        .foregroundStyle(.primary)
    }
}

struct TopArtistBox: View {
    
    let top_artist: (String, Int)
    @State var picture: URL?
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background.secondary)
            .frame(maxWidth: .infinity, maxHeight: 125)
            .overlay(alignment: .leading)
        {
                HStack {
                    pictureAsyncFetch(url: picture)
                        .frame(width: 125, height: 125)
                        .background(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading) {
                        Text("Top Artist")
                            .font(.title3)
                        
                        Spacer()
                        
                        MarqueeText(
                            text: top_artist.0,
                            font: UIFont.preferredFont(forTextStyle: .title2),
                            leftFade: 0,
                            rightFade: 5,
                            startDelay: 2
                        )
                        .bold()

                        Text("\(top_artist.1) Minutes")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .onAppear {
                Task {
                    let artist_metadata = await AppleMusicFetchArtist(searchTerm: top_artist.0)
                    switch artist_metadata {
                    case .success(let artist):
                        
                        picture = artist.artwork?.url(width: 500, height: 500)
                    case .failure(let error):
                        print("Error fetching artist metadata: \(error)")
                    }
                }
            }
    }
}

struct LowAlbumBox: View {
    
    let album: Album
    
    var body: some View {
        NavigationLink(destination:
            AlbumDetail(
                accessed_via_collection_search: false,
                selectedAlbumID: album.id
           )
        ) {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background.secondary)
                .frame(maxWidth: .infinity, maxHeight: 250)
            
                .overlay {
                    VStack {
                        Text("Unloved 💔")
                            .font(.title2)
                            .bold()
                        
                        Spacer()
                        
                        pictureAsyncFetch(url: album.cover_image_URL)
                            .frame(width: 125, height: 125)
                            .overlay {
                                ZStack {
                                    Rectangle()
                                        .foregroundStyle(.background.tertiary)
                                        .opacity(0.5)
                                    
                                    VStack {
                                        Text("Listened to the least")
                                            .multilineTextAlignment(.center)
                                            .italic()
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Spacer()

    //                    Text(album.title)
    //                        .font(.headline)
    //                    Text(album.artist)
    //                        .font(.subheadline)
                    }
                    .padding()
                    
                }
        }
        .foregroundStyle(.primary)
    }
}

struct TotalListening: View {
    
    let total_seconds: Int
    let albumData: [(Album, Int)] // Album and listening time
    
    var body: some View {
        let time = formatSecondsToTime(seconds: total_seconds)
        
        NavigationLink(destination: DetailedAlbumListView(albumData: albumData)) {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background.secondary)
                .frame(maxWidth: .infinity, maxHeight: 175)
                .overlay {
                    VStack {
                        Text("Total Time")
                            .font(.title2)
                            .bold()
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("\(time.hours) Hours")
                                .font(.title2)
                            Text("\(time.minutes) Minutes")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .fontWeight(.light)
                            Text("\(time.seconds) Seconds")
                                .font(.headline)
                                .fontWeight(.ultraLight)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                        Spacer()
                    }
                    .padding()
                }
        }
        .foregroundStyle(.primary)
    }
    
    func formatSecondsToTime(seconds: Int) -> (hours: Int, minutes: Int, seconds: Int) {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        return (hours, minutes, remainingSeconds)
    }
}

struct DetailedAlbumListView: View {
    let albumData: [(Album, Int)] // Album and listening time

    var body: some View {
        List {
            
            ForEach(listenedAlbums(), id: \.0.id) { album, time in
                HStack {
                    
                    VStack(alignment: .leading) {
                        Text(album.title)
                            .font(.headline)
                        Text(album.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(formatSecondsToReadableTime(seconds: time))")
                            .bold()
                            .foregroundColor(.clear)
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .teal, .green]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .mask(
                                Text("\(formatSecondsToReadableTime(seconds: time))")
                                    .bold()
                            )
                    }
                    
                    Spacer()
                    Spacer()
                    
                    pictureAsyncFetch(url: album.cover_image_URL)
                        .frame(width: 90, height: 90)
                        .background(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    
                }
                .padding(.vertical)
            }
            
            if hasUnlistenedAlbums() {
                Section(header: Text("Unlistened Albums")) {
                    ForEach(unlistenedAlbums(), id: \.0.id) { album, _ in
                        VStack(alignment: .leading) {
                            Text(album.title)
                                .font(.headline)
                            Text(album.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func hasUnlistenedAlbums() -> Bool {
        return albumData.contains { $0.1 == 0 }
    }
    
    func unlistenedAlbums() -> [(Album, Int)] {
        return albumData.filter { $0.1 == 0 }
    }
    
    func listenedAlbums() -> [(Album, Int)] {
        return albumData.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
    }
    
    func formatSecondsToReadableTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60

        if hours > 0 {
            // Show hours and minutes only if listening time exceeds an hour
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
}



struct FavouriteGenreBox: View {
    
    let top_genres: [(String, Int)]
    
    var body: some View {
        
        NavigationLink(destination:
            listGenres(top_genres: top_genres)
        ) {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background.secondary)
                .frame(maxWidth: .infinity, maxHeight: 130)
            
                .overlay {
                    VStack {
                        Text("Top Genre")
                            .font(.title2)
                            .bold()
                        
                        Spacer()
                        
                        VStack {
                            Text(top_genres.first!.0)
                                .font(.headline)
                                .bold()
                            
                            let percentage = calculateTopGenrePercentage(from: top_genres)
                            
                            Text("\(percentage)% of total")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fontWeight(.light)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
        }
        .foregroundStyle(.primary)
    }
}

struct listGenres: View {
    
    let top_genres: [(String, Int)]
    
    var body: some View {
        
        List {
            Text("As a percentage of time listened...")
                .font(.headline)
                .foregroundStyle(.secondary)
                .italic()
            
            ForEach(top_genres.filter({ $0.1 > 0 }), id: \.0) { genre in
                row(genre: genre)
            }
            
            Section(header: Text("Unplayed genres from your collection")) {
                ForEach(top_genres.filter({ $0.1 == 0 }), id: \.0) { genre in
                    row(genre: genre)
                }
            }
        }
        .navigationTitle("Top Genres")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func row(genre: (String, Int)) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(genre.0)")
                    .font(.headline)
                    .bold()
                
                let minutes = Int(ceil(Double(genre.1) / 60))
                
                Text("\(minutes) minutes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            let percentage = calculateTopGenrePercentage(
                from: top_genres,
                specific: genre
            )
            
            
            Text("\(percentage) %")
                .bold()
                .foregroundColor(.clear)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .teal, .green]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    Text("\(percentage) %")
                        .bold
                )
        }
    }
}

func calculateTopGenrePercentage(from genres: [(String, Int)], specific: (String, Int)? = nil) -> Int {
    guard let first = genres.first else { return 0 }
    
    var elemSeconds: Double
    elemSeconds = Double(first.1) // assume just top value
    
    if let specific = specific {
        elemSeconds = Double(specific.1)
    }
    
    let totalSeconds = Double(genres.reduce(0) { $0 + $1.1 })
    
    guard totalSeconds > 0 else { return 0 } // avoid division by zero
    
    let percentage = Int(ceil((elemSeconds / totalSeconds) * 100))
    
    return percentage
}

struct RecommendationPageLink: View {
    
    var body: some View {
        
        NavigationLink(destination:
            Recommendations()
        ) {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.background.secondary)
                .frame(maxWidth: .infinity, maxHeight: 175)
            
                .overlay {
                    VStack {
                        Text("What's New")
                            .font(.title2)
                            .bold()
                        
                        Spacer()
                        
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 45))
                            .foregroundStyle(.yellow)
                        
                        Spacer()
                        
                        Text("Tap to for album recommendations!")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
        }
        .foregroundStyle(.primary)
    }
}

struct TotalCollection: View {
    
    let artists_distinct: (Int, Int)
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.background.secondary)
            .frame(maxWidth: .infinity, maxHeight: 130)
        
            .overlay {
                VStack {
                    Text("Collection")
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    VStack {
                        Text("\(artists_distinct.0) Vinyls")
                            .font(.title2)
                        Text("w/ \(artists_distinct.1) distinct artists")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fontWeight(.light)
                    }
                    
                    Spacer()
                }
                .padding()
            }
    }
}
