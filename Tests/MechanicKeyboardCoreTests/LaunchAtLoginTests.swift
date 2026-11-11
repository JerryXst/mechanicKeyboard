import XCTest
@testable import MechanicKeyboardCore

final class LaunchAtLoginTests: XCTestCase {
    func testDefaultStateIsDisabledWhenNoLaunchAgentExists() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchAtLoginTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = LaunchAtLoginManager(
            label: "com.jerryxst.mechanickeyboard",
            executablePath: "/Applications/MechanicKeyboard.app/Contents/MacOS/MechanicKeyboard",
            launchAgentsDirectory: tempDir
        )

        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: manager.plistURL.path))
    }

    func testEnablingWritesValidLaunchAgentPlistAndDisablingRemovesIt() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchAtLoginTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let executablePath = "/Applications/MechanicKeyboard.app/Contents/MacOS/MechanicKeyboard"
        let manager = LaunchAtLoginManager(
            label: "com.jerryxst.mechanickeyboard",
            executablePath: executablePath,
            launchAgentsDirectory: tempDir
        )

        try manager.setEnabled(true)

        XCTAssertTrue(manager.isEnabled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: manager.plistURL.path))

        let data = try Data(contentsOf: manager.plistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["Label"] as? String, "com.jerryxst.mechanickeyboard")
        XCTAssertEqual(plist["ProgramArguments"] as? [String], [executablePath])
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["KeepAlive"] as? Bool, false)

        try manager.setEnabled(false)

        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: manager.plistURL.path))
    }

    func testLocalizedLaunchAtLoginTitles() {
        XCTAssertEqual(L10n(language: .en).launchAtLogin, "Launch at Login")
        XCTAssertEqual(L10n(language: .zhHans).launchAtLogin, "开机自动启动")
        XCTAssertEqual(L10n(language: .zhHant).launchAtLogin, "開機自動啟動")
    }
}
