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
    /// Array holding other users' metadata for the user's starred profiles.
    @State var staredProfiles: [ProfileMetadata] = []
    
    @State var loading: Bool = false

    var body: some View {
        VStack {
            if loading {
                Spacer()
                
                ProgressView()
                    .scaleEffect(2.5)
                
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
                    current_user_profile_metadata.starred_users = staredProfiles.map { $0.user_id! }
                    
                    loading = false
                case .failure(let error):
                    print(error)
                    staredProfiles = []
                    
                    loading = false
                }
            }
        }
        .navigationTitle("Other Users")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Displays a list of profile metadata, including starred users and search results.
struct listProfileMetadata: View {
    
    @EnvironmentObject var current_user_profile_metadata: ProfileMetadata
    
    @State var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?
    @State var loading_search_results = false
    @State var results: [ProfileMetadata] = []
    
    @State var recommended_users: [ProfileMetadata] = []
    @Binding var staredProfiles: [ProfileMetadata]

    var body: some View {
        List {
            switch (searchText.isEmpty, staredProfiles.isEmpty, results.isEmpty) {
            case (false, _, true):
                if loading_search_results {
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                        .fontWeight(.light)
                        .italic()
                        .listRowBackground(Color.blue.opacity(0.5))
                } else {
                    Text("No results from searching...")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                        .fontWeight(.light)
                        .italic()
                        .listRowBackground(Color.red.opacity(0.5))
                }
            case (true, true, _):
                if recommended_users != [] {
                    Section(header: Text("Recommended Users")) {
                        itterator(results: recommended_users)
                    }
                }
                Section(header: Text("Stared Users")) {
                    VStack(alignment: .leading) {
                        Text("You have no starred users :(")
                            .foregroundStyle(.secondary)
                            .font(.title2)
                        Text("Search for users with the box above...")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                            .fontWeight(.light)
                    }
                    .listRowBackground(Color.yellow.opacity(0.5))
                }
            case (true, false, _):
                Section(header: Text("Stared Users")) {
                    itterator(results: staredProfiles)
                }
                if recommended_users != [] {
                    Section(header: Text("Recommended Users")) {
                        itterator(results: recommended_users)
                    }
                }
            default:
                itterator(results: results)
            }
        }
        .task {
            recommended_users = await fetch_recommended_users()
        }
        .onChange(of: searchText) {
            performSearchDebounced()
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }

    private func performSearchDebounced() {
        searchTask?.cancel()
        searchTask = Task {
            // Debounce for 1 second
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            if query.isEmpty || query.count <= 2 {
                results = []
                return
            }

            results = []

            let fetchSearch = await searchProfiles(searchTerm: query)

            switch fetchSearch {
            case .success(let profiles):
                results = profiles
                loading_search_results = false
            case .failure(let error):
                print(error)
                loading_search_results = false
                results = []
            }
        }
    }

    func fetch_recommended_users() async -> [ProfileMetadata] {
        let cloud_function_URL = "https://user-recs-1087873563961.europe-west1.run.app"
        let user_id = current_user_profile_metadata.user_id!

        let result = await getJSONfromURL(
            URL_string: "\(cloud_function_URL)?user_id=\(user_id)"
        )

        switch result {
        case .success(let json):
            let rec_user_ids: [String] = json.arrayValue.compactMap { $0["user_id"].string?.uppercased() }
            let starred_users_string_array = current_user_profile_metadata.starred_users.map { $0.uuidString }
            let filtered_rec_users = rec_user_ids.filter { !starred_users_string_array.contains($0) }

            do {
                let profiles: [ProfileMetadata] = try await supabase
                    .from("user_metadata")
                    .select()
                    .in("user_id", values: filtered_rec_users)
                    .execute()
                    .value

                return profiles
            } catch {
                print("Error, fetching recommended profiles from Supabase", error)
            }
        case .failure(let error):
            print(error)
        }

        return []
    }
}

/// Iterates over a list of profiles and displays them in the list.
struct itterator: View {
    
    @EnvironmentObject var current_user_profile_metadata: ProfileMetadata
    
    let results: [ProfileMetadata]
    
    var body: some View {
        ForEach(results) { result in
            
            let starred_user  = current_user_profile_metadata.starred_users.contains(result.user_id!)
            
            NavigationLink(destination: searchedUserProfile(user_profile_metadata: result)) {
                
                HStack(spacing: 15) {
                    
                    pictureAsyncFetch(
                        localImage: result.profile_picture,
                        url: result.gravatarURL,
                        profile_picture: true
                    )
                    .frame(width: 80, height: 80)
                    .background(Color.gray)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        
                        HStack(alignment: .center) {
                            Text(result.display_name)
                                .font(.headline)
                                .bold()
                            
                            if starred_user {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.headline)
                            }
                        }
                        
                        Text(result.email ?? "hello@world.com")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
            }
        }
    }
}

/// Displays the profile for a searched user, navigated to from the list.
struct searchedUserProfile: View {
    
    /// Environment object containing metadata about the CURRENTLY logged-in user.
    @EnvironmentObject var current_user_profile_metadata: ProfileMetadata
    
