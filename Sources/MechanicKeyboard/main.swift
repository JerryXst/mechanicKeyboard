import AppKit
import AVFoundation
import ApplicationServices
import UniformTypeIdentifiers

private let keyboardEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let eventTap = KeyboardEventState.eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

    KeyboardEventState.inputHandler?.handleKeyDown(keyCode: keyCode, isRepeat: isRepeat)

    return Unmanaged.passUnretained(event)
}

private enum KeyboardEventState {
    nonisolated(unsafe) static var inputHandler: KeyboardInputHandler?
    nonisolated(unsafe) static var eventTap: CFMachPort?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var keyboardSound: KeyboardSoundEngine!
    private var inputHandler: KeyboardInputHandler!
    private var eventTap: CFMachPort?
    private var eventRunLoopSource: CFRunLoopSource?
    private var monitorRetryTimer: Timer?
    private var lastMonitorIsActive = false
    private var enabled = UserDefaults.standard.object(forKey: Defaults.enabled) as? Bool ?? true
    private var volume = UserDefaults.standard.object(forKey: Defaults.volume) as? Double ?? 0.55

    var currentEventTap: CFMachPort? {
        eventTap
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        keyboardSound = KeyboardSoundEngine(volume: Float(volume), customSoundPaths: UserDefaults.standard.stringArray(forKey: Defaults.customSoundPaths))
        inputHandler = KeyboardInputHandler(soundEngine: keyboardSound, enabled: enabled)
        KeyboardEventState.inputHandler = inputHandler
        setupMenuBar()
        installKeyboardEventTap()
        startMonitorRetryTimer()
        refreshPermissionStatus()
        debugLog("Launched. inputMonitoring=\(hasRequiredPermissions()) monitorActive=\(monitorIsActive)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        KeyboardEventState.eventTap = nil
        KeyboardEventState.inputHandler = nil
        if let eventRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventRunLoopSource, .commonModes)
        }
        monitorRetryTimer?.invalidate()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⌨︎"
        statusItem.button?.toolTip = "Mechanic Keyboard"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let toggleTitle = enabled ? "Disable Sound" : "Enable Sound"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let permissionItem = NSMenuItem(title: permissionTitle(), action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        let monitorItem = NSMenuItem(title: monitorTitle(), action: #selector(refreshPermissionStatus), keyEquivalent: "")
        monitorItem.target = self
        menu.addItem(monitorItem)

        let countItem = NSMenuItem(title: "Key Events: \(inputHandler.keyEventCount)", action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)

        menu.addItem(.separator())

        let volumeItem = NSMenuItem()
        volumeItem.view = VolumeControlView(value: volume) { [weak self] newValue in
            self?.setVolume(newValue)
        }
        menu.addItem(volumeItem)

        menu.addItem(.separator())

        let soundTitle = "Sound: \(keyboardSound.soundName)"
        let soundItem = NSMenuItem(title: soundTitle, action: nil, keyEquivalent: "")
        soundItem.isEnabled = false
        menu.addItem(soundItem)

        let chooseSoundItem = NSMenuItem(title: "Choose Sound Files...", action: #selector(chooseSoundFiles), keyEquivalent: "")
        chooseSoundItem.target = self
        menu.addItem(chooseSoundItem)

        let resetSoundItem = NSMenuItem(title: "Use Built-in Sound", action: #selector(useBuiltInSound), keyEquivalent: "")
        resetSoundItem.target = self
        menu.addItem(resetSoundItem)

        menu.addItem(.separator())

        let testItem = NSMenuItem(title: "Test Click", action: #selector(playTestClick), keyEquivalent: "")
        testItem.target = self
        menu.addItem(testItem)

        let quitItem = NSMenuItem(title: "Quit Mechanic Keyboard", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.contentTintColor = monitorIsActive ? nil : .systemOrange
    }

    private func installKeyboardEventTap() {
        guard eventTap == nil else {
            return
        }

        debugLog("Installing keyboard event tap. inputMonitoring=\(hasRequiredPermissions())")
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: keyboardEventCallback,
            userInfo: nil
        )

        guard let eventTap else {
            debugLog("Failed to create keyboard event tap. Grant Input Monitoring permission, then restart or wait for retry.")
            return
        }

        KeyboardEventState.eventTap = eventTap
        eventRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let eventRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), eventRunLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        lastMonitorIsActive = monitorIsActive
        debugLog("Keyboard event tap installed. monitorActive=\(monitorIsActive)")
        rebuildMenu()
    }

    @objc private func refreshPermissionStatus() {
        if hasRequiredPermissions() {
            installKeyboardEventTap()
        } else {
            requestAccessibilityPermission()
        }
        rebuildMenu()
    }

    private func permissionTitle() -> String {
        hasRequiredPermissions() ? "Input Monitoring: Granted" : "Grant Input Monitoring..."
    }

    private func monitorTitle() -> String {
        monitorIsActive ? "Keyboard Monitor: Active" : "Keyboard Monitor: Waiting"
    }

    private var monitorIsActive: Bool {
        guard let eventTap else {
            return false
        }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    private func hasRequiredPermissions() -> Bool {
        CGPreflightListenEventAccess()
    }

    private func requestAccessibilityPermission() {
        CGRequestListenEventAccess()
    }

    private func startMonitorRetryTimer() {
        monitorRetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }
                if self.eventTap == nil, self.hasRequiredPermissions() {
                    self.installKeyboardEventTap()
                }
                let monitorIsActive = self.monitorIsActive
                if monitorIsActive != self.lastMonitorIsActive {
                    self.lastMonitorIsActive = monitorIsActive
                    self.rebuildMenu()
                }
            }
        }
    }

    private func debugLog(_ message: String) {
        NSLog("[MechanicKeyboard] %@", message)
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        UserDefaults.standard.set(enabled, forKey: Defaults.enabled)
        inputHandler.enabled = enabled
        rebuildMenu()
    }

    @objc private func openAccessibilitySettings() {
        requestAccessibilityPermission()
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refreshPermissionStatus()
        }
    }

