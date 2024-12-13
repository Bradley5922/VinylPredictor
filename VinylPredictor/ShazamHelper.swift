//
//  ShazamTest.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 26/11/2024.
//

import Foundation
import AVKit
import ShazamKit
import SwiftUI
import Combine
import MusicKit
import Fuse // allows for fuzzy searching

struct DetectedSong: Identifiable, Hashable {
    let id: UUID // Apple Music ID
    
    struct AppleMusic: Hashable {
        let artist: String
        let title: String
        let album: String
        let duration: TimeInterval
        let artworkURL: URL
    }
    
    let appleMusic: AppleMusic
    var discogsAlbum: Album?
    
    func album_title() -> String {
        if let discogsAlbum {
            return discogsAlbum.title
        } else {
            return appleMusic.album
        }
    }
    
    func album_artwork() -> URL {
        if let discogsAlbum {
            return discogsAlbum.cover_image_URL ?? appleMusic.artworkURL
        } else {
            return appleMusic.artworkURL
        }
    }
    
    init(id: UUID,
         artist: String,
         title: String,
         album: String,
         duration: TimeInterval,
         artworkURL: URL,
         discogsAlbum: Album? = nil
    ) {
        self.id = id
        self.appleMusic = AppleMusic(artist: artist, title: title, album: album, duration: duration, artworkURL: artworkURL)
        self.discogsAlbum = discogsAlbum
    }
}


class ShazamViewModel: NSObject, ObservableObject {
    private var session = SHSession()
    private let audioEngine = AVAudioEngine()
    
    @Published var detectedSongs: [DetectedSong] = []
    @Published var nowPlayingSong: DetectedSong?
    
    @Published var userCollection: [Album]? // used to relate user collection to Shazam detections
    
    @Published var isListening: Bool = false
    
    private var tracklist_timer: Timer? // Timer to evaluate buffered detections
    private var bufferedDetections: [DetectedSong] = []
    
    private var cancellable: AnyCancellable? // Store Combine subscription, listening object

    override init() {
        super.init()
        session.delegate = self

        // Set up listener for `isListening`
        cancellable = $isListening.sink { [weak self] state in
            guard let self = self else { return }
            
            if state {
                self.startTimer()
                self.startListening()
            } else {
                self.stopTimer()
                self.stopListening()
            }
        }
    
    }
        
    deinit {
        // Cancel listeners and timers (for function fires)
        tracklist_timer?.invalidate()
        cancellable?.cancel()
    }

    // functions to start and stop buffer checks
    private func startTimer() {
        tracklist_timer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            self?.processBufferedDetections()
        }
    }

    private func stopTimer() {
        tracklist_timer?.invalidate()
        tracklist_timer = nil
    }

    func startListening() {
        print("Song Detection Session, Started.")
        
        
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            requestRecordPermission()
        case .denied:
            print("no microphone permission")
        case .granted:
            DispatchQueue.global(qos: .background).async {
                self.proceedWithRecording()
            }
        @unknown default:
            requestRecordPermission()
        }
    }

    func stopListening() {
        stopRecording()
    }

    private func requestRecordPermission() {
        AVAudioApplication.requestRecordPermission(completionHandler: { (granted: Bool) -> Void in
            DispatchQueue.main.async {
                if granted {
                    DispatchQueue.global(qos: .background).async {
                        self.proceedWithRecording()
                    }
                } else {
                    print("Permission denied")
                }
            }
        })
    }

    private func proceedWithRecording() {
        print("Recording started, waiting for results...")
        
        // Implement a local notification trigger, every half hour
        // "Are you still listening?, if not disable"

        if audioEngine.isRunning {
            stopRecording()
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: .zero)

        inputNode.removeTap(onBus: .zero)
        inputNode.installTap(onBus: .zero, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
//            print("Current Recording at: \(time)")
            self?.session.matchStreamingBuffer(buffer, at: time)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            print(error.localizedDescription)
        }
    }

    private func stopRecording() {
        print("Song Detection Session, Ended.")
        // upload to Supabase
        
        audioEngine.stop()
    }
}

extension ShazamViewModel: SHSessionDelegate {
    
