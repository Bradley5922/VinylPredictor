//
//  UserSearch.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 08/12/2024.
//

import SwiftUI

struct UserSearch: View {
    
    @EnvironmentObject var current_user_profile_metadata: ProfileMetadata
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
                listProfileMetadata(staredProfiles: $staredProfiles)
            }
        }
        .onAppear() {
            Task {
                let fetchedStaredProfiles = await fetchStaredProfiles()
                
                switch fetchedStaredProfiles {
                case .success(let profiles):
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
    
    @EnvironmentObject var current_user_profile_metadata: ProfileMetadata
    
    @State var searchText: String = ""
    @State var results: [ProfileMetadataModel] = []
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
                    // No search text and no stared users
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
                    // Default case: We have at least some stared users or search results
                    Section(header: Text("Stared Users")) {
                        itterator(results: staredProfiles)
                    }
                    
                    Section(header: Text("Search Results")) {
//                        if !results.isEmpty {
//                            Text("Search for users with the box above...")
//                                .foregroundStyle(.secondary)
//                                .font(.title2)
//                                .fontWeight(.light)
//                                .italic()
//                                .listRowBackground(Color.red.opacity(0.5))
//                                
//                        }
                        
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
        .offset(y:-10) // weird gap
        
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }
}

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

struct searchedUserProfile: View {
    
    @EnvironmentObject var current_user_profile_metadata: ProfileMetadata
    
    let user_profile_metadata: ProfileMetadataModel
    @State var stared_user: Bool = false
    
    @State var user_collection: [Album] = []

    var emailPrefix: String {
        let email = user_profile_metadata.email.capitalized
        let atIndex = email.firstIndex(of: "@")
        
        return String(email[..<atIndex!])
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
                    VStack {
                        HStack {
                            Text("\(emailPrefix)'s Vinyl Collection")
                                .font(.headline)
                            
                            Spacer()
                            
                            if user_profile_metadata.public_collection {
                                NavigationLink(destination: showDetailsCollection(user_collection: user_collection)) {
                                    Text("Show Detail")
                                        .font(.headline)
                                }
                            }
                        }
                        
                        Profile_Collection(
                            user_profile_metadata: user_profile_metadata,
                            user_collection: $user_collection
                        )
                    }
                    .padding(.vertical)
                    
                    VStack {
                        HStack {
                            Text("\(emailPrefix)'s Listening Statistics")
                                .font(.headline)
                            
                            Spacer()
                        }
                        
                        Profile_Statistics(
                            user_profile_metadata: user_profile_metadata
                        )
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
                            await current_user_profile_metadata.updateProfileMetadata(singular_stared_profile: user_profile_metadata.user_id)
                        }
                    } label: {
                        Image(systemName: stared_user ? "star.fill" : "star")
                            .tint(.yellow)
                    }
                }
            }
            .onAppear() {
                print(current_user_profile_metadata.starred_users)
                print(user_profile_metadata.user_id)
                stared_user = current_user_profile_metadata.starred_users.contains(user_profile_metadata.user_id)
            }
        }
    }
}

struct Profile_Statistics: View {
    
    let user_profile_metadata: ProfileMetadataModel
    @State var user_listening_statistics: TopListeningStats?
    
    var body: some View {
        if let user_listening_statistics = user_listening_statistics {
            VStack() {
                HStack(spacing: 20) {
                    pictureAsyncFetch()
                        .frame(width: 100, height: 100)
                        .background(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading) {
                        Text("Top Artist")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(user_listening_statistics.topArtists.first?.name ?? "Artist Name")
                            .font(.title)
                            .bold()
                        Text("Lorem Ipsum dolor sit amet.")
                            .lineLimit(1)
                            .font(.subheadline)
                            .fontWeight(.light)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
                
                HStack(spacing: 20) {
                    pictureAsyncFetch()
                        .frame(width: 100, height: 100)
                        .background(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading) {
                        Text("Top Album")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(user_listening_statistics.topAlbums.first?.name ?? "Album Name")
                            .font(.title)
                            .bold()
                        Text("Artist Name")
                            .font(.subheadline)
                            .fontWeight(.light)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
                
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
        } else {
            VStack {
                if !user_profile_metadata.public_statistics {
                    Text("Statistics Is Not Public")
                        .fontWeight(.ultraLight)
                        .font(.title)
                } else {
                    // user listening stats is public, fetch it
                    ProgressView()
                        .scaleEffect(2)
                    
                        .onAppear() {
                            Task {
                                print("Getting User listening stats")
                                
                                let result_listening_statistics = await fetchUserListeningStats(passed_user_id: user_profile_metadata.user_id)
                                
                                switch result_listening_statistics {
                                case .success(let user_listening_statistics):
                                    print("user listening stats fetched: \(user_listening_statistics)")
                                    
                                    self.user_listening_statistics = user_listening_statistics
                                case .failure(let error):
                                    print(error)
                                }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
        }
    }
}

struct Profile_Collection: View {
    
    let user_profile_metadata: ProfileMetadataModel
    @Binding var user_collection: [Album]
    
    var body: some View {
        if !user_collection.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(user_collection, id: \.self) { album in
                        VStack {
                            pictureAsyncFetch(url: album.cover_image_URL)
                                .frame(width: 100, height: 100)
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
        } else {
            VStack {
                if !user_profile_metadata.public_collection {
                    Text("Collection Is Not Public")
                        .fontWeight(.ultraLight)
                        .font(.title)
                } else {
                    // user collection is public, fetch their collection
                    ProgressView()
                        .scaleEffect(2)
                    
                        .onAppear() {
                            Task {
                                let result_user_collection = await fetchCollection(passed_user_id: user_profile_metadata.user_id)
                                
                                switch result_user_collection {
                                case .success(let user_collection):
                                    self.user_collection = user_collection
                                case .failure(let error):
                                    print(error)
                                }
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding()
            
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.background.secondary)
            }
        }
    }
}

struct showDetailsCollection: View {
    
    let user_collection: [Album]
    
    var body: some View {
        List {
            ForEach(user_collection) { album in
                NavigationLink(destination:
                    AlbumDetail(
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

//#Preview {
//    @Previewable @State var sampleCollection: [Album] = []
//    
//    sampleCollection = [Album(]
//    
//    showDetailsCollection(user_collection: sampleCollection)
//}

//#Preview {
//    let mockProfileMetadata = ProfileMetadata()
//    
//    return searchedUserProfile(
//        user_profile_metadata: ProfileMetadataModel(
//            user_id: UUID(uuidString: "25892d4c-a156-4117-9276-b41e1e0df939")!,
//            email: "bradley5922@icloud.com",
//            public_collection: true,
//            public_statistics: true,
//            profile_picture_url: URL(string: "https://gravatar.com/avatar/2ea0945bac17413ffe90364d2fbd4a7d?s=400&d=robohash&r=x")
//        )
//    )
//    .environmentObject(mockProfileMetadata)
//}
