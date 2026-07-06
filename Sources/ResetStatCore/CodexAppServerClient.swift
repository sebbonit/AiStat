import Foundation

public protocol CodexUsageFetching: Sendable {
    func fetchSnapshot() async throws -> ResetStatSnapshot
}

public final class CodexAppServerClient: CodexUsageFetching, @unchecked Sendable {
    public let executablePath: String
    public let appVersion: String
    private let resetCreditFetcher: ResetCreditFetching
    private let accountFetcher: CodexAccountFetching

    public init(
        executablePath: String = "/Applications/Codex.app/Contents/Resources/codex",
        appVersion: String = "1.0.0",
        resetCreditFetcher: ResetCreditFetching = BackendResetCreditClient(),
        accountFetcher: CodexAccountFetching = BackendCodexAccountClient()
    ) {
        self.executablePath = executablePath
        self.appVersion = appVersion
        self.resetCreditFetcher = resetCreditFetcher
        self.accountFetcher = accountFetcher
    }

    public func fetchSnapshot() async throws -> ResetStatSnapshot {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw CodexUsageError.codexNotFound(path: executablePath)
        }

        let session = JSONRPCProcessSession(executablePath: executablePath)
        try session.start()
        defer { session.terminate() }

        let initializeParams: [String: Any] = [
            "clientInfo": [
                "name": "resetstat",
                "title": "ResetStat",
                "version": appVersion
            ],
            "capabilities": [
                "experimentalApi": true
            ]
        ]

        let _: EmptyResult = try await session.request(
            method: "initialize",
            params: initializeParams,
            as: EmptyResult.self
        )

        let rateLimits: GetAccountRateLimitsResponse = try await session.request(
            method: "account/rateLimits/read",
            params: NSNull(),
            as: GetAccountRateLimitsResponse.self
        )

        let usage: GetAccountTokenUsageResponse? = try? await session.request(
            method: "account/usage/read",
            params: NSNull(),
            as: GetAccountTokenUsageResponse.self
        )

        let resetCredits = (try? await resetCreditFetcher.fetchResetCredits())
            ?? ResetCreditInfo(summary: rateLimits.rateLimitResetCredits)
        let account = try? await accountFetcher.fetchAccountInfo()

        return ResetStatSnapshot(
            rateLimit: rateLimits.preferredRateLimit,
            resetCredits: resetCredits,
            planExpiresAt: account?.planExpiresAt,
            tokenUsage: usage?.summary,
            dailyUsageBuckets: usage?.dailyUsageBuckets ?? []
        )
    }
}

private struct EmptyResult: Decodable {
    init(from decoder: Decoder) throws {}
}

private struct JSONRPCEnvelope<Result: Decodable>: Decodable {
    let result: Result
}

private final class JSONRPCProcessSession: @unchecked Sendable {
    private let executablePath: String
    private let process = Process()
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let store = JSONRPCResponseStore()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var nextId = 1
    private var readerTask: Task<Void, Never>?

    init(executablePath: String) {
        self.executablePath = executablePath
    }

    func start() throws {
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        try process.run()

        let reader = outputPipe.fileHandleForReading
        readerTask = Task.detached(priority: .utility) { [store] in
            var buffer = Data()
            while true {
                let chunk = reader.readData(ofLength: 1)
                if chunk.isEmpty {
                    if !buffer.isEmpty {
                        await store.receive(line: buffer)
                    }
                    break
                }

                if chunk.first == 10 {
                    await store.receive(line: buffer)
                    buffer.removeAll(keepingCapacity: true)
                } else {
                    buffer.append(chunk)
                }
            }
        }
    }

    func terminate() {
        readerTask?.cancel()
        if process.isRunning {
            process.terminate()
        }
    }

    func request<Result: Decodable>(method: String, params: Any, as type: Result.Type) async throws -> Result {
        let id = nextId
        nextId += 1

        let request: [String: Any] = [
            "id": id,
            "method": method,
            "params": params
        ]

        let data = try JSONSerialization.data(withJSONObject: request)
        inputPipe.fileHandleForWriting.write(data)
        inputPipe.fileHandleForWriting.write(Data([10]))

        let responseData = try await store.response(for: id)
        return try decoder.decode(JSONRPCEnvelope<Result>.self, from: responseData).result
    }
}

private actor JSONRPCResponseStore {
    private var pendingResponses: [Int: Data] = [:]
    private var pendingErrors: [Int: Error] = [:]
    private var continuations: [Int: CheckedContinuation<Data, Error>] = [:]

    func response(for id: Int) async throws -> Data {
        if let response = pendingResponses.removeValue(forKey: id) {
            return response
        }
        if let error = pendingErrors.removeValue(forKey: id) {
            throw error
        }

        return try await withCheckedThrowingContinuation { continuation in
            continuations[id] = continuation
        }
    }

    func receive(line: Data) {
        guard !line.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let id = object["id"] as? Int else {
            return
        }

        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Codex app-server returned an error."
            resume(id: id, result: .failure(CodexUsageError.fromServerMessage(message)))
            return
        }

        resume(id: id, result: .success(line))
    }

    private func resume(id: Int, result: Result<Data, Error>) {
        if let continuation = continuations.removeValue(forKey: id) {
            switch result {
            case .success(let data):
                continuation.resume(returning: data)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
            return
        }

        if case .success(let data) = result {
            pendingResponses[id] = data
        } else if case .failure(let error) = result {
            pendingErrors[id] = error
        }
    }
}
