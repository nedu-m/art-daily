import Foundation

/// Installs/uninstalls a launchd agent that opens the app once each day.
struct LaunchAgentManager {
    static let shared = LaunchAgentManager()

    private let label = "com.edu.art-daily"

    var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    func install(hour: Int, minute: Int) throws {
        let agentsDir = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)

        let appBundle = Bundle.main.bundleURL.path
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/ArtDaily", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", appBundle, "--args", "--set-wallpaper"],
            "StartCalendarInterval": ["Hour": min(max(hour, 0), 23), "Minute": min(max(minute, 0), 59)],
            "RunAtLoad": false,
            "StandardOutPath": logDir.appendingPathComponent("9am.log").path,
            "StandardErrorPath": logDir.appendingPathComponent("9am.log").path,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)

        let uid = getuid()
        _ = try? run("/bin/launchctl", ["bootout", "gui/\(uid)", plistURL.path], allowFailure: true)
        try run("/bin/launchctl", ["bootstrap", "gui/\(uid)", plistURL.path])
    }

    func uninstall() throws {
        let uid = getuid()
        _ = try? run("/bin/launchctl", ["bootout", "gui/\(uid)", plistURL.path], allowFailure: true)
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    @discardableResult
    private func run(_ executable: String, _ arguments: [String], allowFailure: Bool = false) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard allowFailure || process.terminationStatus == 0 else {
            throw NSError(
                domain: "ArtDaily.LaunchAgent",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "launchctl failed with status \(process.terminationStatus)." : output]
            )
        }
        return output
    }
}
