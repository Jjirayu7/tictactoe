import AVFoundation
import Foundation

final class ClickSoundEngine {
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [AVAudioPCMBuffer] = []
    private var volume: Float = 0.65
    private var nextVoice = 0
    private var nextBuffer = 0

    init(audioURLs: [URL] = [], voiceCount: Int = 8) {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let count = min(max(voiceCount, 1), 8)
        for _ in 0..<count {
            let player = AVAudioPlayerNode()
            player.volume = volume
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 1
        load(audioURLs: audioURLs)
        try? engine.start()
    }

    func load(audioURLs: [URL]) {
        buffers = audioURLs.compactMap { url in
            guard let file = try? AVAudioFile(forReading: url),
                  let loaded = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                return nil
            }
            try? file.read(into: loaded)
            return loaded
        }
    }

    func setVolume(_ value: Float) {
        volume = min(max(value, 0), 1)
        players.forEach { $0.volume = volume }
    }

    func play() {
        guard !buffers.isEmpty, !players.isEmpty else { return }
        if !engine.isRunning { try? engine.start() }
        let player = players[nextVoice % players.count]
        let buffer = buffers[nextBuffer % buffers.count]
        nextVoice += 1
        nextBuffer += 1
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }
}
