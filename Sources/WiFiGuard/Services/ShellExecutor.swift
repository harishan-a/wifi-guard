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

        // Read pipe data BEFORE waitUntilExit to avoid deadlock
        // when the subprocess fills the pipe buffer (64 KB on macOS).
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        // Use a background task to enforce the timeout
        let timedOut = UnsafeSendableBox(value: false)
        let timeoutTask = Task.detached {
            try? await Task.sleep(for: .seconds(timeout))
            if process.isRunning {
                process.terminate()
                timedOut.value = true
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        if timedOut.value {
            throw ShellError.timeout
        }

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return CommandResult(
            exitCode: process.terminationStatus,
            output: stdout,
            error: stderr
        )
    }

    // MARK: - Convenience

    /// Run a path-based command with variadic arguments.
    func runCommand(
        _ path: String,
        _ args: String...,
        timeout: TimeInterval = 10
    ) async throws -> CommandResult {
        try await run(path, arguments: Array(args), timeout: timeout)
    }
}

// Helper for thread-safe flag sharing
private final class UnsafeSendableBox<T>: @unchecked Sendable {
    var value: T
    init(value: T) { self.value = value }
}
