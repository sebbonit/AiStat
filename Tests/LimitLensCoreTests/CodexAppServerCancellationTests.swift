import Foundation
import Testing
@testable import LimitLensCore

@Suite("Codex app-server lifecycle")
struct CodexAppServerCancellationTests {
    @Test("A pending app-server request respects task cancellation")
    func pendingRequestRespectsCancellation() async throws {
        let executableURL = try makeUnresponsiveExecutable()
        defer { try? FileManager.default.removeItem(at: executableURL) }

        let client = CodexAppServerClient(
            executablePath: executableURL.path,
            requestTimeout: .seconds(2)
        )
        let requestTask = Task { try await client.fetchSnapshot() }

        try await Task.sleep(for: .milliseconds(50))
        requestTask.cancel()

        do {
            _ = try await requestTask.value
            Issue.record("Expected the pending request to be cancelled")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Expected CancellationError, got \(error)")
        }
    }

    @Test("An unresponsive app-server request has a hard deadline")
    func unresponsiveRequestTimesOut() async throws {
        let executableURL = try makeUnresponsiveExecutable()
        defer { try? FileManager.default.removeItem(at: executableURL) }

        let client = CodexAppServerClient(
            executablePath: executableURL.path,
            requestTimeout: .milliseconds(100)
        )

        do {
            _ = try await client.fetchSnapshot()
            Issue.record("Expected the app-server request to time out")
        } catch let error as CodexUsageError {
            #expect(error.errorDescription == "Codex app-server did not respond in time.")
        } catch {
            Issue.record("Expected CodexUsageError, got \(error)")
        }
    }

    private func makeUnresponsiveExecutable() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("limitlens-unresponsive-\(UUID().uuidString).sh")
        let script = """
        #!/bin/sh
        while IFS= read -r line
        do
            :
        done
        """
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
        return url
    }
}
