////
////  MainScreen.swift
////  VinylPredictor
////
////  Created by Bradley Cable on 27/10/2024.
////
//
//import SwiftUI
//import SwiftyJSON
//import Combine
//
//// MARK: - Extensions
//
//extension String {
//    func trimmed(to length: Int = 32) -> String {
//        return count > length ? String(prefix(length)) + "..." : self
//    }
//}
//
//// MARK: - Models
//
//class AlbumCollectionModel: ObservableObject {
//    @Published var albums: [Album] = []
//    @Published var isLoading = true
//
//    // Functions to add and remove albums
//    func addAlbum(_ album: Album) {
//        albums.append(album)
//    }
//
//    func removeAlbum(_ album: Album) {
//        albums.removeAll { $0.id == album.id }
//    }
//
//    func inCollection(_ album: Album) -> Bool {
//        return albums.contains(where: { $0.id == album.id })
//    }
//}
//
//// MARK: - Views
//
//struct CollectionView: View {
//    @StateObject var userCollection = AlbumCollectionModel()
//    @StateObject private var barcodeViewData = BarcodeViewDataStorage()
//
//    @State private var searchText = ""
//    @State private var searchResults: [Album] = []
//
//    var body: some View {
//        NavigationStack(path: $barcodeViewData.path) {
//            VStack {
//                if userCollection.isLoading {
//                    LoadingView()
//                } else if userCollection.albums.isEmpty {
//                    NoAlbumsInfo()
//                } else {
//                    AlbumListView(
//                        searchText: $searchText,
//                        searchResults: searchResults
//                    )
//                }
//            }
//            .navigationTitle("Collection")
//            .searchable(text: $searchText)
//            
//            //
//            .navigationDestination(for: String.self) { view in
//                if view == "DetailAlbumView" {
//                    if let albumID = barcodeViewData.barcodeScanResult?.id {
//                        AlbumDetail(selectedAlbumID: albumID)
//                            .toolbar(.hidden, for: .tabBar)
//                    }
//                }
//            }
//        }
//        .environmentObject(userCollection)
//        .environmentObject(barcodeViewData)
//        .onAppear {
//            Task {
//                if case .success(let collection) = await fetchCollection() {
//                    userCollection.albums = collection.sorted()
//                    userCollection.isLoading = false
//                }
//            }
//        }
//        .onChange(of: searchText) { _ in
//            Task {
//                if searchText.count > 2 {
//                    searchResults = await fetchSearchResults()
//                }
//            }
//        }
//    }
//
//    func fetchSearchResults() async -> [Album] {
//        if case .success(let results) = await searchDiscogs(searchTerm: searchText) {
//            return results
//        }
//        return []
//    }
//}
//
//// MARK: - AlbumDetail View
//
//struct AlbumDetail: View {
//    let selectedAlbumID: Int
//    @State private var selectedAlbum: Album?
//
//    @EnvironmentObject var userCollection: AlbumCollectionModel
//    @Environment(\.dismiss) var dismiss
//
//    var body: some View {
//        if let selectedAlbum = selectedAlbum {
//            ScrollView {
//                AlbumHeaderView(album: selectedAlbum)
//                AlbumInfoView(album: selectedAlbum)
//            }
//            .overlay {
//                InCollectionOverlay(selectedAlbum: selectedAlbum)
//            }
//        } else {
//            ProgressView()
//                .scaleEffect(2)
//                .onAppear {
//                    Task {
//                        if case .success(let album) = await discogsFetch(id: selectedAlbumID) {
//                            selectedAlbum = album
//                        } else {
//                            dismiss()
//                        }
//                    }
//                }
//        }
//    }
//}
//
//// MARK: - Subviews
//
//struct AlbumHeaderView: View {
//    let album: Album
//
//    var body: some View {
//        Group {
//            album.image
//                .frame(width: 275, height: 275)
//
//            Text(album.title)
//                .font(.title)
//                .bold()
//                .multilineTextAlignment(.center)
//        }
//        .padding(4)
//        .scrollTransition { content, phase in
//            content
//                .opacity(phase.isIdentity ? 1 : 0)
//                .scaleEffect(phase.isIdentity ? 1 : 0.75)
//                .blur(radius: phase.isIdentity ? 0 : 10)
//        }
//    }
//}
//
//struct AlbumInfoView: View {
//    let album: Album
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            InfoRow(title: "Artist", value: album.artist)
//            InfoRow(title: "Genres", value: album.styles.joined(separator: ", "))
//            InfoRow(title: "Release Year", value: album.releaseYear)
//
//            Text("Tracklist")
//                .bold()
//                .padding(.top)
//                .padding(.bottom, 4)
//
//            ForEach(album.trackList ?? [], id: \.self) { track in
//                Text("\(track.position) - \(track.title)")
//            }
//        }
//        .padding()
//        .padding(.bottom, 108)
//    }
//}
//
//struct InfoRow: View {
//    let title: String
//    let value: String
//
//    var body: some View {
//        RoundedRectangle(cornerRadius: 8)
//            .foregroundStyle(.thickMaterial)
//            .frame(height: 45)
//            .overlay {
//                HStack {
//                    Text(title)
//                        .bold()
//                    Spacer()
//                    Text(value)
//                }
//                .padding()
//            }
//    }
//}
//
//struct InCollectionOverlay: View {
//    let selectedAlbum: Album
//
//    var body: some View {
//        VStack {
//            Spacer()
//            InCollectionButton(selectedAlbum: selectedAlbum)
//                .padding()
//                .background(.thickMaterial)
//        }
//    }
//}
//
//struct InCollectionButton: View {
//    @EnvironmentObject var userCollection: AlbumCollectionModel
//    let selectedAlbum: Album
//
//    var body: some View {
//        Button {
//            Task {
//                let request: Result<Any, Error>
//
//                if !userCollection.inCollection(selectedAlbum) {
//                    request = await addToCollection(discogsID: selectedAlbum.id)
//                } else {
//                    request = await removeFromCollection(discogsID: selectedAlbum.id)
//                }
//
//                switch request {
//                case .success(let result):
//                    print("Added/Removed from Collection: \(result)")
//
//                    if userCollection.inCollection(selectedAlbum) {
//                        userCollection.removeAlbum(selectedAlbum)
//                    } else {
//                        userCollection.addAlbum(selectedAlbum)
//                    }
//
//                case .failure(let error):
//                    print(error)
//                }
//            }
//        } label: {
//            RoundedRectangle(cornerRadius: 10)
//                .fill(userCollection.inCollection(selectedAlbum) ? Color.red : Color.blue)
//                .frame(height: 50)
//                .frame(maxWidth: .infinity)
//                .overlay(
//                    Text(userCollection.inCollection(selectedAlbum) ? "Remove from Collection" : "Add to Collection")
//                        .foregroundColor(.white)
//                        .font(.headline)
//                )
//                .padding(.bottom)
//        }
//    }
//}
//
//struct RowView: View {
//    let album: Album
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            Text(album.title.trimmed())
//                .font(.headline)
//                .foregroundStyle(.primary)
//
//            Text(album.artist)
//                .font(.caption)
//                .foregroundStyle(.secondary)
//        }
//    }
//}
//
//struct NoAlbumsInfo: View {
//    var body: some View {
//        VStack(spacing: 8) {
//            Text("No albums in collection")
//                .font(.title)
//                .foregroundStyle(.primary)
//            Text("Search above to add albums")
//                .font(.title3)
//                .fontWeight(.light)
//                .foregroundStyle(.secondary)
//        }
//    }
//}
//
//struct LoadingView: View {
//    var body: some View {
//        ScrollView {
//            ProgressView()
//                .scaleEffect(2)
//        }
//    }
//}
//
//struct BarcodeAddRow: View {
//    var body: some View {
//        HStack {
//            Text("Add to collection via barcode")
//            Spacer()
//            Image(systemName: "barcode.viewfinder")
//        }
//        .listRowBackground(Color.green)
//        .background(
//            NavigationLink(destination:
//                BarcodeReader()
//                    .toolbar(.hidden, for: .tabBar)
//            ) { EmptyView() }
//            .opacity(0)
//        )
//    }
//}
//
//struct AlbumListView: View {
//    @Binding var searchText: String
//    let albums: [Album]
//    let searchResults: [Album]
//
//    var body: some View {
//        List {
//            BarcodeAddRow()
//
//            ForEach(searchText.isEmpty ? albums : searchResults, id: \.id) { album in
//                NavigationLink(destination:
//                    AlbumDetail(selectedAlbumID: album.id)
//                        .toolbar(.hidden, for: .tabBar)
//                ) {
//                    RowView(album: album)
//                }
//            }
//        }
//    }
//}
//
//// Uncomment and adjust if you have a preview setup
///*
//#Preview {
//    AlbumDetail(selectedAlbumID: 2823404)
//        .environmentObject(AlbumCollectionModel())
//        .environmentObject(BarcodeViewDataStorage())
//}
//*/
