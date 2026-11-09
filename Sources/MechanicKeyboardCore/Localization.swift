import Foundation

public enum ResolvedLanguage: String, CaseIterable, Equatable, Sendable {
    case en = "en"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
}

public enum AppLanguage: String, CaseIterable, Equatable, Sendable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    public static let defaultsKey = "appLanguage"

    public static let manualCases: [AppLanguage] = [
        .english,
        .simplifiedChinese,
        .traditionalChinese
    ]

    public static func load(from defaults: UserDefaults = .standard) -> AppLanguage {
        guard
            let raw = defaults.string(forKey: defaultsKey),
            let language = AppLanguage(rawValue: raw)
        else {
            return .system
        }
        return language
    }

    public func save(to defaults: UserDefaults = .standard) {
        if self == .system {
            defaults.removeObject(forKey: Self.defaultsKey)
        } else {
            defaults.set(rawValue, forKey: Self.defaultsKey)
        }
    }

    public static func resolvedLanguage(
        from defaults: UserDefaults = .standard,
        preferredLanguages: [String] = systemPreferredLanguages()
    ) -> ResolvedLanguage {
        load(from: defaults).resolved(preferredLanguages: preferredLanguages)
    }

    public static func systemPreferredLanguages() -> [String] {
        if let global = CFPreferencesCopyAppValue("AppleLanguages" as CFString, kCFPreferencesAnyApplication) as? [String],
           !global.isEmpty {
            return global
        }
        return Locale.preferredLanguages
    }

    public func resolved(preferredLanguages: [String] = systemPreferredLanguages()) -> ResolvedLanguage {
        switch self {
        case .english:
            return .en
        case .simplifiedChinese:
            return .zhHans
        case .traditionalChinese:
            return .zhHant
        case .system:
            for rawTag in preferredLanguages {
                let tag = rawTag.lowercased()
                if tag.hasPrefix("en") {
                    return .en
                }
                if tag.hasPrefix("zh") {
                    if tag.contains("hant") || tag.contains("-tw") || tag.contains("_tw") ||
                       tag.contains("-hk") || tag.contains("_hk") || tag.contains("-mo") || tag.contains("_mo") {
                        return .zhHant
                    }
                    return .zhHans
                }
            }
            return .en
        }
    }
}

public enum SoundSourceDescriptor: Equatable, Sendable {
    case builtIn
    case file(String)
    case multipleCustom(Int)
}

public struct L10n: Sendable {
    public let language: ResolvedLanguage

    public init(language: ResolvedLanguage) {
        self.language = language
    }

    public func toggleSound(enabled: Bool) -> String {
        switch (language, enabled) {
        case (.en, true):
            return "Disable Sound"
        case (.en, false):
            return "Enable Sound"
        case (.zhHans, true):
            return "关闭按键音"
        case (.zhHans, false):
            return "开启按键音"
        case (.zhHant, true):
            return "關閉按鍵音"
        case (.zhHant, false):
            return "開啟按鍵音"
        }
    }

    public func permissionStatus(granted: Bool) -> String {
        switch (language, granted) {
        case (.en, true):
            return "Input Monitoring: Granted"
        case (.en, false):
            return "Grant Input Monitoring..."
        case (.zhHans, true):
            return "输入监控：已授权"
        case (.zhHans, false):
            return "授权输入监控..."
        case (.zhHant, true):
            return "輸入監控：已授權"
        case (.zhHant, false):
            return "授權輸入監控..."
        }
    }

    public func monitorStatus(active: Bool) -> String {
        switch (language, active) {
        case (.en, true):
            return "Keyboard Monitor: Active"
        case (.en, false):
            return "Keyboard Monitor: Waiting"
        case (.zhHans, true):
            return "键盘监听：工作中"
        case (.zhHans, false):
            return "键盘监听：等待中"
        case (.zhHant, true):
            return "鍵盤監聽：運作中"
        case (.zhHant, false):
            return "鍵盤監聽：等待中"
        }
    }

    public func keyEvents(_ count: Int) -> String {
        switch language {
        case .en:
            return "Key Events: \(count)"
        case .zhHans:
            return "按键次数：\(count)"
        case .zhHant:
            return "按鍵次數：\(count)"
        }
    }

    public var volumeLabel: String {
        switch language {
        case .en:
            return "Volume"
        case .zhHans, .zhHant:
            return "音量"
        }
    }

    public func soundSourceName(for source: SoundSourceDescriptor) -> String {
        switch (language, source) {
        case (.en, .builtIn):
            return "Built-in"
        case (.zhHans, .builtIn):
            return "内置音效"
        case (.zhHant, .builtIn):
            return "內置音效"
        case (_, .file(let name)):
            return name
        case (.en, .multipleCustom(let count)):
            return "\(count) custom sounds"
        case (.zhHans, .multipleCustom(let count)):
            return "\(count) 个自定义音效"
        case (.zhHant, .multipleCustom(let count)):
            return "\(count) 個自訂音效"
        }
    }

    public func soundTitle(for source: SoundSourceDescriptor) -> String {
        let name = soundSourceName(for: source)
        switch language {
        case .en:
            return "Sound: \(name)"
        case .zhHans:
            return "当前音效：\(name)"
        case .zhHant:
            return "目前音效：\(name)"
        }
    }

    public var chooseSoundFiles: String {
        switch language {
        case .en:
            return "Choose Sound Files..."
        case .zhHans:
            return "选择音效文件..."
        case .zhHant:
            return "選擇音效檔案..."
        }
    }

    public var useBuiltInSound: String {
        switch language {
        case .en:
            return "Use Built-in Sound"
        case .zhHans:
            return "使用内置音效"
        case .zhHant:
            return "使用內置音效"
        }
    }

    public var languageMenuTitle: String {
        switch language {
        case .en:
            return "Language"
        case .zhHans:
            return "语言"
        case .zhHant:
            return "語言"
        }
    }

    public func languageOptionTitle(_ option: AppLanguage) -> String {
        switch option {
        case .system:
            switch language {
            case .en:
                return "Follow System"
            case .zhHans:
                return "跟随系统"
            case .zhHant:
                return "跟隨系統"
            }
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        }
    }

    public var testClick: String {
        switch language {
        case .en:
            return "Test Click"
        case .zhHans:
            return "测试按键音"
        case .zhHant:
            return "測試按鍵音"
        }
    }

    public var quitApp: String {
        switch language {
        case .en:
            return "Quit Mechanic Keyboard"
        case .zhHans:
            return "退出 Mechanic Keyboard"
        case .zhHant:
            return "結束 Mechanic Keyboard"
        }
    }

    public var soundLoadErrorTitle: String {
        switch language {
        case .en:
            return "Could not load sound file"
        case .zhHans:
            return "无法加载音效文件"
        case .zhHant:
            return "無法載入音效檔案"
        }
    }
}