    @objc private func playTestClick() {
        keyboardSound.play(for: 0)
    }

    @objc private func chooseSoundFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff, .mpeg4Audio]

        guard panel.runModal() == .OK, !panel.urls.isEmpty else {
            return
        }

        do {
            try keyboardSound.useCustomSounds(urls: panel.urls)
            UserDefaults.standard.set(panel.urls.map(\.path), forKey: Defaults.customSoundPaths)
            rebuildMenu()
        } catch {
            showSoundLoadError(error)
        }
    }

    @objc private func useBuiltInSound() {
        keyboardSound.useBuiltInSound()
        UserDefaults.standard.removeObject(forKey: Defaults.customSoundPaths)
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setVolume(_ newValue: Double) {
        volume = min(max(newValue, 0), 1)
        UserDefaults.standard.set(volume, forKey: Defaults.volume)
        keyboardSound.volume = Float(volume)
    }

    private func showSoundLoadError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not load sound file"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}

private enum Defaults {
    static let enabled = "soundEnabled"
    static let volume = "volume"
    static let customSoundPaths = "customSoundPaths"
}

private final class KeyboardInputHandler: @unchecked Sendable {
    var enabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return isEnabled
        }
        set {
            lock.lock()
            isEnabled = newValue
            lock.unlock()
        }
    }

    var keyEventCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    private let soundEngine: KeyboardSoundEngine
    private let lock = NSLock()
    private var isEnabled: Bool
    private var count = 0

    init(soundEngine: KeyboardSoundEngine, enabled: Bool) {
        self.soundEngine = soundEngine
        self.isEnabled = enabled
    }

    func handleKeyDown(keyCode: UInt16, isRepeat: Bool) {
        lock.lock()
        let shouldPlay = isEnabled && !isRepeat
        if shouldPlay {
            count += 1
        }
        lock.unlock()

        guard shouldPlay else {
            return
        }
        soundEngine.play(for: keyCode)
    }
}

private final class VolumeControlView: NSView {
    private let slider: NSSlider
    private let label: NSTextField
    private let onChange: (Double) -> Void

    init(value: Double, onChange: @escaping (Double) -> Void) {
        self.slider = NSSlider(value: value, minValue: 0, maxValue: 1, target: nil, action: nil)
        self.label = NSTextField(labelWithString: "Volume")
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 230, height: 42))

        label.frame = NSRect(x: 16, y: 13, width: 58, height: 17)
        slider.frame = NSRect(x: 76, y: 9, width: 138, height: 24)
        slider.target = self
        slider.action = #selector(volumeChanged)

        addSubview(label)
        addSubview(slider)
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func volumeChanged() {
        onChange(slider.doubleValue)
    }
}

private final class KeyboardSoundEngine: @unchecked Sendable {
    var volume: Float {
        get {
            lock.lock()
            defer { lock.unlock() }
            return currentVolume
        }
        set {
            lock.lock()
            currentVolume = newValue
            voices.forEach { $0.node.volume = newValue }
            lock.unlock()
        }
    }

    var soundName: String {
        lock.lock()
        defer { lock.unlock() }
        return sourceName
    }

    private let lock = NSRecursiveLock()
    private let engine = AVAudioEngine()
    private let voiceMixer = AVAudioMixerNode()
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffersByKind: [SoundKind: [AVAudioPCMBuffer]] = [:]
    private var voices: [PlaybackVoice] = []
    private var bufferCursor: [SoundKind: Int] = [:]
    private var voiceCursor = 0
    private var currentVolume: Float
    private var sourceName = "Built-in"
    private var usesRandomCustomSounds = false

