//
//  MainScreen.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 27/10/2024.
//

// Variable Name System: camelCase

import SwiftUI
import SwiftyJSON
import Combine

struct CollectionView: View {
    
    @EnvironmentObject var userCollection: AlbumCollectionModel
    @StateObject private var barcodeViewData = BarcodeViewDataStorage()
    
    var body: some View {
        
        NavigationStack(path: $barcodeViewData.path) {
            VStack {
                
                if userCollection.loading { // Show loading indicator while collection is loading
                    ProgressView().scaleEffect(2)
                } else {
                    ListViewContent()
                }
                
            }
            .navigationTitle("Collection")
            
            .navigationDestination(for: String.self) { view in
                if view == "DetailAlbumView" {
                    
                    AlbumDetail(selectedAlbumID: barcodeViewData.barcodeScanResult!.id)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
        }
        .environment(barcodeViewData)
    }
}

struct NoAlbumsInfo: View {
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("No albums in collection")
                .font(.title2)
                .foregroundStyle(.primary)
            Text("Search above to add albums")
                .font(.title3)
                .fontWeight(.light)
                .foregroundStyle(.secondary)
        }
    }
}

struct ListViewContent: View {
    
    @EnvironmentObject var userCollection: AlbumCollectionModel
    
    @State var searchText: String = ""
    @State var searchResults: [Album] = []
    
    // used for debouncing
    // last active search Task so we can cancel it if needed
    @State private var searchTask: Task<(), Never>? = nil
    
    var body: some View {
        let sortedCollection = userCollection.array.sorted { $0.title < $1.title }
        
        List {
            barcodeRowView()
            if userCollection.array.isEmpty && searchText.isEmpty {
                NoAlbumsInfo()
                    .listRowBackground(Color.yellow.opacity(0.5))
            }
            
            ForEach(searchText.isEmpty ? sortedCollection : searchResults, id: \.id) { item in
                NavigationLink(destination:
                    AlbumDetail(selectedAlbumID: item.id)
                        .toolbar(.hidden, for: .tabBar)
                ) {
                    rowView(item: item)
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        
        .onChange(of: searchText) {
            // Cancel any pending task
            searchTask?.cancel()
            
            // If user clears text, clear results
            if searchText.isEmpty {
                searchResults = []
                return
            }
            
            // "Debounce" search to only make request when user stops typing
            searchTask = Task {
                // Debounce for 1 seconds
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Boilerplate for debounding
                if Task.isCancelled { return }
                
                if searchText.count > 2 {
                    if case .success(let results) = await searchDiscogs(searchTerm: searchText) {
                        searchResults = results
                    } else {
                        searchResults = []
                    }
                } else {
                    searchResults = []
                }
            }
        }
    }
}

struct barcodeRowView: View {
    
    var body: some View {
        HStack {
            Text("Add to collection via barcode")
            Spacer()
            Image(systemName: "barcode.viewfinder")
        }
        .listRowBackground(Color.green)
        .background(
            // Use an invisible NavigationLink overlay to hide the chevron
            NavigationLink(destination:
                BarcodeReader()
                    .toolbar(.hidden, for: .tabBar)
            ) { EmptyView() }
            .opacity(0)
        )
    }
}

struct rowView: View {
    
    let item: Album
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(item.title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(item.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: Detail Views

struct AlbumDetail: View {
    
    /// checking if this view has been access outside of the collection view
    /// In collection button not needed in said case (AlbumCollectionModel would be missing as an ancestor of this view)
    var accessed_via_collection_search: Bool? = true
    
    @EnvironmentObject var userCollection: AlbumCollectionModel
    
    let selectedAlbumID: Int
    @State private var selectedAlbum: Album?
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        if let selectedAlbum = selectedAlbum {
            ScrollView {
                AlbumHeaderView(album: selectedAlbum)
                AlbumInfoView(album: selectedAlbum)
            }
            .overlay {
                VStack {
                    Spacer()
                    
                    if accessed_via_collection_search ?? true {
                        InCollectionButton(selectedAlbum: selectedAlbum)
                            .padding()
                            .background(.thickMaterial)
                    }
                }
            }
        } else {
            ProgressView()
                .scaleEffect(2)
                .onAppear {
                    Task {
                        print("Selected album ID: \(selectedAlbumID)")
                        
                        let album_data = await discogsFetch(id: selectedAlbumID)
                        switch album_data {
                        case .success(let album):
                            selectedAlbum = album
                        case .failure(let error):
                            print(error)
                            // add error alert
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct AlbumInfoView: View {
    
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(title: "Artist", value: album.artist)
            InfoRow(title: "Genres", value: album.styles.joined(separator: ", "))
            InfoRow(title: "Release Year", value: album.release_year)

            Text("Tracklist")
                .bold()
                .padding(.top)
                .padding(.bottom, 4)

            ForEach(album.trackList ?? [], id: \.self) { track in
                Text("\(track.position) - \(track.title)")
            }
        }
        .padding()
        .padding(.bottom, 108)
    }
}

struct AlbumHeaderView: View {
    
    let album: Album

    var body: some View {
        Group {
            pictureAsyncFetch(url: album.cover_image_URL)
                .frame(width: 275, height: 275)
                .background(Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(album.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
        }
        .padding(4)
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0)
                .scaleEffect(phase.isIdentity ? 1 : 0.75)
                .blur(radius: phase.isIdentity ? 0 : 10)
        }
    }
}

struct InfoRow: View {
    
    let title: String
    let value: String

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundStyle(.thickMaterial)
            .frame(height: 45)
            .overlay {
                HStack {
                    Text(title)
                        .bold()
                    Spacer()
                    Text(value)
                }
                .padding()
            }
    }
}

struct InCollectionButton: View {
    
    @EnvironmentObject var userCollection: AlbumCollectionModel
    
    let selectedAlbum: Album
    
    var body: some View {
        Button {
            Task {
                var request: Result<CollectionItem?, any Error>
                
                if !userCollection.inCollection(selectedAlbum) {
                    request = await addToCollection(album: selectedAlbum)
                } else {
                    request = await removeFromCollection(discogs_id: selectedAlbum.id)
                }
                
                switch request {
                case .success(let result):
                    print("Added/Removed from Collection: \(String(describing: result))")
                    
                    if userCollection.inCollection(selectedAlbum) {
                        // was in collection, now removed, so therefore remove it locally
                        userCollection.removeAlbum(selectedAlbum)
                    } else {
                        // wasn't in collection, now added, so therefore add it locally
                        userCollection.addAlbum(selectedAlbum)
                    }
                
                case .failure(let error):
                    print(error)
                }
            }
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(userCollection.inCollection(selectedAlbum) ? Color.red : Color.blue)
                .frame(height: 50).frame(maxWidth: .infinity)
                .overlay(
                    Text(userCollection.inCollection(selectedAlbum) ? "Remove from Collection" : "Add to Collection")
                        .foregroundColor(.white)
                        .font(.headline)
                )
                .padding([.bottom])
        }
    }
}

//#Preview {
//    @Previewable @State var sampleCollection: [Album] = []
//    
//    AlbumDetail(selected_album_id: 2823404
//}
//
