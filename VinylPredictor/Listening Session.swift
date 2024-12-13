////
////  Listening Session.swift
////  VinylPredictor
////
////  Created by Bradley Cable on 02/12/2024.
////
//
//import SwiftUI
//import MusicKit
//import MarqueeText
//
//struct Listening_Session: View {
//    
//    @StateObject var userCollection: AlbumCollectionModel = AlbumCollectionModel()
//    
//    @EnvironmentObject var Shazam: ShazamViewModel
//    
//    @State var tracklistHistory: [DetectedSong] = []
//
//    var body: some View {
//        NavigationView {
//            
//            VStack(alignment: .leading) {
//                NowPlaying()
//                    .padding([.top, .leading, .trailing])
//                
//       
//                List {
//                    Group {
//                        if tracklistHistory.isEmpty {
//                            VStack(alignment: .leading) {
//                                Text("No Previous Songs...")
//                                    .bold()
//                                    .foregroundStyle(.primary)
//                                
//                                Text("As you spin new tracks, as they get recognized, they'll appear here!")
//                                    .foregroundStyle(.secondary)
//                                
//                            }
//                        }
//                        
//                        ForEach(tracklistHistory) { song in
//                            VStack(alignment: .leading) {
//                                Text(song.title)
//                                    .font(.headline)
//                                    .foregroundStyle(.primary)
//                                
//                                Text(song.artist)
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                            }
//                            .transition(AnyTransition.identity)
//                        }
//                        .onDelete(perform: deleteSong)
//                        
//                        .onChange(of: Shazam.detectedSongs) {
//                            withAnimation {
//                                var updatedList = Shazam.detectedSongs
//                                _ = updatedList.popLast() // Removes the last element (now playing)
//                                tracklistHistory = updatedList.reversed()
//                            }
//                        }
//                    }
//                    .padding(.top, 10)
//                }
//                .listStyle(.plain)
//                .scrollIndicators(.hidden)
//                
//                .overlay(alignment: .top) {
//                    Rectangle()
//                        .foregroundStyle(Gradient(colors: [Color.black, Color.clear]))
//                        .frame(height: 30)
//                }
//                
//
//                
//                Spacer()
//            }
//            .ignoresSafeArea(.all, edges: .bottom)
//            .navigationBarTitle("Listening Session")
//        }
//        .environment(userCollection)
//        .onAppear() {
//            Task {
//                if case .success(let collection) = await fetchCollection() {
//                    userCollection.array = collection
//                    userCollection.loading = false
//                }
//            }
//        }
//    }
//    
//    private func deleteSong(at offsets: IndexSet) {
//        Shazam.detectedSongs.remove(atOffsets: offsets)
//    }
//    
////    MARK: Used for testing
////    func addNewSong() {
////            withAnimation {
////                let newSong = DetectedSong(
////                    id: UUID().uuidString,
////                    artist: "New Artist",
////                    title: "Lorem ipsum dolor sit amet, consectetur adipiscing elit",
////                    artworkURL: nil
////                )
////                Shazam.detectedSongs.append(newSong)
////            }
////        }
//}
//
//struct NowPlaying: View {
//    
//    @EnvironmentObject var Shazam: ShazamViewModel
//    
//    @State private var offset: CGFloat = 0
//    @State private var artworkVisible = false
//
//    var body: some View {
//        
//        VStack(spacing: 0) {
//            Rectangle()
//                .foregroundStyle(.background.secondary)
//                .frame(maxWidth: .infinity, maxHeight: 110)
//                .clipShape(
//                    .rect(
//                        topLeadingRadius: 8,
//                        bottomLeadingRadius: 0,
//                        bottomTrailingRadius: 0,
//                        topTrailingRadius: 8
//                    )
//                )
//            
//                .overlay {
//                    let artwork = Shazam.nowPlayingSong?.image
//                    let title = Shazam.nowPlayingSong?.title
//                    let album = Shazam.nowPlayingSong?.album
//                    
//                    GeometryReader { geometry in
//                        HStack(alignment: .center) {
//                            
//                            ZStack {
//                                SpinningVinyl()
//                                    .frame(width: 90, height: 90)
//                                    .offset(x: offset)
//                                
//                                if let image = artwork {
//                                    image
//                                        .frame(width: 90, height: 90)
//                                        .opacity(artworkVisible ? 1: 0)
//                                        .transition(.opacity) // Add a fade transition when the artwork changes
//                                }
//                            }
//                            .shadow(radius: 8)
//                            .padding(.trailing, 8)
//                            
//                            if Shazam.nowPlayingSong == nil {
//                                VStack(alignment: .leading) {
//                                    Text("Waiting for a song...")
//                                        .bold()
//                                        .foregroundStyle(.primary)
//                                    
//                                    Text("Start a session and spin your records! 🕺")
//                                        .foregroundStyle(.secondary)
//                                }
//                            } else {
//                                VStack(alignment: .leading) {
//                                    MarqueeText(
//                                        text: title ?? "-------------",
//                                        font: UIFont.preferredFont(forTextStyle: .body),
//                                        leftFade: 5,
//                                        rightFade: 16,
//                                        startDelay: 3
//                                    )
//                                    .frame(width: geometry.size.width - 90 - 30 - offset, alignment: .leading) // Adjusted width
//
//                                    .bold()
//                                    .foregroundStyle(.primary)
//
//                                    MarqueeText(
//                                        text: album ?? "-----------------------",
//                                        font: UIFont.preferredFont(forTextStyle: .body),
//                                        leftFade: 5,
//                                        rightFade: 16,
//                                        startDelay: 3
//                                    )
//                                    .frame(width: geometry.size.width - 90 - 30 - offset, alignment: .leading) // Adjusted width
//                                    .foregroundStyle(.secondary)
//                                }
//                                .offset(x: offset)
//                            }
//                            
//                            Spacer()
//                        }
//                        .padding(10)
//                        
//                        .onChange(of: Shazam.isListening) {
//                            animateOffset()
//                        }
//                        .onChange(of: Shazam.nowPlayingSong) {
//                            animateOffset()
//                        }
//                    }
//                }
//            
//            Toggle("Listening Session Active", isOn: $Shazam.isListening)
//                .toggleStyle(.switch)
//                .tint(.yellow)
//                .bold()
//                .shadow(radius: 2)
//                .padding(.horizontal, 12)
//                .padding(.vertical, 8)
//                .background(Color.green)
//                .clipShape(
//                    .rect(
//                        topLeadingRadius: 0,
//                        bottomLeadingRadius: 8,
//                        bottomTrailingRadius: 8,
//                        topTrailingRadius: 0
//                    )
//                )
//        }
//    }
//    
//    private func animateOffset() {
//        if Shazam.isListening && Shazam.nowPlayingSong != nil {
//            // Reset offset to trigger a smoother animation
//            withAnimation(.easeInOut(duration: 1.25)) {
//                offset = 35
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
//                withAnimation(.easeInOut(duration: 0.5)) {
//                    artworkVisible = true
//                }
//            }
//        } else {
//            withAnimation(.easeInOut(duration: 0.5)) {
//                artworkVisible = false
//            }
//            withAnimation(.easeInOut(duration: 1.25)) {
//                offset = 0
//            }
//        }
//    }
//}
//
//struct SpinningVinyl: View {
//    @EnvironmentObject var Shazam: ShazamViewModel
//    
//    @State private var rotationAngle: Double = 0.0
//    @State private var isAnimating = false
//
//    var body: some View {
//        Image("Disk")
//            .resizable()
//        
//            .rotationEffect(Angle.degrees(rotationAngle))
//            .onChange(of: Shazam.isListening) {
//                if Shazam.isListening {
//                    startRotating()
//                } else {
//                    stopRotating()
//                }
//            }
//        
//            // if the user comes back to the app during a session
//            .onAppear {
//                if Shazam.isListening {
//                    startRotating()
//                }
//            }
//    }
//
//    private func startRotating() {
//        isAnimating = true
//
//        // Use a timer-based approach to continuously update the rotation
//        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
//            if isAnimating {
//                rotationAngle += 2 // Increment angle for smooth rotation
//            } else {
//                timer.invalidate() // Stop the timer when not animating
//            }
//        }
//    }
//
//    private func stopRotating() {
//        isAnimating = false
//        
//        let additionalSpin: Double = 150
//        
//        // Calculate the target angle to spin the fixed amount forward
//        let targetAngle = rotationAngle + additionalSpin
//
//        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
//            // the below code allows the speed of rotation to slow down
//            let remainingAngle = targetAngle - rotationAngle
//            
//            if rotationAngle < targetAngle {
//                let increment = min(2, remainingAngle / 10) // Maximum increment of 2, so it won't go faster than playing, then it will slow down as it gets closer to target value
//                rotationAngle += increment
//            } else {
//                timer.invalidate() // Stop the timer when target is reached
//            }
//        }
//    }
//}
//
//#Preview {
//    let shazamViewModel = ShazamViewModel()
//    
////    // Add a variety of sample data to the detected songs
////    shazamViewModel.detectedSongs.append(contentsOf: [
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "Four Tet",
////            title: "Three+",
////            artworkURL: nil
////        ),
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "Aphex Twin",
////            title: "Windowlicker",
////            artworkURL: nil
////        ),
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "Radiohead",
////            title: "Paranoid Android",
////            artworkURL: nil
////        ),
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "Daft Punk",
////            title: "Harder, Better, Faster, Stronger",
////            artworkURL: nil
////        ),
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "Nirvana",
////            title: "Smells Like Teen Spirit",
////            artworkURL: nil
////        ),
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "The Prodigy",
////            title: "Firestarter",
////            artworkURL: nil
////        ),
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "The Beatles",
////            title: "Hey Jude",
////            artworkURL: nil
////        ),
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "Beyoncé",
////            title: "Halo",
////            artworkURL: nil
////        ),
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "Kendrick Lamar",
////            title: "HUMBLE.",
////            artworkURL: nil
////        ),
////        DetectedSong(
////            id: UUID().uuidString,
////            artist: "Tame Impala",
////            title: "The Less I Know The Better",
////            artworkURL: nil
////        )
////    ])
//    
//    return Listening_Session()
//        .environmentObject(shazamViewModel)
//}