    init(volume: Float, customSoundPaths: [String]?) {
        self.currentVolume = volume
        installPlaybackVoices()
        if let customSoundPaths, !customSoundPaths.isEmpty {
            let urls = customSoundPaths.map { URL(fileURLWithPath: $0) }
            do {
                try prepareCustomPlayers(urls: urls)
            } catch {
                prepareBuiltInPlayers()
            }
        } else {
            prepareBuiltInPlayers()
        }
    }

    func play(for keyCode: UInt16) {
        lock.lock()
        defer { lock.unlock() }

        let kind = SoundKind(keyCode: keyCode)
        guard let buffers = buffersByKind[kind], !buffers.isEmpty, !voices.isEmpty else {
            return
        }
        startEngineIfNeeded()

        let buffer = nextBuffer(from: buffers, for: kind)
        let voice = nextVoice()
        if voice.node.isPlaying {
            voice.node.stop()
        }
        voice.node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        voice.node.play()
    }

    private func nextBuffer(from buffers: [AVAudioPCMBuffer], for kind: SoundKind) -> AVAudioPCMBuffer {
        if usesRandomCustomSounds {
            return buffers[Int.random(in: 0..<buffers.count)]
        }

        let index = bufferCursor[kind, default: 0] % buffers.count
        bufferCursor[kind] = index + 1
        return buffers[index]
    }

    private func nextVoice() -> PlaybackVoice {
        let start = voiceCursor % voices.count
        for offset in 0..<voices.count {
            let index = (start + offset) % voices.count
            if !voices[index].node.isPlaying {
                voiceCursor = index + 1
                return voices[index]
            }
        }

        let index = start
        voiceCursor = index + 1
        return voices[index]
    }

    func useCustomSounds(urls: [URL]) throws {
        lock.lock()
        defer { lock.unlock() }
        try prepareCustomPlayers(urls: urls)
    }

    func useBuiltInSound() {
        lock.lock()
        defer { lock.unlock() }
        prepareBuiltInPlayers()
    }

    private func prepareBuiltInPlayers() {
        if let defaultSoundURL, let defaultBuffer = try? loadSoundBuffer(url: defaultSoundURL) {
            buffersByKind = Dictionary(uniqueKeysWithValues: SoundKind.allCases.map { kind in
                (kind, [defaultBuffer])
            })
            bufferCursor.removeAll(keepingCapacity: true)
            sourceName = defaultSoundURL.lastPathComponent
            usesRandomCustomSounds = false
            return
        }

        let nextBuffers = Dictionary(uniqueKeysWithValues: SoundKind.allCases.map { kind in
            (kind, (0..<24).compactMap { variant in
                WaveFactory.makeClickBuffer(kind: kind, variant: variant)
            })
        })
        buffersByKind = nextBuffers
        bufferCursor.removeAll(keepingCapacity: true)
        sourceName = "Built-in"
        usesRandomCustomSounds = false
    }

    private func prepareCustomPlayers(urls: [URL]) throws {
        let soundBuffers = try urls.map { url in
            (url: url, buffer: try loadSoundBuffer(url: url))
        }

        var nextBuffers: [SoundKind: [AVAudioPCMBuffer]] = [:]
        for kind in SoundKind.allCases {
            var pool: [AVAudioPCMBuffer] = []
            for item in soundBuffers {
                pool.append(item.buffer)
            }
            nextBuffers[kind] = pool
        }
        buffersByKind = nextBuffers
        bufferCursor.removeAll(keepingCapacity: true)
        usesRandomCustomSounds = true
        sourceName = soundBuffers.count == 1 ? soundBuffers[0].url.lastPathComponent : "\(soundBuffers.count) custom sounds"
    }

    private func installPlaybackVoices() {
        engine.attach(voiceMixer)
        engine.connect(voiceMixer, to: engine.mainMixerNode, format: audioFormat)

        let voiceCount = 12
        voices = (0..<voiceCount).map { index in
            let node = AVAudioPlayerNode()
            node.volume = currentVolume
            engine.attach(node)
            engine.connect(node, to: voiceMixer, fromBus: 0, toBus: index, format: audioFormat)
            return PlaybackVoice(node: node)
        }
        engine.prepare()
        startEngineIfNeeded()
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else {
            return
        }
        do {
            try engine.start()
        } catch {
            NSLog("[MechanicKeyboard] Could not start audio engine: %@", error.localizedDescription)
        }
    }

