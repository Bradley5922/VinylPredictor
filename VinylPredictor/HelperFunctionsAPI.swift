//
//  HelperFunctions.swift
//  BurnFM-iOS (from another app of mine)
//
//  Created by Bradley Cable on 22/09/2024.
//  Amended on 27/10/2024

import SwiftyJSON
import Foundation
import SwiftUI
import MusicKit

class AlbumCollectionModel: ObservableObject, Observable {
    @Published var  user_id: UUID?
    
    @Published var array: [Album] = []
    @Published var listened_to_seconds: [Int] = []
    
    @Published var loading = true
    
    // Functions to add and remove albums
    func addAlbum(_ album: Album) async {
        
        DispatchQueue.main.async { // UI changes on main thread
            self.array.append(album)
            self.listened_to_seconds.append(0)
        }
        
        let _ = await addToCollection(album: album)
    }
    
    func removeAlbum(_ album: Album) async {
        let indicesToRemove = array.enumerated().compactMap { index, element in
            element.id == album.id ? index : nil
        }

        // Sort indices in descending order, as not to mess with indexes of latter elements
        for index in indicesToRemove.sorted(by: >) {
            
            DispatchQueue.main.async {
                self.array.remove(at: index)
                self.listened_to_seconds.remove(at: index)
            }
        }
        
        let _ = await removeFromCollection(discogs_id: album.id)
    }
    
    func inCollection(_ album: Album) -> Bool {
        return array.contains(where: { $0.id == album.id })
    }
}

// modified from other applications of mine
func getJSONfromURL(URL_string: String, authHeader: String? = nil) async -> Result<JSON, Error> {
    
    guard let url = URL(string: URL_string) else {
        return .failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil))
    }
    
    // Create a URLRequest and set the Authorisation (American spelling boo) header
    var request = URLRequest(url: url)
    
    if let authHeader = authHeader {
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
    }
    
    do {
        // Perform the network request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check the HTTP response status
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let error = NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: nil)
            return .failure(error)
        }
        
        // Parse the JSON data
        let json = try JSON(data: data)
        return .success(json)
        
    } catch {
        // Return any errors that occur during the request or parsing
        return .failure(error)
    }
}

struct emptyImageView: View {
    
