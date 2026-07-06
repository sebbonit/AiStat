import Foundation

public protocol OpenCodeGoUsageFetching: Sendable {
    func fetchSnapshot() async throws -> OpenCodeGoUsageSnapshot
}

public final class OpenCodeGoUsageClient: OpenCodeGoUsageFetching, @unchecked Sendable {
    private let configPath: String
    private let session: URLSession

    public init(
        configPath: String = "\(NSHomeDirectory())/.config/opencode/opencode-quota/opencode-go.json",
        session: URLSession = .shared
    ) {
        self.configPath = configPath
        self.session = session
    }

    public func fetchSnapshot() async throws -> OpenCodeGoUsageSnapshot {
        guard let config = try OpenCodeGoDashboardConfig.resolve(configPath: configPath) else {
            throw CodexUsageError.unavailable("OpenCode Go needs dashboard auth. Run Scripts/configure-opencode-go.sh.")
        }

        return try await scrapeDashboard(config: config)
    }

    private func scrapeDashboard(config: OpenCodeGoDashboardConfig) async throws -> OpenCodeGoUsageSnapshot {
        let url = URL(string: "https://opencode.ai/workspace/\(config.workspaceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? config.workspaceId)/go")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Gecko/20100101 Firefox/148.0", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("auth=\(config.authCookie)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CodexUsageError.unavailable("OpenCode Go dashboard is temporarily unavailable.")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw CodexUsageError.unavailable("OpenCode Go dashboard response was invalid.")
        }

        let parsed = OpenCodeGoDashboardParser.snapshot(from: html, now: Date(), source: "Dashboard")
        guard parsed.hasUsage else {
            throw CodexUsageError.unavailable("OpenCode Go dashboard usage was not found.")
        }
        return parsed
    }
}

struct OpenCodeGoDashboardConfig: Equatable {
    let workspaceId: String
    let authCookie: String

    static func resolve(configPath: String, environment: [String: String] = ProcessInfo.processInfo.environment) throws -> OpenCodeGoDashboardConfig? {
        if let workspaceId = environment["OPENCODE_GO_WORKSPACE_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
           let authCookie = environment["OPENCODE_GO_AUTH_COOKIE"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            return OpenCodeGoDashboardConfig(workspaceId: workspaceId, authCookie: authCookie)
        }

        guard FileManager.default.fileExists(atPath: configPath) else { return nil }
        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let config = try JSONDecoder().decode(OpenCodeGoConfigFile.self, from: data)
        guard let workspaceId = config.workspaceId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
              let authCookie = config.authCookie?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }
        return OpenCodeGoDashboardConfig(workspaceId: workspaceId, authCookie: authCookie)
    }
}

private struct OpenCodeGoConfigFile: Decodable {
    let workspaceId: String?
    let authCookie: String?
}

enum OpenCodeGoDashboardParser {
    static func snapshot(from html: String, now: Date, source: String?) -> OpenCodeGoUsageSnapshot {
        let solid = OpenCodeGoUsageSnapshot(
            rolling: parseSolidWindow(name: "rollingUsage", html: html, now: now),
            weekly: parseSolidWindow(name: "weeklyUsage", html: html, now: now),
            monthly: parseSolidWindow(name: "monthlyUsage", html: html, now: now),
            source: source,
            fetchedAt: now
        )
        if solid.hasUsage {
            return solid
        }

        let slots = parseDataSlotWindows(html: html, now: now)
        return OpenCodeGoUsageSnapshot(
            rolling: slots["rolling"],
            weekly: slots["weekly"],
            monthly: slots["monthly"],
            source: source,
            fetchedAt: now
        )
    }

    private static func parseSolidWindow(name: String, html: String, now: Date) -> OpenCodeGoUsageWindow? {
        let number = #"(-?\d+(?:\.\d+)?)"#
        let pctFirst = #"\#(name):\$R\[\d+\]=\{[^}]*usagePercent:\#(number)[^}]*resetInSec:\#(number)[^}]*\}"#
        let resetFirst = #"\#(name):\$R\[\d+\]=\{[^}]*resetInSec:\#(number)[^}]*usagePercent:\#(number)[^}]*\}"#

        if let match = firstMatch(pattern: pctFirst, in: html),
           let usage = Double(match[0]),
           let resetSeconds = Double(match[1]) {
            return window(usedPercent: usage, resetSeconds: resetSeconds, now: now)
        }

        if let match = firstMatch(pattern: resetFirst, in: html),
           let resetSeconds = Double(match[0]),
           let usage = Double(match[1]) {
            return window(usedPercent: usage, resetSeconds: resetSeconds, now: now)
        }

        return nil
    }

    private static func parseDataSlotWindows(html: String, now: Date) -> [String: OpenCodeGoUsageWindow] {
        let parts = html.components(separatedBy: #"data-slot="usage-item""#)
        guard parts.count > 1 else { return [:] }

        var result: [String: OpenCodeGoUsageWindow] = [:]
        for part in parts.dropFirst() {
            guard let label = firstMatch(pattern: #"data-slot="usage-label">([^<]+)<"#, in: part)?.first?.lowercased(),
                  let usedText = firstMatch(pattern: #"data-slot="usage-value">[^0-9]*(\d+(?:\.\d+)?)"#, in: part)?.first,
                  let usedPercent = Double(usedText),
                  let resetMatch = firstMatch(pattern: #"data-slot="(reset-time|reset-now)">([\s\S]*?)</span>"#, in: part) else {
                continue
            }

            let resetSeconds = resetMatch[0] == "reset-now" ? 0 : parseHumanDuration(resetMatch[1])
            guard let resetSeconds else { continue }

            if label.contains("rolling") {
                result["rolling"] = window(usedPercent: usedPercent, resetSeconds: resetSeconds, now: now)
            } else if label.contains("weekly") {
                result["weekly"] = window(usedPercent: usedPercent, resetSeconds: resetSeconds, now: now)
            } else if label.contains("monthly") {
                result["monthly"] = window(usedPercent: usedPercent, resetSeconds: resetSeconds, now: now)
            }
        }
        return result
    }

    private static func parseHumanDuration(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: #"<!--\$-->"#, with: "")
            .replacingOccurrences(of: #"<!--/-->"#, with: "")
            .replacingOccurrences(of: #"Resets?\s*in\s*"#, with: "", options: .regularExpression)
            .lowercased()

        var seconds: Double = 0
        var found = false
        for (unit, multiplier) in [("days?", 86_400.0), ("hours?", 3_600.0), ("minutes?", 60.0), ("seconds?", 1.0)] {
            if let value = firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*\#(unit)"#, in: normalized)?.first,
               let number = Double(value) {
                seconds += number * multiplier
                found = true
            }
        }
        return found ? seconds : nil
    }

    private static func window(usedPercent: Double, resetSeconds: Double, now: Date) -> OpenCodeGoUsageWindow {
        OpenCodeGoUsageWindow(
            usedPercent: usedPercent,
            resetAt: now.addingTimeInterval(max(0, resetSeconds))
        )
    }

    private static func firstMatch(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
