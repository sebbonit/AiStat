import Foundation

public protocol ResetCreditFetching: Sendable {
    func fetchResetCredits() async throws -> ResetCreditInfo
}

public final class BackendResetCreditClient: ResetCreditFetching, @unchecked Sendable {
    private let authPath: String
    private let endpoint: URL
    private let session: URLSession

    public init(
        authPath: String = "\(NSHomeDirectory())/.codex/auth.json",
        endpoint: URL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!,
        session: URLSession = .shared
    ) {
        self.authPath = authPath
        self.endpoint = endpoint
        self.session = session
    }

    public func fetchResetCredits() async throws -> ResetCreditInfo {
        let token = try CodexAuthFile(path: authPath).accessToken()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LimitLens/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CodexUsageError.unavailable("Reset credit response was invalid.")
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw CodexUsageError.notSignedIn
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CodexUsageError.unavailable("Reset credit details are temporarily unavailable.")
        }

        return try JSONDecoder.resetStatBackend.decode(BackendResetCreditsResponse.self, from: data).asResetCreditInfo
    }
}

struct CodexAuthFile {
    let path: String

    func accessToken() throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let auth = try JSONDecoder().decode(CodexAuth.self, from: data)
        guard !auth.tokens.accessToken.isEmpty else {
            throw CodexUsageError.notSignedIn
        }
        return auth.tokens.accessToken
    }
}

private struct CodexAuth: Decodable {
    let tokens: Tokens

    struct Tokens: Decodable {
        let accessToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }
}

struct BackendResetCreditsResponse: Decodable {
    let credits: [BackendResetCredit]
    let availableCount: Int
    let totalEarnedCount: Int?

    var asResetCreditInfo: ResetCreditInfo {
        ResetCreditInfo(
            availableCount: availableCount,
            totalEarnedCount: totalEarnedCount,
            credits: credits.map(\.asResetCredit)
        )
    }
}

struct BackendResetCredit: Decodable {
    let id: String?
    let resetType: String?
    let status: String?
    let grantedAt: Date?
    let expiresAt: Date?
    let title: String?
    let description: String?

    var asResetCredit: ResetCredit {
        ResetCredit(
            id: id,
            resetType: resetType,
            status: status,
            grantedAt: grantedAt,
            expiresAt: expiresAt,
            title: title,
            description: description
        )
    }
}

extension JSONDecoder {
    static var resetStatBackend: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = parseBackendDate(value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        return decoder
    }
}

private func parseBackendDate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) {
        return date
    }

    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: value)
}
