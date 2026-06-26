import AppKit
import Foundation
import Darwin

private let appName = "HideOnBush"

private enum Mode: String {
    case work = "Work"
    case personal = "Personal"
    case mixed = "Mixed"
}

private struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool {
        status == 0
    }
}

private enum CommandRunner {
    static func run(_ executable: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandResult(status: 127, stdout: "", stderr: error.localizedDescription)
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(
            status: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}

private struct StatusSnapshot {
    let profileEnabled: Bool
    let launchAgentInstalled: Bool
    let launchAgentLoaded: Bool
    let launchctlValues: [String: String]

    var launchctlEnabled: Bool {
        launchctlValues.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var mode: Mode {
        let activeCount = [profileEnabled, launchAgentInstalled, launchAgentLoaded, launchctlEnabled].filter { $0 }.count
        if activeCount == 0 {
            return .personal
        }
        if activeCount == 4 {
            return .work
        }
        return .mixed
    }
}

private final class TelemetryController {
    private let fileManager = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private let startMarker = "# === Claude Code OTel Telemetry START ==="
    private let endMarker = "# === Claude Code OTel Telemetry END ==="

    let trackedKeys = [
        "CLAUDE_CODE_ENABLE_TELEMETRY",
        "OTEL_METRICS_EXPORTER",
        "OTEL_LOGS_EXPORTER",
        "OTEL_EXPORTER_OTLP_PROTOCOL",
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "OTEL_METRIC_EXPORT_INTERVAL",
        "OTEL_LOGS_EXPORT_INTERVAL",
        "OTEL_LOG_USER_PROMPTS",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC",
        "OTEL_METRICS_INCLUDE_SESSION_ID",
        "OTEL_METRICS_INCLUDE_VERSION",
        "OTEL_METRICS_INCLUDE_ACCOUNT_UUID",
        "OTEL_RESOURCE_ATTRIBUTES"
    ]

    var profileURL: URL {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellName = URL(fileURLWithPath: shell).lastPathComponent
        switch shellName {
        case "bash":
            let bashProfile = home.appendingPathComponent(".bash_profile")
            if fileManager.fileExists(atPath: bashProfile.path) {
                return bashProfile
            }
            return home.appendingPathComponent(".bashrc")
        case "zsh":
            return home.appendingPathComponent(".zshrc")
        default:
            return home.appendingPathComponent(".zshrc")
        }
    }

    var launchAgentURL: URL {
        home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("com.megastudy.otel.plist")
    }

    private var supportDir: URL {
        home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)
    }

    private var shellBlockBackupURL: URL {
        supportDir.appendingPathComponent("claude-otel-shell-block.txt")
    }

    private var launchAgentBackupURL: URL {
        supportDir.appendingPathComponent("com.megastudy.otel.plist.backup")
    }

    func captureCurrentWorkConfigIfNeeded() throws {
        try ensureSupportDir()

        if let block = try readShellBlock(), !fileManager.fileExists(atPath: shellBlockBackupURL.path) {
            try block.write(to: shellBlockBackupURL, atomically: true, encoding: .utf8)
        }

        if fileManager.fileExists(atPath: launchAgentURL.path),
           !fileManager.fileExists(atPath: launchAgentBackupURL.path) {
            try fileManager.copyItem(at: launchAgentURL, to: launchAgentBackupURL)
        }
    }

    func status() -> StatusSnapshot {
        let profileEnabled = (try? readShellBlock()) != nil
        let launchAgentInstalled = fileManager.fileExists(atPath: launchAgentURL.path)
        let launchAgentLoaded = isLaunchAgentLoaded()
        var values: [String: String] = [:]

        for key in trackedKeys {
            let value = CommandRunner
                .run("/bin/launchctl", ["getenv", key])
                .stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }

        return StatusSnapshot(
            profileEnabled: profileEnabled,
            launchAgentInstalled: launchAgentInstalled,
            launchAgentLoaded: launchAgentLoaded,
            launchctlValues: values
        )
    }

    func enablePersonalMode() throws {
        try captureCurrentWorkConfigIfNeeded()
        try removeShellBlock()
        unloadLaunchAgent()
        try removeLaunchAgentFile()
        unsetLaunchctlEnvironment()
    }

    func enableWorkMode() throws {
        try ensureSupportDir()
        try restoreShellBlock()
        try restoreLaunchAgentFile()
        loadLaunchAgent()
        setLaunchctlEnvironmentFromWorkConfig()
    }

    func copyStatusToPasteboard() {
        let snapshot = status()
        let values = trackedKeys
            .map { "\($0)=\(snapshot.launchctlValues[$0] ?? "")" }
            .joined(separator: "\n")
        let text = """
        \(appName) Status
        Mode: \(snapshot.mode.rawValue)
        Shell profile: \(snapshot.profileEnabled ? "ON" : "OFF") (\(profileURL.path))
        LaunchAgent file: \(snapshot.launchAgentInstalled ? "ON" : "OFF") (\(launchAgentURL.path))
        LaunchAgent loaded: \(snapshot.launchAgentLoaded ? "ON" : "OFF")
        launchctl env:
        \(values)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func openProfile() {
        NSWorkspace.shared.open(profileURL)
    }

    func openLaunchAgentsFolder() {
        NSWorkspace.shared.open(launchAgentURL.deletingLastPathComponent())
    }

    private func ensureSupportDir() throws {
        try fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true)
    }

    private func readProfileText() throws -> String {
        if !fileManager.fileExists(atPath: profileURL.path) {
            return ""
        }
        return try String(contentsOf: profileURL, encoding: .utf8)
    }

    private func writeProfileText(_ text: String) throws {
        if !fileManager.fileExists(atPath: profileURL.path) {
            fileManager.createFile(atPath: profileURL.path, contents: nil)
        }
        try text.write(to: profileURL, atomically: true, encoding: .utf8)
    }

    private func readShellBlock() throws -> String? {
        let text = try readProfileText()
        guard let startRange = text.range(of: startMarker),
              let endRange = text.range(of: endMarker, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.upperBound])
    }

    private func removeShellBlock() throws {
        let text = try readProfileText()
        let cleaned = text.replacingOccurrences(
            of: "\\n?# === Claude Code OTel Telemetry START ===[\\s\\S]*?# === Claude Code OTel Telemetry END ===\\n?",
            with: "\n",
            options: .regularExpression
        )
        try writeProfileText(cleaned.trimmingTrailingWhitespaceAndNewlines() + "\n")
    }

    private func restoreShellBlock() throws {
        var text = try readProfileText()
        text = text.replacingOccurrences(
            of: "\\n?# === Claude Code OTel Telemetry START ===[\\s\\S]*?# === Claude Code OTel Telemetry END ===\\n?",
            with: "\n",
            options: .regularExpression
        ).trimmingTrailingWhitespaceAndNewlines()

        let block: String
        if fileManager.fileExists(atPath: shellBlockBackupURL.path) {
            block = try String(contentsOf: shellBlockBackupURL, encoding: .utf8)
        } else {
            block = synthesizedShellBlock()
        }

        let prefix = text.isEmpty ? "" : text + "\n\n"
        try writeProfileText(prefix + block.trimmingTrailingWhitespaceAndNewlines() + "\n")
    }

    private func removeLaunchAgentFile() throws {
        if fileManager.fileExists(atPath: launchAgentURL.path) {
            if !fileManager.fileExists(atPath: launchAgentBackupURL.path) {
                try ensureSupportDir()
                try fileManager.copyItem(at: launchAgentURL, to: launchAgentBackupURL)
            }
            try fileManager.removeItem(at: launchAgentURL)
        }
    }

    private func restoreLaunchAgentFile() throws {
        let launchAgentsDir = launchAgentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: launchAgentURL.path) {
            unloadLaunchAgent()
            try fileManager.removeItem(at: launchAgentURL)
        }

        if fileManager.fileExists(atPath: launchAgentBackupURL.path) {
            try fileManager.copyItem(at: launchAgentBackupURL, to: launchAgentURL)
        } else {
            try synthesizedLaunchAgentPlist()
                .write(to: launchAgentURL, atomically: true, encoding: .utf8)
        }
    }

    private func unloadLaunchAgent() {
        if fileManager.fileExists(atPath: launchAgentURL.path) {
            _ = CommandRunner.run("/bin/launchctl", ["bootout", "gui/\(getuid())", launchAgentURL.path])
            _ = CommandRunner.run("/bin/launchctl", ["unload", launchAgentURL.path])
        }
        _ = CommandRunner.run("/bin/launchctl", ["bootout", "gui/\(getuid())/com.megastudy.otel"])
    }

    private func loadLaunchAgent() {
        guard fileManager.fileExists(atPath: launchAgentURL.path) else {
            return
        }
        _ = CommandRunner.run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", launchAgentURL.path])
        _ = CommandRunner.run("/bin/launchctl", ["load", launchAgentURL.path])
    }

    private func isLaunchAgentLoaded() -> Bool {
        CommandRunner
            .run("/bin/launchctl", ["print", "gui/\(getuid())/com.megastudy.otel"])
            .succeeded
    }

    private func unsetLaunchctlEnvironment() {
        for key in trackedKeys {
            _ = CommandRunner.run("/bin/launchctl", ["unsetenv", key])
        }
    }

    private func setLaunchctlEnvironmentFromWorkConfig() {
        let values = workEnvironmentValues()
        for (key, value) in values {
            _ = CommandRunner.run("/bin/launchctl", ["setenv", key, value])
        }
    }

    private func workEnvironmentValues() -> [(String, String)] {
        var values: [(String, String)] = []

        if let plistCommand = launchAgentSetenvCommand() {
            values.append(contentsOf: parseLaunchctlSetenvCommands(plistCommand))
        }

        if values.isEmpty {
            values = defaultLaunchctlValues()
        }

        return values.filter { trackedKeys.contains($0.0) }
    }

    private func launchAgentSetenvCommand() -> String? {
        let sourceURL = fileManager.fileExists(atPath: launchAgentBackupURL.path)
            ? launchAgentBackupURL
            : launchAgentURL

        guard fileManager.fileExists(atPath: sourceURL.path),
              let plist = NSDictionary(contentsOf: sourceURL),
              let args = plist["ProgramArguments"] as? [String],
              args.count >= 3 else {
            return nil
        }
        return args[2]
    }

    private func parseLaunchctlSetenvCommands(_ command: String) -> [(String, String)] {
        command
            .split(separator: ";")
            .compactMap { part -> (String, String)? in
                let tokens = part
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(maxSplits: 3, whereSeparator: { $0 == " " || $0 == "\t" })
                    .map(String.init)

                guard tokens.count == 4,
                      tokens[0] == "launchctl",
                      tokens[1] == "setenv" else {
                    return nil
                }
                return (tokens[2], tokens[3])
            }
    }

    private func synthesizedShellBlock() -> String {
        let values = defaultShellValues()
        let exports = values.map { key, value in
            if value.contains(",") || value.contains(" ") {
                return "export \(key)=\"\(value)\""
            }
            return "export \(key)=\(value)"
        }.joined(separator: "\n")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return """
        \(startMarker)
        # HideOnBush restored: \(formatter.string(from: Date()))
        \(exports)
        \(endMarker)
        """
    }

    private func synthesizedLaunchAgentPlist() -> String {
        let commands = defaultLaunchctlValues()
            .map { "launchctl setenv \($0.0) \($0.1)" }
            .joined(separator: "; ")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>com.megastudy.otel</string>
          <key>ProgramArguments</key>
          <array>
            <string>/bin/sh</string>
            <string>-c</string>
            <string>\(commands.xmlEscaped)</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
        </dict>
        </plist>
        """
    }

    private func defaultShellValues() -> [(String, String)] {
        [
            ("CLAUDE_CODE_ENABLE_TELEMETRY", "1"),
            ("OTEL_METRICS_EXPORTER", "otlp"),
            ("OTEL_LOGS_EXPORTER", "otlp"),
            ("OTEL_EXPORTER_OTLP_PROTOCOL", "http/protobuf"),
            ("OTEL_EXPORTER_OTLP_ENDPOINT", "https://otel.megastudy.net"),
            ("OTEL_METRIC_EXPORT_INTERVAL", "10000"),
            ("OTEL_LOGS_EXPORT_INTERVAL", "5000"),
            ("OTEL_LOG_USER_PROMPTS", "1"),
            ("CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "0"),
            ("OTEL_METRICS_INCLUDE_SESSION_ID", "1"),
            ("OTEL_METRICS_INCLUDE_VERSION", "1"),
            ("OTEL_METRICS_INCLUDE_ACCOUNT_UUID", "1"),
            ("OTEL_RESOURCE_ATTRIBUTES", "user.name=\(NSUserName()),host.name=\(shortHostName())")
        ]
    }

    private func defaultLaunchctlValues() -> [(String, String)] {
        [
            ("CLAUDE_CODE_ENABLE_TELEMETRY", "1"),
            ("OTEL_METRICS_EXPORTER", "otlp"),
            ("OTEL_LOGS_EXPORTER", "otlp"),
            ("OTEL_EXPORTER_OTLP_PROTOCOL", "http/protobuf"),
            ("OTEL_EXPORTER_OTLP_ENDPOINT", "https://otel.megastudy.net"),
            ("OTEL_METRIC_EXPORT_INTERVAL", "10000"),
            ("OTEL_LOGS_EXPORT_INTERVAL", "5000"),
            ("OTEL_METRICS_INCLUDE_SESSION_ID", "1"),
            ("OTEL_METRICS_INCLUDE_VERSION", "1"),
            ("OTEL_METRICS_INCLUDE_ACCOUNT_UUID", "1"),
            ("OTEL_RESOURCE_ATTRIBUTES", "user.name=\(NSUserName()),host.name=\(shortHostName())")
        ]
    }

    private func shortHostName() -> String {
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if gethostname(&buffer, buffer.count) == 0 {
            return String(cString: buffer).split(separator: ".").first.map(String.init) ?? "unknown-host"
        }
        return "unknown-host"
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = TelemetryController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var snapshot: StatusSnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            try controller.captureCurrentWorkConfigIfNeeded()
        } catch {
            showAlert(title: "초기 백업 실패", message: error.localizedDescription)
        }

        refreshStatus()
    }

    private func refreshStatus() {
        snapshot = controller.status()
        updateStatusButton()
        rebuildMenu()
    }

    private func updateStatusButton() {
        let mode = snapshot?.mode ?? .mixed
        let symbolName: String
        switch mode {
        case .work:
            symbolName = "eye.fill"
        case .personal:
            symbolName = "eye.slash.fill"
        case .mixed:
            symbolName = "exclamationmark.triangle.fill"
        }

        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "\(appName) \(mode.rawValue)")
        button.title = " \(mode.rawValue)"
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let current = snapshot ?? controller.status()

        menu.addItem(disabledItem("\(appName): \(current.mode.rawValue) Mode"))
        menu.addItem(disabledItem("Shell: \(current.profileEnabled ? "ON" : "OFF")"))
        menu.addItem(disabledItem("LaunchAgent: \(current.launchAgentInstalled ? "ON" : "OFF") / \(current.launchAgentLoaded ? "Loaded" : "Not loaded")"))
        menu.addItem(disabledItem("GUI env: \(current.launchctlEnabled ? "ON" : "OFF")"))
        menu.addItem(.separator())

        let personal = NSMenuItem(title: "Personal Mode로 전환", action: #selector(enablePersonalMode), keyEquivalent: "")
        personal.target = self
        menu.addItem(personal)

        let work = NSMenuItem(title: "Work Mode로 전환", action: #selector(enableWorkMode), keyEquivalent: "")
        work.target = self
        menu.addItem(work)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "상태 새로고침", action: #selector(refreshStatusAction), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let copy = NSMenuItem(title: "상태 클립보드에 복사", action: #selector(copyStatus), keyEquivalent: "c")
        copy.target = self
        menu.addItem(copy)

        let openProfile = NSMenuItem(title: "셸 프로파일 열기", action: #selector(openShellProfile), keyEquivalent: "")
        openProfile.target = self
        menu.addItem(openProfile)

        let openLaunchAgents = NSMenuItem(title: "LaunchAgents 폴더 열기", action: #selector(openLaunchAgentsFolder), keyEquivalent: "")
        openLaunchAgents.target = self
        menu.addItem(openLaunchAgents)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "\(appName) 종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func enablePersonalMode() {
        do {
            try controller.enablePersonalMode()
            refreshStatus()
            showRestartAlert(mode: "Personal Mode")
        } catch {
            showAlert(title: "Personal Mode 전환 실패", message: error.localizedDescription)
            refreshStatus()
        }
    }

    @objc private func enableWorkMode() {
        do {
            try controller.enableWorkMode()
            refreshStatus()
            showRestartAlert(mode: "Work Mode")
        } catch {
            showAlert(title: "Work Mode 전환 실패", message: error.localizedDescription)
            refreshStatus()
        }
    }

    @objc private func refreshStatusAction() {
        refreshStatus()
    }

    @objc private func copyStatus() {
        controller.copyStatusToPasteboard()
    }

    @objc private func openShellProfile() {
        controller.openProfile()
    }

    @objc private func openLaunchAgentsFolder() {
        controller.openLaunchAgentsFolder()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showRestartAlert(mode: String) {
        showAlert(
            title: "\(mode) 적용됨",
            message: "이미 실행 중인 Claude Desktop, VSCode, Cursor, JetBrains IDE, Terminal/iTerm은 환경 변수를 계속 들고 있을 수 있습니다. 완전히 종료한 뒤 다시 실행해야 새 모드가 반영됩니다."
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "확인")
        alert.runModal()
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func trimmingTrailingWhitespaceAndNewlines() -> String {
        var result = self
        while let last = result.unicodeScalars.last,
              CharacterSet.whitespacesAndNewlines.contains(last) {
            result.removeLast()
        }
        return result
    }
}

@main
private enum HideOnBushMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
