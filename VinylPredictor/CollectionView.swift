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
    
    @State private var searchText: String = ""
    @State private var searchScope: SearchScope = .title
    @State private var searchResults: [Album] = []
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
        
        .searchScopes($searchScope) {
            Text("Album Title").tag(SearchScope.title)
            Text("Artist").tag(SearchScope.artist)
        }
        
        .onChange(of: searchText) {
            performSearchDebounced()
        }
    }
    
    // Filter results based on selected scope
    private func filteredResults(collection: [Album]) -> [Album] {
        collection.filter { album in
            switch searchScope {
            case .title:
                return searchText.isEmpty || album.title.localizedCaseInsensitiveContains(searchText)
            case .artist:
                return searchText.isEmpty || album.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Debounced search logic
    private func performSearchDebounced() {
        // Cancel any pending task
        searchTask?.cancel()
        
        // "Debounce" search to only make request when user stops typing
        searchTask = Task {
            // Debounce for 1 second
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if query.isEmpty || query.count <= 2 {
                searchResults = []
                return
            }
            
            // Perform search based on the current scope
            switch searchScope {
            case .title:
                if case .success(let results) = await searchDiscogs(title: searchText) {
                    searchResults = results
                } else {
                    searchResults = []
                }
            case .artist:
                if case .success(let results) = await searchDiscogs(artist: searchText) {
                    searchResults = results
                } else {
                    searchResults = []
                }
            }
        }
    }

}

// Enum for search scope
enum SearchScope: String {
    case title
    case artist
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
    @State var inCollection: Bool = false
    
    var body: some View {
        
        
        Button {
            Task {
                
                if !inCollection {
                    await userCollection.addAlbum(selectedAlbum)
                    inCollection.toggle()
                } else {
                    await userCollection.removeAlbum(selectedAlbum)
                    inCollection.toggle()
                }
                
            }
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(inCollection ? Color.red : Color.blue)
                .frame(height: 50).frame(maxWidth: .infinity)
                .overlay(
                    Text(inCollection ? "Remove from Collection" : "Add to Collection")
                        .foregroundColor(.white)
                        .font(.headline)
                )
                .padding([.bottom])
        }
        .onAppear {
            inCollection = userCollection.inCollection(selectedAlbum)
        }
    }
}

#Preview {
    let mockCollection = AlbumCollectionModel()
    mockCollection.loading = false

    return CollectionView()
        .environmentObject(mockCollection)
}


