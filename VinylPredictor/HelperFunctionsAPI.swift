//
//  HelperFunctions.swift
//  BurnFM-iOS (from another app of mine)
//
//  Created by Bradley Cable on 22/09/2024.
//  Amended on 27/10/2024

import SwiftyJSON
import Foundation
import SwiftUI

func getJSONfromURL(URL_string: String) async -> Result<JSON, Error> {
    
    guard let url = URL(string: URL_string) else {
        return .failure(NSError(domain: "Invalid URL", code: 0))
    }
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSON(data: data)
        return .success(json)
    } catch {
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
    
    private var cover_image_URL: String?
    
    var image: some View {
        
        Group {
            if let validImagePath = cover_image_URL {
                AsyncImage(url: URL(string: validImagePath)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                    case .failure:
                        emptyImageView()
                    case .empty:
                        emptyImageView()
                    @unknown default:
                        emptyImageView()
                    }
                }
            } else {
                emptyImageView()
            }
        }
    }
    
    func trimTitle(title: String) -> String {
        let trimmedTitle = title.count > 32 ? String(title.prefix(32)) + "..." : title
        
        return trimmedTitle
    }

    init(json: JSON, full_data: Bool) {
        
        self.full_data = full_data
        
        if full_data { // data from Masters Endpoint
            self.id = json["id"].intValue
            self.title = json["title"].stringValue
            self.artist = json["artists"][0]["name"].stringValue
            self.release_year = json["year"].stringValue
            self.styles = json["styles"].arrayValue.map { $0.stringValue }
            self.cover_image_URL = json["images"][0]["uri"].string
            
            var tempTracklist: [Track] = []
            
            for track in json["tracklist"].arrayValue {
                tempTracklist.append(
                    Track(position: track["position"].stringValue, title: track["title"].stringValue)
                )
            }
            
            self.trackList = tempTracklist
            
        } else { // data from search endpoint
            self.id = json["id"].intValue
            self.title = json["title"].stringValue
            
            // Separate artist and title from the title string, API response: "Artist - Title"
            let (artist, title) = separatedTitle(from: self.title)
            self.artist = artist.isEmpty ? "Unknown Artist" : artist
            self.title = title.isEmpty ? "Unknown Title" : title
            
            self.release_year = json["year"].stringValue
            self.styles = json["style"].arrayValue.map { $0.stringValue }
            self.cover_image_URL = json["cover_image"].string
        }
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

func searchDiscogs(searchTerm: String) async -> Result<[Album], Error> {
    let response = await getJSONfromURL(URL_string:
                    "https://api.discogs.com/database/search?q=\(searchTerm)&type=master&format=album&per_page=10&key=\(DISCOGS_API_KEY)&secret=\(DISCOGS_API_SECRET)"
    )
    
    var searchResults: [Album] = []
    
    switch response {
    case .success(let json):
        for index in json["results"].arrayValue {

            searchResults.append(Album(json: index, full_data: false))
        }
        
        return .success(searchResults)

    case .failure(let error):
        return .failure(error)
    }
    
}

func discogsFetch(id: Int) async -> Result<Album, Error> {
    let response = await getJSONfromURL(URL_string:
        "https://api.discogs.com/masters/\(id)?key=\(DISCOGS_API_KEY)&secret=\(DISCOGS_API_SECRET)"
    )
    
    switch response {
    case .success(let json):
        return .success(Album(json: json, full_data: true))

    case .failure(let error):
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

