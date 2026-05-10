import AVFoundation
import Foundation
import os

public protocol AudioRecorderProtocol: AnyObject {
    func start() async throws
    func stop() async -> [Float]
    var isRecording: Bool { get }
}

/// Captures microphone audio and resamples it to 16 kHz mono Float32 — the
/// canonical format Whisper consumes.
public final class AudioRecorder: AudioRecorderProtocol, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let log = Logger(subsystem: "de.dreamit.voicy", category: "AudioRecorder")

    private let targetFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
    }()

    private var converter: AVAudioConverter?
    private var buffer: [Float] = []
    private let bufferLock = NSLock()
    private(set) public var isRecording = false

    public init() {}

    public func start() async throws {
        guard !isRecording else { return }

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw AudioRecorderError.noInputDevice
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterUnavailable
        }
        self.converter = converter

        bufferLock.lock()
        buffer.removeAll(keepingCapacity: true)
        bufferLock.unlock()

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] pcm, _ in
            self?.process(pcm)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
        log.info("AudioRecorder started; input sampleRate=\(inputFormat.sampleRate, privacy: .public)")
    }

    public func stop() async -> [Float] {
        guard isRecording else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        bufferLock.lock()
        let samples = buffer
        buffer.removeAll(keepingCapacity: false)
        bufferLock.unlock()
        log.info("AudioRecorder stopped; captured \(samples.count, privacy: .public) samples (\(Double(samples.count) / 16000.0, privacy: .public)s)")
        return samples
    }

    private func process(_ inputBuffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio + 1024)
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputCapacity
        ) else { return }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return inputBuffer
        }

        if status == .error {
            log.error("Converter error: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            return
        }

        guard let channel = outputBuffer.floatChannelData?[0] else { return }
        let frames = Int(outputBuffer.frameLength)
        if frames == 0 { return }

        bufferLock.lock()
        buffer.append(contentsOf: UnsafeBufferPointer(start: channel, count: frames))
        bufferLock.unlock()
    }
}

public enum AudioRecorderError: Error, Sendable {
    case noInputDevice
    case converterUnavailable
}
