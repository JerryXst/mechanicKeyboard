import Foundation

/// Fixed-size mixer for one-shot clicks.
///
/// `trigger` only retains the sample owner and arms a voice. It must not call into
/// the audio device. Doing that from the main-thread event tap is what froze the
/// app: `AVAudioPlayerNode.play()` waits in `awaitIOCycle`, and `stop()` does a
/// synchronous HAL round trip. After sleep or a long uptime those waits never
/// return, so the run loop never processes the status item again.
public final class ClickMixer: @unchecked Sendable {
    private struct Voice {
        var owner: AnyObject?
        var samples: UnsafePointer<Float>?
        var frameCount = 0
        var cursor = 0
        var startedAt: UInt64 = 0
        var isActive = false
    }

    private let lock = NSLock()
    private var voices: [Voice]
    private var sequence: UInt64 = 0
    private var storedGain: Float = 1

    public init(voiceCount: Int = 16) {
        voices = Array(repeating: Voice(), count: max(1, voiceCount))
    }

    public var gain: Float {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedGain
        }
        set {
            lock.lock()
            storedGain = newValue
            lock.unlock()
        }
    }

    public var activeVoiceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return voices.reduce(into: 0) { count, voice in
            if voice.isActive {
                count += 1
            }
        }
    }

    public func trigger(owner: AnyObject, samples: UnsafePointer<Float>, frameCount: Int) {
        guard frameCount > 0 else {
            return
        }

        lock.lock()
        sequence += 1
        let index = idleVoiceIndex() ?? oldestVoiceIndex()
        voices[index] = Voice(
            owner: owner,
            samples: samples,
            frameCount: frameCount,
            cursor: 0,
            startedAt: sequence,
            isActive: true
        )
        lock.unlock()
    }

    /// Writes one render quantum. Returns whether any audible sample was produced.
    /// The sample owner stays retained until a later `trigger` or `reset` replaces
    /// the voice, so this method does not release objects on the audio thread.
    @discardableResult
    public func render(into buffer: UnsafeMutablePointer<Float>, frameCount: Int) -> Bool {
        guard frameCount > 0 else {
            return false
        }

        lock.lock()
        let gain = storedGain
        var audible = false
        for frame in 0..<frameCount {
            var mixed: Float = 0
            for index in voices.indices where voices[index].isActive {
                let cursor = voices[index].cursor
                mixed += (voices[index].samples?[cursor] ?? 0) * gain
                let next = cursor + 1
                voices[index].cursor = next
                if next >= voices[index].frameCount {
                    voices[index].isActive = false
                }
            }
            if mixed > 1 {
                mixed = 1
            } else if mixed < -1 {
                mixed = -1
            }
            if mixed != 0 {
                audible = true
            }
            buffer[frame] = mixed
        }
        lock.unlock()
        return audible
    }

    public func reset() {
        lock.lock()
        for index in voices.indices {
            voices[index] = Voice()
        }
        lock.unlock()
    }

    private func idleVoiceIndex() -> Int? {
        voices.firstIndex { !$0.isActive }
    }

    private func oldestVoiceIndex() -> Int {
        var oldest = 0
        for index in voices.indices where voices[index].startedAt < voices[oldest].startedAt {
            oldest = index
        }
        return oldest
    }
}