    func session(_ session: SHSession, didFind match: SHMatch) {
        guard let firstMatch = match.mediaItems.first else {
            return
        }
        
        var song: DetectedSong = DetectedSong(
            id: firstMatch.id,
            artist: firstMatch.artist ?? "",
            title: firstMatch.title ?? "",
            album: firstMatch.songs.first?.albumTitle ?? "",
            duration: firstMatch.songs.first?.duration ?? 0,
            artworkURL: firstMatch.artworkURL ?? URL(string: "https://example.com/invalid-image-url.png")!
        )
        
        print("Guesstimated detected song: \(song.appleMusic.title) - \(song.appleMusic.album) by \(song.appleMusic.artist)")

        // user collection is available for comparison
        if let userCollection = userCollection {
            let fuzzy = Fuse() // library for fuzzy search
            var matchesUserCollection: [(album: Album, score: Double)] = []

            // need to consider track list in here too
            for albumDiscogs in userCollection {
                if let temp = fuzzy.search("\(song.appleMusic.artist) - \(song.appleMusic.album)", in: "\(albumDiscogs.artist) - \(albumDiscogs.title)") {
                    print("Fuzzy Score: \(temp.score)")
                    matchesUserCollection.append((album: albumDiscogs, score: temp.score))
                }
            }

            if let closestMatch = matchesUserCollection.max(by: { $0.score < $1.score }),
               closestMatch.score > 0.4 {
                song.discogsAlbum = closestMatch.album
            } else {
                song.discogsAlbum = nil
            }

            // Compare detected album with what's in the collection
            print("\(song.discogsAlbum?.title ?? "No Match") VS \(song.appleMusic.album)")
        }
        
        // buffer the detections, so we can be more confident about the results
        // especially songs with long intros
        DispatchQueue.main.async {
            withAnimation {
                self.nowPlayingSong = song
            }
        }
        
        bufferedDetections.append(song)
        
    }
    
    func processBufferedDetections() {
        print("Processing buffered detections... (45 seconds passed)")

        if let mostFrequentSong = mostFrequentSong(array: bufferedDetections) {
            if self.detectedSongs.contains(where: { $0.id == mostFrequentSong.id }) {
                print("Song already detected, skipping...")
            } else {
                print("\nUpdating tracklist...")
                print("\t=> \(mostFrequentSong.appleMusic.title) - \(mostFrequentSong.album_title()) by \(mostFrequentSong.appleMusic.artist)")
                
                DispatchQueue.main.async {
                    withAnimation {
                        self.detectedSongs.append(mostFrequentSong)
                        self.bufferedDetections.removeAll()
                    }
                }
            }
        }
    }
    
    // helper function, counts most common in array - modified from stack overflow (https://stackoverflow.com/a/38416464)
    func mostFrequentSong(array: [DetectedSong]) -> DetectedSong? {
        var counts = [UUID: Int]()

        array.forEach { counts[$0.id] = (counts[$0.id] ?? 0) + 1 }

        // Find the ID with the maximum count
        if let (mostFrequentId, _) = counts.max(by: { $0.value < $1.value }) {
            // Find the corresponding DetectedSong for the most frequent ID
            if let mostFrequentSong = array.first(where: { $0.id == mostFrequentId }) {
                return mostFrequentSong
            }
        }

        return nil
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        print(error?.localizedDescription ?? "")
        print("No match found, waiting for song to be played")

    }
}

// Changed implementation not needed, could get data straight from Shazam response
// Fetch metadata from Apple Music
//Task {
//    do {
//        let result = await AppleMusicFetch(searchTerm: "\(mostFrequentSong.title) - \(mostFrequentSong.artist)")
//        
//        // Create a new immutable due to concurrency (see swift 6)
//        let updatedDetection: DetectedSong = DetectedSong(
//            id: mostFrequentSong.id,
//            artist: mostFrequentSong.artist,
//            title: mostFrequentSong.title,
//            artworkURL: mostFrequentSong.artworkURL,
//            album: try result.get()
//        )
//        
//        // Update UI on the main thread
//        DispatchQueue.main.async {
//            withAnimation {
//                print("Most frequent song in last 30 seconds: \(updatedDetection)")
//                self.detectedSongs.append(updatedDetection)
//            }
//        }
//    } catch {
//        print("Failed to fetch metadata: \(error)")
//    }
//}
