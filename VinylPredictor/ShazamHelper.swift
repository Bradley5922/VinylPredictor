import Foundation
import AVKit
import ShazamKit

class ShazamViewModel: NSObject, ObservableObject {
    private var session = SHSession()
    private let audioEngine = AVAudioEngine()
    
    @Published var isListening: Bool = false

    override init() {
        super.init()
        session.delegate = self
    }

    func startListening() {

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
        
        audioEngine.stop()
    }
}

extension ShazamViewModel: SHSessionDelegate {
    func session(_ session: SHSession, didFind match: SHMatch) {
        guard let firstMatch = match.mediaItems.first else {
            return
        }
//        stopRecording()
        
        print("Found match: \(firstMatch)")
        print("\(firstMatch.title ?? "Song Name") - \(firstMatch.artist ?? "Artist Name")")
        

//        let song = Song(
//            title: firstMatch.title ?? "",
//            artist: firstMatch.artist ?? "",
//            genres: firstMatch.genres,
//            artworkUrl: firstMatch.artworkURL,
//            appleMusicUrl: firstMatch.appleMusicURL
//        )
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        print(error?.localizedDescription ?? "")
        print("No match found, waiting for song to be played")

    }
}
