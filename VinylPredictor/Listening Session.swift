//
//  Listening Session.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 02/12/2024.
//

import SwiftUI
import MusicKit

struct Listening_Session: View {
    
    @EnvironmentObject var Shazam: ShazamViewModel

    var body: some View {
        NavigationView {
            
            VStack {
                NowPlaying()
                    .padding([.top, .leading, .trailing])
                
//                Button(action: addNewSong) {
//                                    Text("Add New Song - TESTING")
//                                        .font(.headline)
//                                        .foregroundColor(.white)
//                                        .padding()
//                                        .background(Color.blue)
//                                        .cornerRadius(10)
//                                }
//                                .padding(.bottom, 20)

                List {
                    ForEach(Shazam.detectedSongs.reversed()) { song in
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .transition(AnyTransition.identity)
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
                
                Spacer()
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .navigationBarTitle("Listening Session")
        }
    }
    
//    func addNewSong() {
//            withAnimation {
//                let newSong = DetectedSong(
//                    id: UUID().uuidString,
//                    artist: "New Artist",
//                    title: "New Song",
//                    artworkURL: nil
//                )
//                Shazam.detectedSongs.append(newSong)
//            }
//        }
}

struct NowPlaying: View {
    
    @EnvironmentObject var Shazam: ShazamViewModel
    
    @State private var offset: CGFloat = 0
    @State private var artworkVisible = false

    var body: some View {
        
        VStack(spacing: 0) {
            Rectangle()
                .foregroundStyle(.background.secondary)
                .frame(maxWidth: .infinity, maxHeight: 110)
                .clipShape(
                    .rect(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 8
                    )
                )
                
                .overlay {
                    let artwork = Shazam.detectedSongs.last?.image
                    let title = Shazam.detectedSongs.last?.title
                    let album = Shazam.detectedSongs.last?.album?.title
                    
                    HStack(alignment: .center) {
                        
                        ZStack {
                            SpinningVinyl()
                                .frame(width: 90, height: 90)
                                .offset(x: offset)
                            
                            if let image = artwork {
                                image
                                    .frame(width: 90, height: 90)
                                    .opacity(artworkVisible ? 1: 0)
                                    .transition(.opacity) // Add a fade transition when the artwork changes
                            }
                        }
                        .shadow(radius: 8)
                        .padding(.trailing, 8)
                        
                        if Shazam.detectedSongs.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Waiting for a song...")
                                    .bold()
                                    .foregroundStyle(.primary)
                                
                                Text("Start a session and spin your records! 🕺")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading) {
                                Text("\(title ?? "-------------")")
                                    .bold()
                                    .foregroundStyle(.primary)
                                    .transition(.symbolEffect)
                                    .id(title)
                                
                                Text("\(album ?? "------------------------")")
                                    .foregroundStyle(.secondary)
                                    .transition(.symbolEffect)
                                    .id(album)
                            }
                            .offset(x: offset)
                        }
                        
                        Spacer()
                    }
                    .padding(10)
                    
                    .onChange(of: Shazam.detectedSongs.last) {
                        animateOffset()
                    }
                }
            
            Toggle("Listening Session Active", isOn: $Shazam.isListening)
                .toggleStyle(.switch)
                .tint(.yellow)
                .bold()
                .shadow(radius: 2)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green)
                .clipShape(
                    .rect(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 8,
                        bottomTrailingRadius: 8,
                        topTrailingRadius: 0
                    )
                )
        }
    }
    
    private func animateOffset() {
        // Reset offset to trigger a smoother animation
        withAnimation(.easeInOut(duration: 1.25)) {
            offset = 35
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
            withAnimation(.easeInOut(duration: 0.5)) {
                artworkVisible = true
            }
        }
    }
}

struct SpinningVinyl: View {
    @EnvironmentObject var Shazam: ShazamViewModel
    
    @State private var rotationAngle: Double = 0.0
    @State private var isAnimating = false

    var body: some View {
        Image("Disk")
            .resizable()
        
            .rotationEffect(Angle.degrees(rotationAngle))
            .onChange(of: Shazam.isListening) {
                if Shazam.isListening {
                    startRotating()
                } else {
                    stopRotating()
                }
            }
        
            // if the user comes back to the app during a session
            .onAppear {
                if Shazam.isListening {
                    startRotating()
                }
            }
    }

    private func startRotating() {
        isAnimating = true

        // Use a timer-based approach to continuously update the rotation
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if isAnimating {
                rotationAngle += 2 // Increment angle for smooth rotation
            } else {
                timer.invalidate() // Stop the timer when not animating
            }
        }
    }

    private func stopRotating() {
        isAnimating = false
        
        let additionalSpin: Double = 100
        
        // Calculate the target angle to spin the fixed amount forward
        let targetAngle = rotationAngle + additionalSpin

        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            // the below code allows the speed of rotation to slow down
            let remainingAngle = targetAngle - rotationAngle
            
            if rotationAngle < targetAngle {
                let increment = min(2, remainingAngle / 10) // Maximum increment of 2, so it won't go faster than playing, then it will slow down as it gets closer to target value
                rotationAngle += increment
            } else {
                timer.invalidate() // Stop the timer when target is reached
            }
        }
    }
}

extension MusicKit.Album {
    static func mock(
        id: String = UUID().uuidString,
        title: String = "Mock Album Title",
        artistName: String = "Mock Artist"
    ) -> MusicKit.Album {
        let json = """
        {
            "id": "\(id)",
            "title": "\(title)",
            "artistName": "\(artistName)"
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        return try! decoder.decode(MusicKit.Album.self, from: data)
    }
}

#Preview {
    let shazamViewModel = ShazamViewModel()
    
    // Add a variety of sample data to the detected songs
    shazamViewModel.detectedSongs.append(contentsOf: [
        DetectedSong(
            id: UUID().uuidString,
            artist: "Four Tet",
            title: "Three+",
            artworkURL: nil
        ),
        DetectedSong(
            id: UUID().uuidString,
            artist: "Aphex Twin",
            title: "Windowlicker",
            artworkURL: nil
        ),
        DetectedSong(
            id: UUID().uuidString,
            artist: "Radiohead",
            title: "Paranoid Android",
            artworkURL: nil
        ),
        DetectedSong(
            id: UUID().uuidString,
            artist: "Daft Punk",
            title: "Harder, Better, Faster, Stronger",
            artworkURL: nil
        ),
        DetectedSong(
            id: UUID().uuidString,
            artist: "Nirvana",
            title: "Smells Like Teen Spirit",
            artworkURL: nil
        ),
        DetectedSong(
            id: UUID().uuidString,
            artist: "The Prodigy",
            title: "Firestarter",
            artworkURL: nil
        ),
        DetectedSong(
            id: UUID().uuidString,
            artist: "The Beatles",
            title: "Hey Jude",
            artworkURL: nil
        ),
        DetectedSong(
            id: UUID().uuidString,
            artist: "Beyoncé",
            title: "Halo",
            artworkURL: nil
        ),
        DetectedSong(
            id: UUID().uuidString,
            artist: "Kendrick Lamar",
            title: "HUMBLE.",
            artworkURL: nil
        ),
        DetectedSong(
            id: UUID().uuidString,
            artist: "Tame Impala",
            title: "The Less I Know The Better",
            artworkURL: nil
        )
    ])
    
    return Listening_Session()
        .environmentObject(shazamViewModel)
}
