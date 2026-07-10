import Foundation

public protocol CodexAccountFetching: Sendable {
    func fetchAccountInfo() async throws -> CodexAccountInfo
}

public struct CodexAccountInfo: Equatable, Sendable {
    public let planExpiresAt: Date?

    public init(planExpiresAt: Date?) {
        self.planExpiresAt = planExpiresAt
    }
}

public final class BackendCodexAccountClient: CodexAccountFetching, @unchecked Sendable {
    private let authPath: String
    private let endpoint: URL
    private let session: URLSession

    public init(
        authPath: String = "\(NSHomeDirectory())/.codex/auth.json",
        endpoint: URL = URL(string: "https://chatgpt.com/backend-api/accounts/check/v4-2023-04-27")!,
        session: URLSession = .shared
    ) {
        self.authPath = authPath
        self.endpoint = endpoint
        self.session = session
    }

    public func fetchAccountInfo() async throws -> CodexAccountInfo {
        let token = try CodexAuthFile(path: authPath).accessToken()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LimitLens/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return CodexAccountInfo(planExpiresAt: nil)
        }

        let payload = try JSONDecoder.resetStatBackend.decode(BackendCodexAccountResponse.self, from: data)
        return CodexAccountInfo(planExpiresAt: payload.planExpiresAt)
    }
}

struct BackendCodexAccountResponse: Decodable, Equatable {
    let accountPlan: BackendCodexAccountPlan?
    let accounts: BackendCodexAccounts?
    let accountOrdering: [String]?

    var planExpiresAt: Date? {
        accountPlan?.planExpiresAt ?? accounts?.preferredPlanExpiresAt(ordering: accountOrdering)
    }
}

struct BackendCodexAccounts: Decodable, Equatable {
    let values: [String: BackendCodexAccount]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let keyed = try? container.decode([String: BackendCodexAccount].self) {
            values = keyed
        } else {
            let array = try container.decode([BackendCodexAccount].self)
            values = Dictionary(uniqueKeysWithValues: array.enumerated().map { (String($0.offset), $0.element) })
        }
    }

    func preferredPlanExpiresAt(ordering: [String]?) -> Date? {
        if let date = values["default"]?.planExpiresAt {
            return date
        }
        for accountId in ordering ?? [] {
            if let date = values[accountId]?.planExpiresAt {
                return date
            }
        }
        return values.values.compactMap(\.planExpiresAt).first
    }
}

struct BackendCodexAccount: Decodable, Equatable {
    let entitlement: BackendCodexEntitlement?
    let accountPlan: BackendCodexAccountPlan?

    var planExpiresAt: Date? {
        entitlement?.planExpiresAt ?? accountPlan?.planExpiresAt
    }
}

struct BackendCodexEntitlement: Decodable, Equatable {
    let expiresAt: Date?
    let renewsAt: Date?

    var planExpiresAt: Date? {
        renewsAt ?? expiresAt
    }
}

struct BackendCodexAccountPlan: Decodable, Equatable {
    let expiresAt: Date?
    let renewalDate: Date?
    let nextInvoiceDate: Date?

    var planExpiresAt: Date? {
        renewalDate ?? nextInvoiceDate ?? expiresAt
    }
}
