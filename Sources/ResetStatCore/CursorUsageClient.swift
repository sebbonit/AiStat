import Foundation

public protocol CursorUsageFetching: Sendable {
    func fetchSnapshot() async throws -> CursorUsageSnapshot
}

public final class CursorUsageClient: CursorUsageFetching, @unchecked Sendable {
    private let stateDatabasePath: String
    private let endpointBaseURL: URL
    private let session: URLSession

    public init(
        stateDatabasePath: String = "\(NSHomeDirectory())/Library/Application Support/Cursor/User/globalStorage/state.vscdb",
        endpointBaseURL: URL = URL(string: "https://api2.cursor.sh")!,
        session: URLSession = .shared
    ) {
        self.stateDatabasePath = stateDatabasePath
        self.endpointBaseURL = endpointBaseURL
        self.session = session
    }

    public func fetchSnapshot() async throws -> CursorUsageSnapshot {
        guard FileManager.default.fileExists(atPath: stateDatabasePath) else {
            throw CursorUsageError.cursorStateNotFound
        }

        let token = try CursorAuthTokenReader(databasePath: stateDatabasePath).accessToken()
        async let usage = dashboardRequest(
            method: "GetCurrentPeriodUsage",
            token: token,
            as: CursorCurrentPeriodUsageResponse.self
        )
        async let plan = dashboardRequest(
            method: "GetPlanInfo",
            token: token,
            as: CursorPlanInfoResponse.self
        )

        let (usageResponse, planResponse) = try await (usage, plan)
        return usageResponse.snapshot(plan: planResponse.planInfo)
    }

    private func dashboardRequest<Response: Decodable>(
        method: String,
        token: String,
        as type: Response.Type
    ) async throws -> Response {
        let url = endpointBaseURL.appending(path: "aiserver.v1.DashboardService/\(method)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "connect-protocol-version")
        request.setValue("ResetStat/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CursorUsageError.unavailable("Cursor response was invalid.")
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw CursorUsageError.notSignedIn
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CursorUsageError.unavailable("Cursor usage is temporarily unavailable.")
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

public enum CursorUsageError: LocalizedError, Equatable, Sendable {
    case cursorStateNotFound
    case notSignedIn
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .cursorStateNotFound:
            return "Cursor usage unavailable."
        case .notSignedIn:
            return "Sign in to Cursor."
        case .unavailable(let message):
            return message
        }
    }
}

struct CursorCurrentPeriodUsageResponse: Decodable, Equatable {
    let billingCycleStart: FlexibleMilliseconds?
    let billingCycleEnd: FlexibleMilliseconds?
    let planUsage: CursorPlanUsage?
    let displayMessage: String?
    let enabled: Bool?

    func snapshot(plan: CursorPlanInfo?) -> CursorUsageSnapshot {
        CursorUsageSnapshot(
            planName: plan?.planName,
            price: plan?.price,
            includedAmountCents: plan?.includedAmountCents,
            billingCycleStart: billingCycleStart?.date,
            billingCycleEnd: billingCycleEnd?.date,
            remainingCents: planUsage?.remaining,
            limitCents: planUsage?.limit,
            totalPercentUsed: planUsage?.totalPercentUsed,
            autoSpendCents: planUsage?.autoSpend,
            autoLimitCents: planUsage?.autoLimit,
            autoPercentUsed: planUsage?.autoPercentUsed,
            apiSpendCents: planUsage?.apiSpend,
            apiLimitCents: planUsage?.apiLimit,
            apiPercentUsed: planUsage?.apiPercentUsed,
            displayMessage: displayMessage
        )
    }
}

struct CursorPlanUsage: Decodable, Equatable {
    let remaining: Int?
    let limit: Int?
    let totalPercentUsed: Double?
    let autoSpend: Int?
    let autoLimit: Int?
    let autoPercentUsed: Double?
    let apiSpend: Int?
    let apiLimit: Int?
    let apiPercentUsed: Double?
}

struct CursorPlanInfoResponse: Decodable, Equatable {
    let planInfo: CursorPlanInfo?
}

struct CursorPlanInfo: Decodable, Equatable {
    let planName: String?
    let includedAmountCents: Int?
    let price: String?
    let billingCycleEnd: FlexibleMilliseconds?
}

struct FlexibleMilliseconds: Decodable, Equatable {
    let rawValue: Int64

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(rawValue) / 1000)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int64.self) {
            rawValue = intValue
            return
        }
        let stringValue = try container.decode(String.self)
        guard let intValue = Int64(stringValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected millisecond timestamp."
            )
        }
        rawValue = intValue
    }
}

private struct CursorAuthTokenReader {
    let databasePath: String

    func accessToken() throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            databasePath,
            "SELECT value FROM ItemTable WHERE key='cursorAuth/accessToken' LIMIT 1;"
        ]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CursorUsageError.unavailable("Cursor sign-in state could not be read.")
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let token = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw CursorUsageError.notSignedIn
        }
        return token
    }
}
