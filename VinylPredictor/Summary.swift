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
    
    @State var top_album: (Album, Int)?
    @State var unloved_album: (Album, Int)?
    
    @State var total_time: Int?
    
    @State var artists_distinct: (Int, Int)? // (total, distinct)
    @State var top_artist: (String, Int)?
    
    @State var top_genres: [(String, Int)]?
    
    // TODO: make it so if total listen time is under 30 mins, can't make summary
    // TODO: when click artist give description from Apple Music
    
    var body: some View {
        NavigationView {
            
            VStack {
                if computeTotalTimeListened(from: userCollection) < 1800 {
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
                    
                    // make sure data has been loaded and computed
                    
                    if let top_album = top_album,
                       let unloved_album = unloved_album,
                       let total_time = total_time,
                       let artists_distinct = artists_distinct,
                       let top_artist = top_artist,
                       let top_genres = top_genres
                    {
                        
                        TopArtistBox(top_artist: top_artist)
                        
                        HStack(alignment: .top) {
                            VStack {
                                TopAlbumBox(album: top_album.0, seconds: top_album.1)
                                TotalCollection(artists_distinct: artists_distinct)
                                RecommendationPageLink()
                            }
                            VStack {
                                TotalListening(total_seconds: total_time)
                                LowAlbumBox(album: unloved_album.0)
                                FavouriteGenreBox(top_genres: top_genres)
                            }
                        }
                        
                    } else {
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
            
            .onAppear() {

                if let top_X = computeTopAndUnlovedAlbums(from: userCollection) {
                    let loved = top_X.0
                    let unloved = top_X.1
                    
                    top_album = (loved.0, loved.1)
                    unloved_album = (unloved.0, unloved.1)
                }
                
                total_time = computeTotalTimeListened(from: userCollection)
                artists_distinct = computeTotalAlbumsDistinctArtists(from: userCollection)
                top_artist = computeTopArtistMinutes(from: userCollection)
                
                top_genres = computeTopGenres(from: userCollection)
                print(top_genres ?? "Error: top genre is nil")
            }
//            .onDisappear() {
//                top_album = nil
//                unloved_album = nil
//                
//                total_time = nil
//                artists_distinct = nil
//                top_artist = nil
//                top_genres = nil
//            }
        }
    }
    
    func computeTopAndUnlovedAlbums(from collection: AlbumCollectionModel) -> ((Album, Int), (Album, Int))? {
        if let maxIndex = collection.listened_to_seconds.enumerated().max(by: { $0.element < $1.element })?.offset,
           let minIndex = collection.listened_to_seconds.enumerated().min(by: { $0.element < $1.element })?.offset {
            
            let top_album = collection.array[maxIndex]
            let top_time = collection.listened_to_seconds[maxIndex]
            
            let unloved_album = collection.array[minIndex]
            let unloved_time = collection.listened_to_seconds[minIndex]
            
            return ((top_album, top_time), (unloved_album, unloved_time))
        }
        return nil
    }
    
    func computeTotalTimeListened(from collection: AlbumCollectionModel) -> Int {
        return collection.listened_to_seconds.reduce(0, +)
    }
    
    func computeTopArtistMinutes(from collection: AlbumCollectionModel) -> (String, Int)? {
        var artistListeningTime: [String: Int] = [:]
        
        for (index, album) in collection.array.enumerated() {
            let artist = album.artist
            let time = collection.listened_to_seconds[index]
            
            artistListeningTime[artist, default: 0] += time
        }
        
        if let topArtist = artistListeningTime.max(by: { $0.value < $1.value }) {
            return (topArtist.key, topArtist.value / 60)
        }
        return nil
    }
    
    func computeTotalAlbumsDistinctArtists(from collection: AlbumCollectionModel) -> (Int, Int) {
        let totalAlbums = collection.array.count
        let uniqueArtists = Set(collection.array.map(\.artist))
        let totalArtists = uniqueArtists.count
        
        return (totalAlbums, totalArtists)
    }
    
    func computeTopGenres(from collection: AlbumCollectionModel) -> [(String, Int)] {
        var styleTimes: [String: Int] = [:]

        // Go through all albums in the users collection
        for (index, album) in collection.array.enumerated() {
            // Get the listening time for said album
            let time = collection.listened_to_seconds[index]
            
            // For each style (sub-genre in Discogs) in said  album, add the listening time
            for style in album.styles {
                styleTimes[style, default: 0] += time
            }
        }

        // Convert the dictionary to an array and sort by most-listened
        let sortedStyles = styleTimes.sorted { $0.value > $1.value }

        return sortedStyles
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

    var body: some View {
        let time = formatSecondsToTime(seconds: total_seconds)
        
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
    
    func formatSecondsToTime(seconds: Int) -> (hours: Int, minutes: Int, seconds: Int) {
        
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        return (hours, minutes, remainingSeconds)
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
            Text("Coming Soon")
            .font(.title)
            .bold()
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
