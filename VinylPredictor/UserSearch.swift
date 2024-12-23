//
//  UserSearch.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 08/12/2024.
//

import SwiftUI
import MarqueeText

struct UserSearch: View {
    
    /// Environment object containing metadata about the currently logged-in user.
    @EnvironmentObject var current_user_profile_metadata: ProfileMetadata
    /// Array holding (other users) metadata for the  user's starred profiles.
    @State var staredProfiles: [ProfileMetadataModel] = []
    
    @State var loading: Bool = false

    var body: some View {
        VStack {
            if loading {
                Spacer()
                
                ProgressView()
                    .scaleEffect(2)
                
                Spacer()
            } else {
                // Displays the list of fetched or starred profiles if any
                listProfileMetadata(staredProfiles: $staredProfiles)
            }
        }
        .onAppear {
            Task {
                let fetchedStaredProfiles = await fetchStaredProfiles()
                
                switch fetchedStaredProfiles {
                case .success(let profiles):
                    // Update the local array and environment object with the starred users' IDs.
                    staredProfiles = profiles
                    current_user_profile_metadata.starred_users = staredProfiles.map { $0.user_id }
                    
                    loading = false
                case .failure(let error):
                    print(error)
                    staredProfiles = []
                    loading = false
                }
            }
        }
        .navigationTitle("User Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct listProfileMetadata: View {
    
    /// Environment object containing metadata about the currently logged-in user.
    @EnvironmentObject var current_user_profile_metadata: ProfileMetadata
    
    @State var searchText: String = ""
    @State var results: [ProfileMetadataModel] = [] // result of searching profiles
    
    // all the stared profiles, from the previous view
    @Binding var staredProfiles: [ProfileMetadataModel]
    
    var body: some View {
        List {
            switch (searchText.isEmpty, staredProfiles.isEmpty, results.isEmpty) {
            case (false, _, true):
                
                // Search text is not empty but results are empty
                Text("No results")
                    .foregroundStyle(.secondary)
                    .font(.title2)
                    .fontWeight(.light)
                    .italic()
                    .listRowBackground(Color.red.opacity(0.5))
                
            case (true, true, _):
                // No search text and no starred users
                
                VStack(alignment: .leading) {
                    Text("You have no stared users :(")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                    
                    Text("Search for users with the box above...")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                        .fontWeight(.light)
                }
                .listRowBackground(Color.yellow.opacity(0.5))
                
            default:
                // We have at least some starred users or search results
                Section(header: Text("Stared Users")) {
                    itterator(results: staredProfiles)
                }
                
                Section(header: Text("Search Results")) {
                    itterator(results: results)
                }
            }
        }
        .onChange(of: searchText) {
            Task {
                let fetchSearch = await searchProfiles(searchTerm: searchText)
                
                switch fetchSearch {
                case .success(let profiles):
                    results = profiles
                case .failure(let error):
                    print(error)
                    results = []
                }
            }
        }
        .offset(y: -10) // weird gap in the layout fix
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }
}

/// Used in the list list to show profiles
struct itterator: View {
    
    let results: [ProfileMetadataModel]
    
    var body: some View {
        ForEach(results) { result in
            
            NavigationLink(destination: searchedUserProfile(user_profile_metadata: result)) {
                
                HStack(spacing: 15) {
                    
                    pictureAsyncFetch(
                        url: result.profile_picture_url ?? result.gravatar_url,
                        profile_picture: true
                    )
                    .frame(width: 80, height: 80)
                    .background(Color.gray)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        
                        Text(result.email)
                            .font(.headline)
                            .bold()
                        
                        Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
            }
        }
    }
}

/// Displays the profile for a searched user, navigated to from the list
struct searchedUserProfile: View {
    
    /// Environment object containing metadata about the CURRENTLY logged-in user.
    @EnvironmentObject var current_user_profile_metadata: ProfileMetadata
    
    /// Metadata for the searched user
    let user_profile_metadata: ProfileMetadataModel
    
    /// State object to hold the searched user's collection of albums, passed to other views via environment
    @StateObject var searched_user_collection: AlbumCollectionModel = AlbumCollectionModel()
    
    /// Tracks whether the current user has starred this searched user.
    @State var stared_user: Bool = false

    /// Fake username, created via using start of email
    var emailPrefix: String {
        let email = user_profile_metadata.email.capitalized
        let atIndex = email.firstIndex(of: "@")!
        return String(email[..<atIndex])
    }
    
    var body: some View {
        ScrollView {
            VStack {
                
                pictureAsyncFetch(
                    url: user_profile_metadata.profile_picture_url ?? user_profile_metadata.gravatar_url,
                    profile_picture: true
                )
                .frame(width: 175, height: 175)
                .background(Color.gray)
                .clipShape(Circle())
                
                Text(emailPrefix)
                    .font(.title)
                    .bold()
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    if searched_user_collection.loading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(2)
                        Spacer()
                    } else {
                        VStack {
                            HStack {
                                Text("\(emailPrefix)'s Vinyl Collection")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if user_profile_metadata.public_collection {
                                    NavigationLink(destination: showDetailsCollection()) {
                                        Text("Show Detail")
                                            .font(.headline)
                                    }
                                }
                            }
                            Profile_Collection(user_profile_metadata: user_profile_metadata)
                        }
                        .padding(.vertical)
                        
                        VStack {
                            HStack {
                                Text("\(emailPrefix)'s Listening Statistics")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            Profile_Statistics(user_profile_metadata: user_profile_metadata)
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        stared_user.toggle()
                        Task {
                            await current_user_profile_metadata.updateProfileMetadata(
                                singular_stared_profile: user_profile_metadata.user_id
                            )
                        }
                    } label: {
                        Image(systemName: stared_user ? "star.fill" : "star")
                            .tint(.yellow)
                    }
                }
            }
            .onAppear {
                print(current_user_profile_metadata.starred_users)
                print(user_profile_metadata.user_id)
                stared_user = current_user_profile_metadata.starred_users.contains(user_profile_metadata.user_id)
                
                Task {
                    if case .success(let collection) = await fetchCollection(passed_user_id: user_profile_metadata.user_id) {
                        let albums = collection.map { $0.0 }
                        searched_user_collection.array = albums
                        searched_user_collection.listened_to_seconds = collection.map { $0.1 }
                        
                        searched_user_collection.loading = false
                    }
                }
            }
            // Inject the searched user's album collection into this environment
            .environmentObject(searched_user_collection)
        }
    }
}

/// A compact horizontally scrolling view of the user's public album collection.
struct Profile_Collection: View {
    
    /// Metadata for the user whose collection is being displayed.
    let user_profile_metadata: ProfileMetadataModel
    
    /// Environment object for the searched user's collection data.
    @EnvironmentObject var searched_user_collection: AlbumCollectionModel
    
    var body: some View {
        let albums = searched_user_collection.array
        
        if !user_profile_metadata.public_collection {
            
            VStack {
                
                Text("Collection Is Not Public")
                    .fontWeight(.ultraLight)
                    .font(.title)
                
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
            
        } else if albums.isEmpty {

            VStack {
                
                Text("No Items In Collection")
                    .fontWeight(.ultraLight)
                    .font(.title)
                
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
            
        } else {

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    
                    ForEach(albums, id: \.self) { album in
                        VStack {
                            pictureAsyncFetch(url: album.cover_image_URL)
                                .frame(width: 100, height: 100)
                                .background(Color.gray)
                                .shadow(radius: 10)
                        }
                    }
                    
                }
                .padding()
            }
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
        }
    }
}

struct showDetailsCollection: View {
    
    /// Environment object for the searched user's album collection.
    @EnvironmentObject var searched_user_collection: AlbumCollectionModel
    
    var body: some View {
        let albums = searched_user_collection.array
        
        if albums.isEmpty {
            VStack {
                
                Spacer()
                
                Text("No Items In Collection")
                    .fontWeight(.ultraLight)
                    .font(.title)
                
                Spacer()
            }
        } else {
            List {
                ForEach(albums) { album in
                    
                    NavigationLink(
                        destination: AlbumDetail(
                            accessed_via_collection_search: false,
                            selectedAlbumID: album.id
                        )
                        .toolbar(.hidden, for: .tabBar)
                    ) {
                        HStack(spacing: 20) {
                            
                            pictureAsyncFetch(url: album.cover_image_URL)
                                .frame(width: 60, height: 60)
                                .shadow(radius: 10)
                            
                            VStack(alignment: .leading) {
                                Text(album.title)
                                    .font(.headline)
                                Text(album.artist)
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct Profile_Statistics: View {
    
    /// Environment object for the searched user's album collection.
    @EnvironmentObject var searched_user_collection: AlbumCollectionModel
    
    /// Metadata for the user whose collection is being displayed.
    let user_profile_metadata: ProfileMetadataModel
    
    @State private var topAlbums: (Album, Int)?
    @State private var topArtistMinutes: (String, Int)?
    
    @State private var artistPicture: URL?
    
    var body: some View {
        let albums = searched_user_collection.array
        
        // empty or user has less than 30 mins listening history
        if albums.isEmpty || searched_user_collection.listened_to_seconds.reduce(0, +) < 1800   {
            VStack {
                
                Spacer()
                
                // if no albums in collection, then there is no listening history
                Text("No Listening History")
                    .fontWeight(.ultraLight)
                    .font(.title)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
        }  else if !user_profile_metadata.public_statistics {
            VStack {
                
                Spacer()
                
                Text("Listening History Private")
                    .fontWeight(.ultraLight)
                    .font(.title)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
        } else {
            
            VStack {
                
                if let top_album = topAlbums { /// will show data after computed, using the `searched_user_collection`
                    
                    HStack(alignment: .center, spacing: 20) {
                        pictureAsyncFetch(url: top_album.0.cover_image_URL)
                            .frame(width: 100, height: 100)
                            .background(Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading) {
                            Spacer()
                            
                            Text("Top Album")
                                .font(.headline)
                            
                            Spacer()
                            
                            MarqueeText(
                                text: top_album.0.title,
                                font: UIFont.preferredFont(forTextStyle: .headline),
                                leftFade: 0,
                                rightFade: 5,
                                startDelay: 2
                            )
                            .bold()
                            
                            Text("\(top_album.1 / 60) mins listened")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                }
                
                if let top_artist = topArtistMinutes { /// will show data after computed, using the `searched_user_collection`
                    
                    HStack(spacing: 20) {
                        
                        pictureAsyncFetch(url: artistPicture)
                            .frame(width: 100, height: 100)
                            .background(Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading) {
                            Spacer()
                            
                            Text("Top Artist")
                                .font(.headline)
                            
                            Spacer()
                            
                            MarqueeText(
                                text: top_artist.0,
                                font: UIFont.preferredFont(forTextStyle: .headline),
                                leftFade: 0,
                                rightFade: 5,
                                startDelay: 2
                            )
                            .bold()
                            
                            Text("\(top_artist.1) mins listened")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    .onAppear {
                        Task {
                            let artist_metadata = await AppleMusicFetchArtist(searchTerm: top_artist.0)
                            switch artist_metadata {
                            case .success(let artist):
                                print(artist)
                                artistPicture = artist.artwork?.url(width: 110, height: 110)
                            case .failure(let error):
                                print("Error fetching artist metadata: \(error)")
                            }
                        }
                    }
                }
            }
            .onAppear {
                loadStatistics()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
        }
        
    }
    
    /// Loads and computes top album/artist statistics for the current user.
    private func loadStatistics() {
        self.topAlbums = Summary().computeTopAndUnlovedAlbums(from: searched_user_collection)?.0
        self.topArtistMinutes = Summary().computeTopArtistMinutes(from: searched_user_collection)
    }
}