    private func loadSoundBuffer(url: URL) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let frameCapacity = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCapacity) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try file.read(into: buffer)
        return trimLeadingSilence(from: try convertToPlaybackFormat(buffer))
    }

    private func convertToPlaybackFormat(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        if buffer.format == audioFormat {
            return buffer
        }

        guard let converter = AVAudioConverter(from: buffer.format, to: audioFormat) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let sampleRateRatio = audioFormat.sampleRate / buffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount((Double(buffer.frameLength) * sampleRateRatio).rounded(.up)) + 512
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCapacity) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let input = AudioConversionInput(buffer: buffer)
        var conversionError: NSError?
        converter.convert(to: convertedBuffer, error: &conversionError) { _, status in
            if input.didProvideInput {
                status.pointee = .endOfStream
                return nil
            }

            input.didProvideInput = true
            status.pointee = .haveData
            return input.buffer
        }

        if let conversionError {
            throw conversionError
        }
        guard convertedBuffer.frameLength > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return convertedBuffer
    }

    private func trimLeadingSilence(from buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard
            !buffer.format.isInterleaved,
            buffer.format.commonFormat == .pcmFormatFloat32,
            let sourceChannels = buffer.floatChannelData
        else {
            return buffer
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        let threshold: Float = 0.002
        var firstAudibleFrame = 0

        frameSearch: for frame in 0..<frameLength {
            for channel in 0..<channelCount where abs(sourceChannels[channel][frame]) > threshold {
                firstAudibleFrame = frame
                break frameSearch
            }
        }

        guard firstAudibleFrame > 0, firstAudibleFrame < frameLength else {
            return buffer
        }

        let trimmedFrameLength = frameLength - firstAudibleFrame
        guard let trimmed = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: AVAudioFrameCount(trimmedFrameLength)
        ), let targetChannels = trimmed.floatChannelData else {
            return buffer
        }

        trimmed.frameLength = AVAudioFrameCount(trimmedFrameLength)
        for channel in 0..<channelCount {
            for frame in 0..<trimmedFrameLength {
                targetChannels[channel][frame] = sourceChannels[channel][frame + firstAudibleFrame]
            }
        }
        return trimmed
    }

    private var defaultSoundURL: URL? {
        let relativePath = "sounds/default.wav"
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent(relativePath),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }

        if let resourceURL = Bundle.main.url(forResource: "default", withExtension: "wav") {
            return resourceURL
        }

        let workingDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: workingDirectoryURL.path) {
            return workingDirectoryURL
        }

        return nil
    }
}

private struct PlaybackVoice {
    let node: AVAudioPlayerNode
}

private final class AudioConversionInput: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    var didProvideInput = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
}

private enum SoundKind: CaseIterable, Hashable {
    case normal
    case space
    case modifier
    case delete
    case enter

    init(keyCode: UInt16) {
        switch keyCode {
        case 49:
            self = .space
        case 36, 76:
            self = .enter
        case 51, 117:
            self = .delete
        case 54...58, 59...63:
            self = .modifier
        default:
            self = .normal
        }
    }
}

private enum WaveFactory {
    static func makeClickBuffer(kind: SoundKind, variant: Int) -> AVAudioPCMBuffer? {
        let sampleRate = 44_100
        let duration: Double
        let baseFrequency: Double
        let brightness: Double

        switch kind {
        case .normal:
            duration = 0.052
            baseFrequency = 2_800
            brightness = 0.9
        case .space:
            duration = 0.075
            baseFrequency = 1_700
            brightness = 0.65
        case .modifier:
            duration = 0.046
            baseFrequency = 2_200
            brightness = 0.7
        case .delete:
            duration = 0.058
            baseFrequency = 2_450
            brightness = 0.85
        case .enter:
            duration = 0.068
            baseFrequency = 1_950
            brightness = 0.75
        }

        let frames = Int(Double(sampleRate) * duration)
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
            let channel = buffer.floatChannelData?[0]
        else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frames)

        for frame in 0..<frames {
            let t = Double(frame) / Double(sampleRate)
            let progress = Double(frame) / Double(frames)
            let attack = min(progress / 0.012, 1)
            let decay = exp(-progress * 12)
            let variantOffset = Double((variant % 5) - 2) * 42
            let noise = deterministicNoise(frame: frame, variant: variant)
            let snap = sin(2 * .pi * (baseFrequency + variantOffset) * t)
            let body = sin(2 * .pi * (baseFrequency * 0.42 + variantOffset) * t)
            let signal = (snap * brightness + body * 0.35 + noise * 0.55) * attack * decay
            channel[frame] = Float(max(-1, min(1, signal)) * 0.74)
        }

        return buffer
    }

    private static func deterministicNoise(frame: Int, variant: Int) -> Double {
        var value = UInt64(frame &* 1_103_515_245 &+ variant &* 12_345)
        value ^= value >> 13
        value &*= 0x5DEECE66D
        let normalized = Double(value & 0xffff) / 32_767.5 - 1
        return normalized
    }
}

@main
enum MechanicKeyboardApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
