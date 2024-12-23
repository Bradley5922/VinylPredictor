////
////  StatsTest.swift
////  VinylPredictor
////
////  Created by Bradley Cable on 04/12/2024.
////
//
//import Foundation
//import SwiftUI
//
//struct StatsTest: View {
//    
//    @State var stats: TopListeningStats?
//    
//    var body: some View {
//        
//        VStack(alignment: .leading) {
//            Text("StatsTest")
//                .font(.largeTitle)
//                .bold()
//            
//            if let stats = stats {
//                Text("**Total Listening Time:** \(stats.overall)")
//                
//                Text("Top Artists:")
//                    .bold()
//                
//                ForEach(stats.topArtists) { artist in
//                    Text("- \(artist.name): \(artist.total_listening_mins) mins")
//                }
//                
//                Text("Top Albums:")
//                    .bold()
//                
//                ForEach(stats.topAlbums) { album in
//                    Text("- \(album.name): \(album.total_listening_mins) mins")
//                }
//            }
//        }
//        .onAppear() {
//            Task {
//                let result = await fetchUserListeningStats()
//                switch result {
//                    case .success(let stats):
//                    print(stats)
//                    self.stats = stats
//                case .failure(let error):
//                    print(error)
//                }
//            }
//        }
//    }
//}
