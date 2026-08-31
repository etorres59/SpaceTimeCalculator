//
//  Metronome.swift
//  Space & Time
//
//  Audible + haptic + visual metronome so a tempo can be checked by feel.
//

import Foundation
import AVFoundation

#if canImport(UIKit)
import UIKit
#endif

/// Plays a click at the current tempo. Timing comes from a high-priority
/// `DispatchSourceTimer`; each tick schedules a pre-rendered click buffer and
/// updates the beat for the UI and haptics. Not sample-accurate — good enough
/// to check whether a tempo feels right, which is all this needs to do.
@MainActor
final class MetronomeEngine: ObservableObject {
    @Published private(set) var isRunning = false
    /// 0-based beat within the current bar, for the pulsing UI.
    @Published private(set) var beat = 0
    @Published var beatsPerBar = 4 {
        didSet { beatsPerBar = min(max(beatsPerBar, 1), 12) }
    }

    /// Kept in sync with the tempo field; restarts the timer while running.
    var bpm: Double = 120 {
        didSet { if isRunning, bpm != oldValue { scheduleTimer() } }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let accentClick: AVAudioPCMBuffer?
    private let normalClick: AVAudioPCMBuffer?

    private let timerQueue = DispatchQueue(label: "space-time.metronome", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var tick = 0

    #if canImport(UIKit)
    private let accentHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let normalHaptic = UIImpactFeedbackGenerator(style: .rigid)
    #endif

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        accentClick = format.flatMap { Self.click(format: $0, frequency: 1_600, seconds: 0.05) }
        normalClick = format.flatMap { Self.click(format: $0, frequency: 1_000, seconds: 0.04) }
        if let format {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
    }

    func toggle() { isRunning ? stop() : start() }

    func start() {
        guard !isRunning else { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
        do { try engine.start() } catch { return }
        player.play()
        #if canImport(UIKit)
        accentHaptic.prepare()
        normalHaptic.prepare()
        #endif
        tick = 0
        isRunning = true
        fire()               // downbeat immediately, then schedule the rest
        scheduleTimer()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        player.stop()
        engine.pause()
        isRunning = false
        beat = 0
    }

    private func scheduleTimer() {
        timer?.cancel()
        let interval = 60.0 / max(bpm, 1)
        let source = DispatchSource.makeTimerSource(queue: timerQueue)
        source.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(1))
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async { self?.fire() }
        }
        source.resume()
        timer = source
    }

    private func fire() {
        guard isRunning else { return }
        let isAccent = tick % beatsPerBar == 0
        if let buffer = isAccent ? accentClick : normalClick {
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
        #if canImport(UIKit)
        (isAccent ? accentHaptic : normalHaptic).impactOccurred()
        #endif
        beat = tick % beatsPerBar
        tick += 1
    }

    /// A short decaying sine — a clean, unobtrusive click.
    private static func click(format: AVAudioFormat, frequency: Double, seconds: Double) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = frames
        for frame in 0..<Int(frames) {
            let t = Double(frame) / format.sampleRate
            let sample = Float(sin(2 * .pi * frequency * t) * exp(-t * 40) * 0.5)
            for channel in 0..<Int(format.channelCount) {
                channels[channel][frame] = sample
            }
        }
        return buffer
    }
}
