import XCTest
@testable import MechanicKeyboardCore

final class LocalizationTests: XCTestCase {
    func testSystemLanguageResolvesSimplifiedAndTraditionalChineseAndDefaultsToEnglish() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en-US"]), .zhHans)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-CN"]), .zhHans)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-HK", "en-US"]), .zhHant)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-TW"]), .zhHant)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-MO"]), .zhHant)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["ja-JP", "zh-Hant-TW"]), .zhHant)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["en-US", "zh-Hans-CN"]), .en)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]), .en)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), .en)
    }

    func testExplicitLanguageOverridesPreferredLanguages() {
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["zh-Hans-CN"]), .en)
        XCTAssertEqual(AppLanguage.simplifiedChinese.resolved(preferredLanguages: ["en-US"]), .zhHans)
        XCTAssertEqual(AppLanguage.traditionalChinese.resolved(preferredLanguages: ["en-US"]), .zhHant)
    }

    func testLanguagePreferenceFollowsSystemUntilUserManuallySelectsLanguage() {
        let suiteName = "LocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // 1. Default on launch (never manually set): follows system language
        XCTAssertEqual(AppLanguage.load(from: defaults), .system)
        XCTAssertEqual(
            AppLanguage.resolvedLanguage(from: defaults, preferredLanguages: ["zh-Hans-CN", "en-US"]),
            .zhHans
        )
        XCTAssertEqual(
            AppLanguage.resolvedLanguage(from: defaults, preferredLanguages: ["zh-Hant-TW", "en-US"]),
            .zhHant
        )

        // 2. Once user manually sets English, subsequent launches always use English regardless of system locale
        AppLanguage.english.save(to: defaults)
        XCTAssertEqual(AppLanguage.load(from: defaults), .english)
        XCTAssertEqual(
            AppLanguage.resolvedLanguage(from: defaults, preferredLanguages: ["zh-Hans-CN", "en-US"]),
            .en
        )

        // 3. User switches to Traditional Chinese; persists across launches
        AppLanguage.traditionalChinese.save(to: defaults)
        XCTAssertEqual(AppLanguage.load(from: defaults), .traditionalChinese)
        XCTAssertEqual(
            AppLanguage.resolvedLanguage(from: defaults, preferredLanguages: ["en-US"]),
            .zhHant
        )
    }

    func testLocalizedStringsAndSoundSourceFormattingAcrossAllThreeLanguages() {
        let en = L10n(language: .en)
        let hans = L10n(language: .zhHans)
        let hant = L10n(language: .zhHant)

        XCTAssertEqual(en.toggleSound(enabled: true), "Disable Sound")
        XCTAssertEqual(hans.toggleSound(enabled: true), "关闭按键音")
        XCTAssertEqual(hant.toggleSound(enabled: true), "關閉按鍵音")

        XCTAssertEqual(en.toggleSound(enabled: false), "Enable Sound")
        XCTAssertEqual(hans.toggleSound(enabled: false), "开启按键音")
        XCTAssertEqual(hant.toggleSound(enabled: false), "開啟按鍵音")

        XCTAssertEqual(en.keyEvents(42), "Key Events: 42")
        XCTAssertEqual(hans.keyEvents(42), "按键次数：42")
        XCTAssertEqual(hant.keyEvents(42), "按鍵次數：42")

        XCTAssertEqual(en.soundTitle(for: .builtIn), "Sound: Built-in")
        XCTAssertEqual(hans.soundTitle(for: .builtIn), "当前音效：内置音效")
        XCTAssertEqual(hant.soundTitle(for: .builtIn), "目前音效：內置音效")

        XCTAssertEqual(en.soundTitle(for: .file("click.wav")), "Sound: click.wav")
        XCTAssertEqual(hans.soundTitle(for: .file("click.wav")), "当前音效：click.wav")
        XCTAssertEqual(hant.soundTitle(for: .file("click.wav")), "目前音效：click.wav")

        XCTAssertEqual(en.soundTitle(for: .multipleCustom(3)), "Sound: 3 custom sounds")
        XCTAssertEqual(hans.soundTitle(for: .multipleCustom(3)), "当前音效：3 个自定义音效")
        XCTAssertEqual(hant.soundTitle(for: .multipleCustom(3)), "目前音效：3 個自訂音效")
    }
}
