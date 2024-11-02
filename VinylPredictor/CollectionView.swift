//
//  MainScreen.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 27/10/2024.
//

import SwiftUI
import SwiftyJSON


func trimText(title: String) -> String {
    let trimmedText = title.count > 32 ? String(title.prefix(32)) + "..." : title
    
    return trimmedText
}

struct CollectionView: View {
    
    @State private var path = NavigationPath()
    @Binding var isShowingBarcodeSheet: Bool
    @State var barcodeSearchResult: Album?
    
    @State var loadingCollection: Bool = true
    @State var userCollection: [Album] = []
    
    @State var searchText = ""
    @State private var searchResults: [Album] = []
    
    var body: some View {
        
        NavigationStack(path: $path) {
            VStack {
                if loadingCollection { // Show loading indicator while collection is loading
                    ProgressView()
                        .scaleEffect(2)
                } else if userCollection.isEmpty { // No items in collection and not currently loading
                    NoAlbumsInfo()
                } else {
                    List(searchText.isEmpty ? userCollection : searchResults, id: \.id) { item in
                        NavigationLink(destination:
                            AlbumDetail(selected_album_id: item.id, userCollection: $userCollection)
                                .toolbar(.hidden, for: .tabBar)
                        ) {
                            rowView(item: item)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Collection")
            
            // show barcode sheet when toolbar item clicked
            .sheet(isPresented: $isShowingBarcodeSheet, content: {
                BarcodeReaderSheet(path: $path, barcodeSearchResult: $barcodeSearchResult)
            })
            
            .navigationDestination(for: String.self) { view in
                if view == "DetailAlbumView" && barcodeSearchResult != nil {
                    
                    AlbumDetail(selected_album_id: barcodeSearchResult!.id, userCollection: $userCollection)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
        }
        
        .onAppear() {
            Task {
                if case .success(let collection) = await fetchCollection() {
                    userCollection = collection
                    userCollection.sort(by: <)
                    loadingCollection = false
                }
            }
        }
        
        .onChange(of: searchText) {
            Task {
                if searchText.count > 2 {
                    searchResults = await fetchSearchResults()
                }
            }
        }
        
        .onChange(of: userCollection) {
            userCollection.sort(by: <) // keeps sorted after insertion or removal
        }
    }

    func fetchSearchResults() async -> [Album] {
        if case .success(let results) = await searchDiscogs(searchTerm: searchText) {
            return results
        }
        return []
    }
}

struct BarcodeScannerToolBarItem: View {
    
    @Binding var isShowingBarcodeSheet: Bool
    
    var body: some View {
        Button {
            isShowingBarcodeSheet = true
        } label: {
            Image(systemName: "barcode.viewfinder")
        }
    }
}



struct AlbumDetail: View {
    
    let selected_album_id: Int
    @State var selected_album: Album?
    
    @Binding var userCollection: [Album]
    
    @State var inCollection: Bool = false
    
    // used to programmatically go back if fetch fails
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        
        if let selected_album = selected_album {
            NavigationView {
                ScrollView {
                    Group {
                        selected_album.image
                            .frame(width: 275, height: 275)
                        
                        Text(selected_album.title)
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
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            
                            RoundedRectangle(cornerRadius: 8)
                                .foregroundStyle(.thickMaterial)
                                .frame(height: 45)
                                .overlay {
                                    HStack {
                                        Text("Artist")
                                            .bold()
                                        Spacer()
                                        Text(selected_album.artist)
                                    }
                                    .padding()
                                }
                            
                            RoundedRectangle(cornerRadius: 8)
                                .foregroundStyle(.thickMaterial)
                                .frame(height: 45)
                                .overlay {
                                    HStack {
                                        Text("Genres")
                                            .bold()
                                        Spacer()
                                        Text(selected_album.styles.joined(separator: ", "))
                                    }
                                    .padding()
                                }
                            
                            RoundedRectangle(cornerRadius: 8)
                                .foregroundStyle(.thickMaterial)
                                .frame(height: 45)
                                .overlay {
                                    HStack {
                                        Text("Release Year")
                                            .bold()
                                        Spacer()
                                        Text(selected_album.release_year)
                                    }
                                    .padding()
                                }
                            
                            Text("Tracklist")
                                .bold()
                                .padding(.top)
                                .padding(.bottom, 4)
                            
                            ForEach(selected_album.trackList ?? [], id: \.self) { track in
                                Text("\(track.position) - \(track.title)")
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .padding(.bottom, 108)
                        
                }
            }
            .overlay {
                VStack {
                    Spacer()
                    
                    InCollection_Button(
                        selected_album: selected_album,
                        inCollection: $inCollection,
                        userCollection: $userCollection
                    )
                    .padding()
                    .background(.thickMaterial)
                }
            }
        } else {
            ProgressView()
                .scaleEffect(2)
                .onAppear() {
                    Task {
                        inCollection = userCollection.contains(where: { $0.id == selected_album_id })
                        
                        if case .success(let album) = await discogsFetch(id: selected_album_id) {
                            selected_album = album
                        } else {
                            // Show error
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct rowView: View {
    
    let item: Album
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text(trimText(title: item.title))
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(item.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    @Previewable @State var sampleCollection: [Album] = []
    
    AlbumDetail(selected_album_id: 2823404, userCollection: $sampleCollection)
}

struct InCollection_Button: View {
    
    let selected_album: Album
    @Binding var inCollection: Bool
    @Binding var userCollection: [Album]
    
    var body: some View {
        Button {
            Task {
                var request: Result<Any, any Error>
                
                if !inCollection {
                    request = await addToCollection(discogs_id: selected_album.id)
                } else {
                    request = await removeFromCollection(discogs_id: selected_album.id)
                }
                
                switch request {
                case .success(let result):
                    print("Added/Removed from Collection: \(result)")
                    
                    if inCollection {
                        // was in collection, now removed, so therefore remove it locally
                        userCollection.removeAll(where: { $0.id == selected_album.id })
                    } else {
                        // wasn't in collection, now added, so therefore add it locally
                        userCollection.append(selected_album)
                    }
                    
                    inCollection.toggle()
                case .failure(let error):
                    print(error)
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
