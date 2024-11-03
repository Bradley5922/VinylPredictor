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

class AlbumCollectionModel: ObservableObject, Observable {
    @Published var array: [Album] = []
    @Published var loading = true
    
    // Functions to add and remove albums
    func addAlbum(_ album: Album) {
        array.append(album)
    }
    
    func removeAlbum(_ album: Album) {
        array.removeAll { $0.id == album.id }
    }
    
    func inCollection(_ album: Album) -> Bool {
        return array.contains(where: { $0.id == album.id })
    }
}

struct CollectionView: View {
    
    @StateObject var userCollection: AlbumCollectionModel = AlbumCollectionModel()
    @StateObject private var barcodeViewData = BarcodeViewDataStorage()
    
    var body: some View {
        
        NavigationStack(path: $barcodeViewData.path) {
            VStack {
                
                if userCollection.loading { // Show loading indicator while collection is loading
                    ProgressView().scaleEffect(2)
                } else if userCollection.array.isEmpty { // No items in collection and not currently loading
                    NoAlbumsInfo()
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
        .environment(userCollection)
        .environment(barcodeViewData)
        
        .onAppear() {
            Task {
                if case .success(let collection) = await fetchCollection() {
                    userCollection.array = collection
                    userCollection.array.sort(by: <)
                    userCollection.loading = false
                }
            }
        }
    }
}

struct NoAlbumsInfo: View {
    
    var body: some View {
        VStack(spacing: 8) {
            Text("No albums in collection")
                .font(.title)
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
    
    var body: some View {
        List {
            barcodeRowView()
            
            ForEach(searchText.isEmpty ? userCollection.array : searchResults, id: \.id) { item in
                NavigationLink(destination:
                    AlbumDetail(selectedAlbumID: item.id)
                        .toolbar(.hidden, for: .tabBar)
                ) {
                    rowView(item: item)
                }
            }
        }
        .searchable(text: $searchText)
        
        .onChange(of: searchText) {
            Task {
                if searchText.count > 2 {
                    
                    if case .success(let results) = await searchDiscogs(searchTerm: searchText) {
                        
                        searchResults = results
                    } else {
                        searchResults = []
                    }
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
                    
                    InCollectionButton(selectedAlbum: selectedAlbum)
                        .padding()
                        .background(.thickMaterial)
                }
            }
        } else {
            ProgressView()
                .scaleEffect(2)
                .onAppear {
                    Task {
                        if case .success(let album) = await discogsFetch(id: selectedAlbumID) {
                            selectedAlbum = album
                        } else {
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
            album.image
                .frame(width: 275, height: 275)

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
                var request: Result<Any, any Error>
                
                if !userCollection.inCollection(selectedAlbum) {
                    request = await addToCollection(discogs_id: selectedAlbum.id)
                } else {
                    request = await removeFromCollection(discogs_id: selectedAlbum.id)
                }
                
                switch request {
                case .success(let result):
                    print("Added/Removed from Collection: \(result)")
                    
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
