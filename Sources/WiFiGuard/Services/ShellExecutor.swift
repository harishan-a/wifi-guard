import Foundation

actor ShellExecutor {

    struct CommandResult: Sendable {
        let exitCode: Int32
        let output: String
        let error: String
    }

    enum ShellError: Error, LocalizedError {
        case timeout

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "Shell command timed out"
            }
        }
    }

    // MARK: - Primary API

    /// Run an executable at `command` with the given arguments.
    /// If the process does not exit within `timeout` seconds it is terminated
    /// and ``ShellError/timeout`` is thrown.
    func run(
        _ command: String,
        arguments: [String] = [],
        timeout: TimeInterval = 10
    ) async throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let result = await withTaskGroup(of: CommandResult?.self) { group in
            group.addTask {
                process.waitUntilExit()
                let stdout = String(
                    data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let stderr = String(
                    data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                return CommandResult(
                    exitCode: process.terminationStatus,
                    output: stdout,
                    error: stderr
                )
            }

            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                if process.isRunning {
                    process.terminate()
                }
                return nil
            }

            let first = await group.next()!
            group.cancelAll()
            return first
        }

        if let result {
            return result
        }
        throw ShellError.timeout
    }

    // MARK: - Convenience

    /// Run a path-based command with variadic arguments.
    ///
    /// Example:
    /// ```swift
    /// let result = try await shell.runCommand("/usr/sbin/networksetup", "-getairportpower", "en0")
    /// ```
    func runCommand(
        _ path: String,
        _ args: String...,
        timeout: TimeInterval = 10
    ) async throws -> CommandResult {
        try await run(path, arguments: Array(args), timeout: timeout)
    }
}