    /// Metadata for the searched user.
    let user_profile_metadata: ProfileMetadata
    
    /// State object to hold the searched user's collection of albums, passed to other views via environment.
    @StateObject var searched_user_collection: AlbumCollectionModel = AlbumCollectionModel()
    
    /// Tracks whether the current user has starred this searched user.
    @State var stared_user: Bool = false
    
    var body: some View {
        ScrollView {
            VStack {
                
                pictureAsyncFetch(
                    localImage: user_profile_metadata.profile_picture,
                    url: user_profile_metadata.gravatarURL,
                    profile_picture: true
                )
                .frame(width: 175, height: 175)
                .background(Color.gray)
                .clipShape(Circle())
                
                Text(user_profile_metadata.display_name)
                    .font(.title)
                    .bold()
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
//                        VStack(alignment: .center) {
//                            Spacer()
//
//                            ProgressView()
//                                .scaleEffect(2)
//                                .padding(.top, 100)
//
//                            Text("This can take a while...")
//                                .font(.title3)
//                                .foregroundStyle(.secondary)
//                                .italic()
//                                .padding()
//
//                            Spacer()
//                        }
                    VStack {
                        HStack {
                            Text("\(user_profile_metadata.display_name)'s Vinyl Collection")
                                .font(.headline)
                            
                            Spacer()
                            
//                                if user_profile_metadata.public_collection {
//                                    NavigationLink(destination: showDetailsCollection()) {
//                                        Text("Show Detail")
//                                            .font(.headline)
//                                    }
//                                }
                        }
                        Profile_Collection(user_profile_metadata: user_profile_metadata)
                    }
                    .padding(.vertical)
                    
                    VStack {
                        HStack {
                            Text("\(user_profile_metadata.display_name)'s Listening Statistics")
                                .font(.headline)
                            Spacer()
                        }

                        Profile_Statistics(user_profile_metadata: user_profile_metadata)
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
                            let updateResult = await current_user_profile_metadata.updateProfileMetadata(
                                singularStarredProfile: user_profile_metadata.user_id
                            )
                            switch updateResult {
                            case .success:
                                print("Starred status updated.")
                            case .failure(let error):
                                print("Failed to update starred status: \(error.localizedDescription)")
                            }
                        }
                    } label: {
                        Image(systemName: stared_user ? "star.fill" : "star")
                            .tint(.yellow)
                    }
                }
            }
            .onAppear {
                
                stared_user = current_user_profile_metadata.starred_users.contains(user_profile_metadata.user_id!)

                Task {
                    do {
                        // Initialise the UI collections if necessary
                        searched_user_collection.array = []
                        searched_user_collection.listened_to_seconds = []
                        
                        // Iterate over each album as it's fetched
                        for try await (album, listenedToSeconds) in fetchCollection(passed_user_id: user_profile_metadata.user_id) {
                            // Update the UI collections on the main thread
                            await MainActor.run {
                                searched_user_collection.array.append(album)
                                searched_user_collection.listened_to_seconds.append(listenedToSeconds)
                            }
                        }
                        
                        // Once all albums are loaded, update the loading state
                        await MainActor.run {
                            searched_user_collection.loading = false
                        }
                    } catch {
                        // Handle any errors that occurred during fetching
                        print("Error fetching collection: \(error.localizedDescription)")
                        
                        await MainActor.run {
                            searched_user_collection.loading = false
                        }
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
    let user_profile_metadata: ProfileMetadata
    
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
            
        } else if albums.isEmpty && (searched_user_collection.loading == false) {

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
                                .clipped()
                                .background(Color.gray)
                                .shadow(radius: 10)
                        }
                    }
                    
                    if searched_user_collection.loading {
                        VStack {
                            ProgressView()
                                .scaleEffect(2)
                        }
                        .padding()
                        .frame(width: 100, height: 100)
                        .background(Color.gray)
                        .shadow(radius: 10)
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
                ForEach(albums, id: \.id) { album in
                    
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
    let user_profile_metadata: ProfileMetadata
    
    @State private var topAlbums: (Album, Int)?
    @State private var topArtistMinutes: (String, Int)?
    
    @State private var artistPicture: URL?
    
    var body: some View {
        let albums = searched_user_collection.array
        
        // Empty or user has less than 30 mins listening history
        if searched_user_collection.loading {
            VStack {
                Spacer()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                Text("Loading Summary")
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
        } else if albums.isEmpty || searched_user_collection.listened_to_seconds.reduce(0, +) < 1800 {
            VStack {
                
                Spacer()
                
                // If no albums in collection, then there is no listening history
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
        } else if !user_profile_metadata.public_statistics {
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
                
                if let top_album = topAlbums { // Will show data after computed, using the `searched_user_collection`
                    
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
                
                if let top_artist = topArtistMinutes { // Will show data after computed, using the `searched_user_collection`
                    
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
        let prepared_stats = Summary().prepareAlbumData(from: searched_user_collection)
        
        self.topAlbums = Summary().getTopAlbum(from: prepared_stats)
        self.topArtistMinutes = Summary().computeTopArtistMinutes(from: prepared_stats)
    }
}