    var body: some View {
        
        RoundedRectangle(cornerRadius: 10)
            .foregroundStyle(.gray)
            .overlay {
                Image(systemName: "music.microphone")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
}

struct Track: Hashable {
    var position: String
    var title: String
    
    private var durationValue: Int?
    
    var duration: String? {
        return "00:00"
    }
    
    init(position: String, title: String, durationValue: Int? = nil) {
        self.position = position
        self.title = title
        self.durationValue = durationValue
    }
}

struct Album: Identifiable, Hashable, Comparable {
    // allows sorting by artist
    static func < (lhs: Album, rhs: Album) -> Bool {
        return lhs.artist < rhs.artist
    }
    
    var id: Int
    var full_data: Bool
    
    var title: String
    var artist: String
    
    var release_year: String
    var styles: [String]
    
    var trackList: [Track]?
    
    var cover_image_URL: URL?
    
    var videoURLs: [URL]?

    init(json: JSON, full_data: Bool) {
        
        self.full_data = full_data
        
        if full_data {
            /// PARSING: /releases/{id}
            
            self.id = json["id"].intValue
            self.title = json["title"].stringValue
            
            // For /releases/, primary artist is at [0]
            if let firstArtist = json["artists"].arrayValue.first {
                self.artist = firstArtist["name"].stringValue
            } else {
                self.artist = "Unknown Artist"
            }
            
            self.release_year = json["year"].stringValue
            self.styles = json["styles"].arrayValue.map { $0.stringValue }
            
            if let firstImageURL = json["images"].arrayValue.first?["resource_url"].url {
                self.cover_image_URL = firstImageURL
            } else {
                self.cover_image_URL = nil
            }
            
            let rawTrackList = json["tracklist"].arrayValue
            var tempTracklist: [Track] = []
            for track in rawTrackList {
                tempTracklist.append(
                    Track(
                        position: track["position"].stringValue,
                        title: track["title"].stringValue
                    )
                )
            }
            self.trackList = tempTracklist.isEmpty ? nil : tempTracklist
            
            // useful for masters on the recommendations page
            self.videoURLs = {
                guard let videosArray = json["videos"].array else {
                    return [] // If the `videos` key doesn't exist, return an empty array
                }
                return videosArray.compactMap { video in
                    video["uri"].url
                }
            }()

        } else {
            /// PARSING: /database/search?{...}
            
            self.id = json["id"].intValue
            self.title = json["title"].stringValue
            
            // For searches, "title" is "Artist - Title"
            let (artist, title) = separatedTitle(from: self.title)
            self.artist = artist.isEmpty ? "Unknown Artist" : artist
            self.title = title.isEmpty ? "Unknown Title" : title
            
            self.release_year = json["year"].stringValue
            self.styles = json["style"].arrayValue.map { $0.stringValue }
            
            self.cover_image_URL = json["cover_image"].url
            self.trackList = nil // Not provided in the search response
        }
    }

    func trimTitle(title: String) -> String {
        let trimmedTitle = title.count > 32 ? String(title.prefix(32)) + "..." : title
        return trimmedTitle
    }
}

// Relevant for above `struct`
func separatedTitle(from text: String, separator: String = "-", maxLength: Int? = nil) -> (artist: String, title: String) {
    guard let range = text.range(of: separator) else {
        return (text.trimmingCharacters(in: .whitespaces), "")
    }
    
    let artist = text[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
    var title = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
    
    if let maxLength = maxLength, title.count > maxLength {
        title = String(title.prefix(maxLength)) + "..."
    }
    
    return (artist, title)
}

func searchDiscogs(title: String? = nil, artist: String? = nil, barcode: String? = nil) async -> Result<[Album], Error> {
    // Determine the search query based on the presence of barcode or searchTerm
    let query: String
    if let barcode = barcode {
        query = "barcode=\(barcode)"
    } else if let title = title {
        query = "title=\(title)"
    } else if let artist = artist {
        query = "artist=\(artist)"
    } else {
        return .failure(NSError(domain: "No search term or barcode provided", code: 0, userInfo: nil))
    }
    
    let url1 = "https://api.discogs.com/database/search?\(query)&type=release&format=Album&per_page=50"
    let url2 = "https://api.discogs.com/database/search?\(query)&type=release&format=Vinyl&per_page=50"
    
    // sometimes items are mis-categorised on discogs
    async let response1 = getJSONfromURL(URL_string: url1, authHeader: "Discogs key=\(DISCOGS_API_KEY), secret=\(DISCOGS_API_SECRET)")
    async let response2 = getJSONfromURL(URL_string: url2, authHeader: "Discogs key=\(DISCOGS_API_KEY), secret=\(DISCOGS_API_SECRET)")
    
    // Await both responses
    let (result1, result2) = await (response1, response2)
    
    var searchResults: [Album] = []
    
    // Process the results
    switch (result1, result2) {
    case (.success(let json1), .success(let json2)):
        // Combine results from both responses
        let combinedResults = json1["results"].arrayValue + json2["results"].arrayValue
        
        // Remove duplicates based on album master ID, but keep duplicates if master_id is 0
        let uniqueResults = Array(
            Set(combinedResults.compactMap { $0["master_id"].intValue != 0 ? $0["master_id"].intValue : nil })
        ).compactMap { id in
            combinedResults.first { $0["master_id"].intValue == id }
        } + combinedResults.filter { $0["master_id"].intValue == 0 }
        // Special edition vinyl don't have a master_id (value of 0), as they don't have a related master for example a live version of an album
        
        // Map JSON to Album objects
        searchResults = uniqueResults.map { Album(json: $0, full_data: false) }
        return .success(searchResults)
        
    case (.failure(let error), _), (_, .failure(let error)):
        // Return the first encountered error
        return .failure(error)
    }
}

func discogsFetch(id: Int, is_master: Bool = false) async -> Result<Album, Error> {
    var type: String = "releases"
    if is_master { type = "masters" }
    
    let response = await getJSONfromURL(
        URL_string: "https://api.discogs.com/\(type)/\(id)",
        authHeader: "Discogs  key=\(DISCOGS_API_KEY), secret=\(DISCOGS_API_SECRET)"
    )
    
    switch response {
    case .success(let json):
        return .success(Album(json: json, full_data: true))

    case .failure(let error):
        return .failure(error)
    }
    
}

struct discogsRelease {
    var artist_name: String
    var album_name: String
    
    // used for filtering
    var type: String
    var popularity: Int
    
    // used to get more data if required
    var master_id: Int
}

func discogsFetchArtistReleases(id: Int) async -> Result<[discogsRelease], Error> {

    let response = await getJSONfromURL(
        URL_string: "https://api.discogs.com/artists/\(id)/releases?format=Vinyl&per_page=50",
        authHeader: "Discogs  key=\(DISCOGS_API_KEY), secret=\(DISCOGS_API_SECRET)"
    )
    
    switch response {
        
    case .success(let json):
        let releasesArray = json["releases"].arrayValue
        
        let discogsReleases: [discogsRelease] = releasesArray
            .filter { $0["type"].stringValue == "master" }
            .map { releaseJSON in

            let wants = releaseJSON["stats"]["community"]["in_wantlist"].intValue
            let haves = releaseJSON["stats"]["community"]["in_collection"].intValue
            let popularityScore = wants + haves
            
            return discogsRelease(
                artist_name: releaseJSON["artist"].stringValue,
                album_name: releaseJSON["title"].stringValue,
                type: releaseJSON["type"].stringValue,
                popularity: popularityScore,
                
                master_id: releaseJSON["id"].intValue
            )
        }
        .sorted { $0.popularity > $1.popularity }
        
        return .success(discogsReleases)
        
    case .failure(let error):
        return .failure(error)
    }
}

func AppleMusicFetchAlbums(searchTerm: String) async -> Result<MusicKit.Album, Error> {
    print("Fetching Apple Music album metadata")
    
    do {
        let musicAuthorizationStatus = await MusicAuthorization.request()
        
        if musicAuthorizationStatus != .authorized {
            // required for Shazam to fetch Album to create listening history
            return .failure(NSError(domain: "Authentication required", code: 401, userInfo: nil))
        }
        // Create a search request for albums matching the search term
        var searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [MusicKit.Album.self])
        searchRequest.limit = 10 // Fetch more results to increase chances of finding a full album
                
        // Perform the search
        let response = try await searchRequest.response()
        
        // Filter out singles/EP
        if let album = response.albums.first(where: { $0.isSingle == false }) {
            print("Found full album: \(album)")
            return .success(album)
        } else {
            return .failure(NSError(domain: "No full albums found", code: 404, userInfo: nil))
        }
        
    } catch {
        return .failure(error)
    }
}

func AppleMusicFetchArtist(searchTerm: String) async -> Result<MusicKit.Artist, Error> {
    print("Fetching Apple Music artist metadata")
    
    do {
        // Request Apple Music authorization
        let musicAuthorizationStatus = await MusicAuthorization.request()
        
        if musicAuthorizationStatus != .authorized {
            return .failure(NSError(domain: "Authentication required", code: 401, userInfo: nil))
        }
        
        // Create a search request for artists matching the search term
        var searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [MusicKit.Artist.self])
        searchRequest.limit = 1
        
        // Perform the search
        let response = try await searchRequest.response()
        
        // Get the first artist from the results
        if let artist = response.artists.first {
            print("Found artist: \(artist)")
            return .success(artist)
        } else {
            return .failure(NSError(domain: "No artist found", code: 404, userInfo: nil))
        }
        
    } catch {
        return .failure(error)
    }
}

//struct TesterPage: View {
//
//    @EnvironmentObject private var rootViewSelector: RootViewSelector
//
//    var body: some View {
//        VStack {
//            Button {
//                rootViewSelector.currentRoot = .landing
//            } label: {
//                Text("Return to Main App")
//                    .bold()
//                    .font(.title3)
//            }
//
//            Divider()
//
//            Button {
//                Task {
//                    do {
//                        let result = await searchDiscogs(searchTerm: "The Beatles")
//                        print(try result.get())
//                    } catch {
//                        print(error)
//                    }
//                }
//            } label: {
//                Text("Run Sample Search")
//            }
//        }
//    }
//}
//
//#Preview {
//    CollectionView()
//}

