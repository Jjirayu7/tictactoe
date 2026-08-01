import AVFoundation
import CoreAudio
import Foundation

final class ClickSoundEngine {
    private let engine = AVAudioEngine()
    private let audioFormat: AVAudioFormat
    private var players: [AVAudioPlayerNode] = []
    private var speedUnits: [AVAudioUnitVarispeed] = []
    private var equalizers: [AVAudioUnitEQ] = []
    private var buffers: [AVAudioPCMBuffer] = []
    private var volume: Float = 0.65
    private var presetVolumeDB: Float = 0
    private var presetSpeed: Float = 1
    private var presetEQLow: Float = 0
    private var presetEQMid: Float = 0
    private var presetEQHigh: Float = 0
    private var nextVoice = 0
    private var nextBuffer = 0

    init(audioURLs: [URL] = [], voiceCount: Int = 8) {
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let count = min(max(voiceCount, 1), 8)
        for _ in 0..<count {
            let player = AVAudioPlayerNode()
            let speedUnit = AVAudioUnitVarispeed()
            let equalizer = AVAudioUnitEQ(numberOfBands: 3)
            player.volume = volume
            engine.attach(player)
            engine.attach(speedUnit)
            engine.attach(equalizer)
            configure(equalizer: equalizer)
            engine.connect(player, to: speedUnit, format: audioFormat)
            engine.connect(speedUnit, to: equalizer, format: audioFormat)
            engine.connect(equalizer, to: engine.mainMixerNode, format: audioFormat)
            players.append(player)
            speedUnits.append(speedUnit)
            equalizers.append(equalizer)
        }
        engine.mainMixerNode.outputVolume = 1
        if let outputDeviceID = AudioDeviceManager.savedOutputDeviceID {
            _ = setOutputDevice(outputDeviceID)
        }
        load(audioURLs: audioURLs)
        try? engine.start()
    }

    func load(audioURLs: [URL]) {
        buffers = audioURLs.compactMap(loadBuffer)
    }

    private func loadBuffer(from url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            guard let sourceBuffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { return nil }
            try file.read(into: sourceBuffer)

            guard let converter = AVAudioConverter(from: file.processingFormat, to: audioFormat) else {
                return nil
            }

            let outputCapacity = AVAudioFrameCount(
                ceil(Double(sourceBuffer.frameLength) * audioFormat.sampleRate / file.processingFormat.sampleRate)
            )
            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: audioFormat,
                frameCapacity: max(outputCapacity, 1)
            ) else { return nil }

            var suppliedInput = false
            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
                guard !suppliedInput else {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                suppliedInput = true
                inputStatus.pointee = .haveData
                return sourceBuffer
            }

            guard status != .error, conversionError == nil, outputBuffer.frameLength > 0 else {
                return nil
            }
            return outputBuffer
        } catch {
            NSLog("tictactoe: unable to load audio %@: %@", url.path, error.localizedDescription)
            return nil
        }
    }

    func setVolume(_ value: Float) {
        volume = min(max(value, 0), 1)
        players.forEach { $0.volume = volume }
    }

    func setPresetSettings(volumeDB: Float, speed: Float, eqLow: Float, eqMid: Float, eqHigh: Float) {
        presetVolumeDB = min(max(volumeDB, -60), 24)
        presetSpeed = min(max(speed, 0.5), 2)
        presetEQLow = min(max(eqLow, -12), 12)
        presetEQMid = min(max(eqMid, -12), 12)
        presetEQHigh = min(max(eqHigh, -12), 12)
        applyPresetSettings()
    }

    @discardableResult
    func setOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        guard let audioUnit = engine.outputNode.audioUnit else { return false }
        var selectedDevice = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selectedDevice,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        return status == noErr
    }

    func play() {
        guard !buffers.isEmpty,
              !players.isEmpty,
              players.count == speedUnits.count,
              players.count == equalizers.count else { return }
        if !engine.isRunning { try? engine.start() }
        let voiceIndex = nextVoice % players.count
        let player = players[voiceIndex]
        let speedUnit = speedUnits[voiceIndex]
        let buffer = buffers[nextBuffer % buffers.count]
        nextVoice += 1
        nextBuffer += 1
        let randomPitchRatio = pow(2, Float.random(in: -80...80) / 1_200)
        speedUnit.rate = min(max(presetSpeed * randomPitchRatio, 0.5), 2)
        player.volume = volume * Float.random(in: 0.88...1.0)
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    private func configure(equalizer: AVAudioUnitEQ) {
        let frequencies: [Float] = [100, 1_000, 8_000]
        for (band, frequency) in zip(equalizer.bands, frequencies) {
            band.filterType = .parametric
            band.frequency = frequency
            band.bandwidth = 1
            band.bypass = false
        }
        equalizer.bypass = false
    }

    private func applyPresetSettings() {
        for (index, speedUnit) in speedUnits.enumerated() {
            speedUnit.rate = presetSpeed
            equalizers[index].globalGain = presetVolumeDB
            let bands = equalizers[index].bands
            bands[0].gain = presetEQLow
            bands[1].gain = presetEQMid
            bands[2].gain = presetEQHigh
        }
    }
}
