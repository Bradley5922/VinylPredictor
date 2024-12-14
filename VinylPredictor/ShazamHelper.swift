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
import OSLog

private let logger = Logger(subsystem: "com.vinylpredictor", category: "ShazamViewModel")

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
        tracklist_timer?.invalidate()
        cancellable?.cancel()
    }

    private func startTimer() {
        tracklist_timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.processBufferedDetections()
        }
    }

    private func stopTimer() {
        tracklist_timer?.invalidate()
        tracklist_timer = nil
    }

    func startListening() {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            logger.info("Requesting microphone permission.")
            requestRecordPermission()
        case .denied:
            logger.error("No microphone permission.")
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
        AVAudioApplication.requestRecordPermission(completionHandler: { granted in
            DispatchQueue.main.async {
                if granted {
                    DispatchQueue.global(qos: .background).async {
                        self.proceedWithRecording()
                    }
                } else {
                    logger.error("Microphone permission denied by the user.")
                }
            }
        })
    }

    private func proceedWithRecording() {
        if audioEngine.isRunning {
            // In case it was somehow running, stop first.
            stopRecording()
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: .zero)

        inputNode.removeTap(onBus: .zero)
        inputNode.installTap(onBus: .zero, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            self?.session.matchStreamingBuffer(buffer, at: time)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        audioEngine.stop()
    }
}

extension ShazamViewModel: SHSessionDelegate {
    
    func session(_ session: SHSession, didFind match: SHMatch) {
        guard let firstMatch = match.mediaItems.first else { return }
        
        var song = DetectedSong(
            id: firstMatch.id,
            artist: firstMatch.artist ?? "",
            title: firstMatch.title ?? "",
            album: firstMatch.songs.first?.albumTitle ?? "",
            duration: firstMatch.songs.first?.duration ?? 0,
            artworkURL: firstMatch.artworkURL ?? URL(string: "https://example.com/invalid-image-url.png")!
        )
        
        logger.info("Guesstimate song: \n\t=> \(song.appleMusic.title) - \(song.appleMusic.artist)")

        guard let userCollection = userCollection else {
            // User collection empty: no fuzzy matching
            DispatchQueue.main.async {
                withAnimation {
                    self.nowPlayingSong = song
                }
            }
            bufferedDetections.append(song)
            return
        }
        
        // Minimal fuzzy matching logic
        var matchesUserCollection: [(album: Album, score: Double)] = []
        
        for albumDiscogs in userCollection {
            let artistScore = compareStrings(a: song.appleMusic.artist, b: albumDiscogs.artist)
            let albumScore = compareStrings(a: song.appleMusic.album, b: albumDiscogs.title)
            let score = (artistScore * 0.70) + (albumScore * 0.30)
            let threshold = 0.6
            if score <= threshold {
                matchesUserCollection.append((album: albumDiscogs, score: score))
            }
        }

        if let closestMatch = matchesUserCollection.min(by: { $0.score < $1.score }),
           closestMatch.score <= 0.6 {
            song.discogsAlbum = closestMatch.album
        } else {
            song.discogsAlbum = nil
        }
        
        DispatchQueue.main.async {
            withAnimation {
                self.nowPlayingSong = song
            }
        }
        
        bufferedDetections.append(song)
    }
    
    func processBufferedDetections() {
        logger.debug("Processing buffered detections...")

        let detectedTitles = detectedSongs.map { $0.appleMusic.title }.joined(separator: ", ")
        logger.info("Current History Titles: \(detectedTitles)")

        let bufferedTitles = bufferedDetections.map { $0.appleMusic.title }.joined(separator: ", ")
        logger.info("Current Buffered Detections Titles: \(bufferedTitles)")

        if let mostFrequentSong = mostFrequentSong(array: bufferedDetections) {
            logger.debug("Most frequent buffered song: \(mostFrequentSong.appleMusic.title)")
            
            // Check duplicates in detectedSongs
            if self.detectedSongs.contains(where: { $0.id == mostFrequentSong.id }) {
                logger.warning("Song already present in detectedSongs [naive Apple Music ID check]")
                // Already present
                bufferedDetections.removeAll()
                return
            }
            
            // Fuzzy duplicate check in detectedSongs
            let threshold = 0.5
            for song in detectedSongs {
                let fuzzyMatchCheck = compareStrings(a: mostFrequentSong.appleMusic.title, b: song.appleMusic.title)
                if fuzzyMatchCheck < threshold {
                    // Too similar, skip
                    logger.warning("Fuzzy duplicate found: \(song.appleMusic.title) - \(fuzzyMatchCheck) [lower is better]")
                    
                    bufferedDetections.removeAll()
                    return
                }
            }
            
            // checks turned up nothing, precede with adding song to tracklist
            
            logger.info("No duplicates found in history, adding track: \(mostFrequentSong.appleMusic.title) - \(mostFrequentSong.album_title()) by \(mostFrequentSong.appleMusic.artist)")
            
            self.detectedSongs.append(mostFrequentSong)
            self.bufferedDetections.removeAll()
        } else {
            // No frequent song identified
        }
    }
    
    func mostFrequentSong(array: [DetectedSong]) -> DetectedSong? {
        var counts = [UUID: Int]()
        for item in array {
            counts[item.id] = (counts[item.id] ?? 0) + 1
        }

        if let (mostFrequentId, _) = counts.max(by: { $0.value < $1.value }) {
            return array.first(where: { $0.id == mostFrequentId })
        }

        return nil
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        if let error = error {
            logger.error("Error on match attempt: \(error.localizedDescription)")
        }
    }
}

func compareStrings(a: String, b: String, fuzzy: Fuse = Fuse()) -> Double {
    if a == b {
        return 0.0
    }
    
    if let fuzzyMatch = fuzzy.search(a, in: b) {
        return fuzzyMatch.score
    }
    
    return 1.0
}
