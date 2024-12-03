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

struct DetectedSong: Identifiable, Hashable {
    let id: String
    let artist: String
    let title: String
    
    var album: MusicKit.Album? // Updated asynchronously, only added for final detection
    
    let artworkURL: URL?
    
    
    var image: some View {
        
        Group {
            if let artworkURL = artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                    case .failure:
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundStyle(.background.secondary)
                    case .empty:
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundStyle(.background.secondary)
                    @unknown default:
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundStyle(.background.secondary)
                    }
                }
            } else {
                emptyImageView()
            }
        }
    }
    
    init(id: String?, artist: String?, title: String?, artworkURL: URL?, album: MusicKit.Album? = nil) {
        self.id = id ?? ""
        self.artist = artist ?? ""
        self.title = title ?? ""
        
        self.artworkURL = artworkURL
        self.album = album
    }
}

class ShazamViewModel: NSObject, ObservableObject {
    private var session = SHSession()
    private let audioEngine = AVAudioEngine()
    
    @Published var detectedSongs: [DetectedSong] = []
    @Published var isListening: Bool = false
    
    private var timer: Timer? // Timer to evaluate buffered detections
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
        timer?.invalidate()
        cancellable?.cancel()
    }

    // functions to start and stop buffer checks
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.processBufferedDetections()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
        
        let song: DetectedSong = DetectedSong(
            id: firstMatch.isrc,
            artist: firstMatch.artist,
            title: firstMatch.title,
            artworkURL: firstMatch.artworkURL
        )
        
        print("Guesstimated detected song: \(song.title) - \(song.artist) [ISRC: \(song.id)]")
        
        // buffer the detections, so we can be more confident about the results
        // especially songs with long intros
        bufferedDetections.append(song)
        
    }
    
    func processBufferedDetections() {
        print("Processing buffered detections... (30 seconds passed)")
        
        // Determine the most frequent song
        guard let mostFrequentSong = mostFrequentSong(array: bufferedDetections) else {
            bufferedDetections.removeAll()
            return
        }
        
        // Check if the song has already been detected
        if self.detectedSongs.contains(where: { $0.id == mostFrequentSong.id }) {
            print("Song already detected, skipping...")
            bufferedDetections.removeAll()
            return
        }
        
        // Fetch metadata from Apple Music
        Task {
            do {
                let result = await AppleMusicFetch(searchTerm: "\(mostFrequentSong.title) - \(mostFrequentSong.artist)")
                
                // Create a new immutable due to concurrency (see swift 6)
                let updatedDetection: DetectedSong = DetectedSong(
                    id: mostFrequentSong.id,
                    artist: mostFrequentSong.artist,
                    title: mostFrequentSong.title,
                    artworkURL: mostFrequentSong.artworkURL,
                    album: try result.get()
                )
                
                // Update UI on the main thread
                DispatchQueue.main.async {
                    print("Most frequent song in last 30 seconds: \(updatedDetection)")
                    self.detectedSongs.append(updatedDetection)
                }
            } catch {
                print("Failed to fetch metadata: \(error)")
            }
        }
        
        bufferedDetections.removeAll()
    }
    // helper function, counts most common in array - modified from stack overflow (https://stackoverflow.com/a/38416464)
    func mostFrequentSong(array: [DetectedSong]) -> DetectedSong? {
        var counts = [String: Int]()

        array.forEach { counts[$0.id] = (counts[$0.id] ?? 0) + 1 }

        // Find the ID with the maximum count
        if let (mostFrequentId, count) = counts.max(by: { $0.value < $1.value }) {
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
