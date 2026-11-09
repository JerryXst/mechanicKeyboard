import XCTest
@testable import MechanicKeyboardCore

final class ClickMixerTests: XCTestCase {
    func testScheduledClickIsRenderedInOrder() {
        let click = SampleBuffer([0.25, -0.5, 0.75])
        let mixer = ClickMixer(voiceCount: 4)
        mixer.trigger(owner: click, samples: click.samples, frameCount: click.frameCount)

        let rendered = render(mixer, frameCount: 3)

        assertSamples(rendered, [0.25, -0.5, 0.75])
        XCTAssertEqual(mixer.activeVoiceCount, 0)
    }

    func testOverlappingClicksMixUntilThePoolStealsTheOldestVoice() {
        let mixer = ClickMixer(voiceCount: 2)
        let first = SampleBuffer([0.1, 0.1, 0.1, 0.1])
        let second = SampleBuffer([0.2, 0.2, 0.2, 0.2])
        let newest = SampleBuffer([0.4])
        mixer.trigger(owner: first, samples: first.samples, frameCount: first.frameCount)
        mixer.trigger(owner: second, samples: second.samples, frameCount: second.frameCount)
        mixer.trigger(owner: newest, samples: newest.samples, frameCount: newest.frameCount)

        let rendered = render(mixer, frameCount: 1)

        assertSamples(rendered, [0.6])
        XCTAssertEqual(mixer.activeVoiceCount, 1)
    }

    func testGainScalesEveryVoice() {
        let mixer = ClickMixer(voiceCount: 2)
        mixer.gain = 0.5
        let click = SampleBuffer([1, -1])
        mixer.trigger(owner: click, samples: click.samples, frameCount: click.frameCount)

        let rendered = render(mixer, frameCount: 2)

        assertSamples(rendered, [0.5, -0.5])
    }

    func testRapidTriggersStayInsideTheVoicePool() {
        let mixer = ClickMixer(voiceCount: 8)
        let click = SampleBuffer(Array(repeating: 0.2, count: 256))
        let elapsed = ContinuousClock().measure {
            for _ in 0..<100_000 {
                mixer.trigger(owner: click, samples: click.samples, frameCount: click.frameCount)
            }
        }

        XCTAssertLessThanOrEqual(mixer.activeVoiceCount, 8)
        XCTAssertLessThan(elapsed, .seconds(1))
    }

    func testResetDropsActiveClicks() {
        let mixer = ClickMixer(voiceCount: 2)
        let click = SampleBuffer([0.3, 0.3, 0.3])
        mixer.trigger(owner: click, samples: click.samples, frameCount: click.frameCount)
        mixer.reset()

        let rendered = render(mixer, frameCount: 3)

        assertSamples(rendered, [0, 0, 0])
        XCTAssertEqual(mixer.activeVoiceCount, 0)
    }

    private func assertSamples(_ actual: [Float], _ expected: [Float], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (index, value) in actual.enumerated() where index < expected.count {
            XCTAssertEqual(Double(value), Double(expected[index]), accuracy: 0.0001, file: file, line: line)
        }
    }

    private func render(_ mixer: ClickMixer, frameCount: Int) -> [Float] {
        var output = [Float](repeating: -5, count: frameCount)
        output.withUnsafeMutableBufferPointer { buffer in
            _ = mixer.render(into: buffer.baseAddress!, frameCount: frameCount)
        }
        return output
    }
}

private final class SampleBuffer {
    let frameCount: Int
    private let storage: UnsafeMutablePointer<Float>
    var samples: UnsafePointer<Float> { UnsafePointer(storage) }

    init(_ values: [Float]) {
        frameCount = values.count
        storage = .allocate(capacity: max(values.count, 1))
        for (index, value) in values.enumerated() {
            storage[index] = value
        }
    }

    deinit {
        storage.deallocate()
    }
}
