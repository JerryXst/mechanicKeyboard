import Foundation

public struct LaunchAtLoginManager: Sendable {
    public let label: String
    public let executablePath: String
    public let launchAgentsDirectory: URL

    public init(
        label: String = "com.jerryxst.mechanickeyboard",
        executablePath: String = Self.defaultExecutablePath(),
        launchAgentsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    ) {
        self.label = label
        self.executablePath = executablePath
        self.launchAgentsDirectory = launchAgentsDirectory
    }

    public var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist", isDirectory: false)
    }

    public var isEnabled: Bool {
        guard
            FileManager.default.fileExists(atPath: plistURL.path),
            let data = try? Data(contentsOf: plistURL),
            let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
        else {
            return false
        }
        return (plist["RunAtLoad"] as? Bool) ?? false
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try FileManager.default.createDirectory(
                at: launchAgentsDirectory,
                withIntermediateDirectories: true
            )
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executablePath],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive"
            ]
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: plistURL, options: .atomic)
        } else if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    public static func defaultExecutablePath() -> String {
        let installedPath = "/Applications/MechanicKeyboard.app/Contents/MacOS/MechanicKeyboard"
        if let bundleExecutable = Bundle.main.executablePath, !bundleExecutable.isEmpty {
            return bundleExecutable
        }
        if FileManager.default.fileExists(atPath: installedPath) {
            return installedPath
        }
        return CommandLine.arguments.first ?? installedPath
    }
}
