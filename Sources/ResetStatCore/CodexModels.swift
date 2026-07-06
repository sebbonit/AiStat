import Foundation

public struct RateLimitWindow: Codable, Equatable, Sendable {
    public let resetsAt: Int64?
    public let usedPercent: Int
    public let windowDurationMins: Int64?
}

public struct CreditsSnapshot: Codable, Equatable, Sendable {
    public let balance: String?
    public let hasCredits: Bool
    public let unlimited: Bool
}

public struct SpendControlLimitSnapshot: Codable, Equatable, Sendable {
    public let limit: String
    public let remainingPercent: Int
    public let resetsAt: Int64
    public let used: String
}

public struct RateLimitSnapshot: Codable, Equatable, Sendable {
    public let credits: CreditsSnapshot?
    public let individualLimit: SpendControlLimitSnapshot?
    public let limitId: String?
    public let limitName: String?
    public let planType: String?
    public let primary: RateLimitWindow?
    public let rateLimitReachedType: String?
    public let secondary: RateLimitWindow?
}

public struct RateLimitResetCreditsSummary: Codable, Equatable, Sendable {
    public let availableCount: Int
    public let expiresAt: Int64?
}

public struct ResetCreditInfo: Equatable, Sendable {
    public let availableCount: Int
    public let totalEarnedCount: Int?
    public let credits: [ResetCredit]

    public init(availableCount: Int, totalEarnedCount: Int?, credits: [ResetCredit]) {
        self.availableCount = availableCount
        self.totalEarnedCount = totalEarnedCount
        self.credits = credits
    }

    public init(summary: RateLimitResetCreditsSummary?) {
        self.availableCount = summary?.availableCount ?? 0
        self.totalEarnedCount = nil
        if let expiresAt = summary?.expiresAt {
            self.credits = [
                ResetCredit(
                    id: nil,
                    resetType: nil,
                    status: nil,
                    grantedAt: nil,
                    expiresAt: Date(timeIntervalSince1970: TimeInterval(expiresAt)),
                    title: nil,
                    description: nil
                )
            ]
        } else {
            self.credits = []
        }
    }

    public var nextExpiringCredit: ResetCredit? {
        credits
            .filter { $0.expiresAt != nil }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
            .first
    }
}

public struct ResetCredit: Equatable, Sendable {
    public let id: String?
    public let resetType: String?
    public let status: String?
    public let grantedAt: Date?
    public let expiresAt: Date?
    public let title: String?
    public let description: String?

    public init(
        id: String?,
        resetType: String?,
        status: String?,
        grantedAt: Date?,
        expiresAt: Date?,
        title: String?,
        description: String?
    ) {
        self.id = id
        self.resetType = resetType
        self.status = status
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.title = title
        self.description = description
    }
}

public struct GetAccountRateLimitsResponse: Codable, Equatable, Sendable {
    public let rateLimitResetCredits: RateLimitResetCreditsSummary?
    public let rateLimits: RateLimitSnapshot
    public let rateLimitsByLimitId: [String: RateLimitSnapshot]?

    public var preferredRateLimit: RateLimitSnapshot {
        rateLimitsByLimitId?["codex"] ?? rateLimits
    }
}

public struct AccountTokenUsageDailyBucket: Codable, Equatable, Sendable {
    public let startDate: String
    public let tokens: Int64
}

public struct AccountTokenUsageSummary: Codable, Equatable, Sendable {
    public let currentStreakDays: Int64?
    public let lifetimeTokens: Int64?
    public let longestRunningTurnSec: Int64?
    public let longestStreakDays: Int64?
    public let peakDailyTokens: Int64?
}

public struct GetAccountTokenUsageResponse: Codable, Equatable, Sendable {
    public let dailyUsageBuckets: [AccountTokenUsageDailyBucket]?
    public let summary: AccountTokenUsageSummary
}

public struct ResetStatSnapshot: Equatable, Sendable {
    public let rateLimit: RateLimitSnapshot
    public let resetCredits: ResetCreditInfo
    public let planExpiresAt: Date?
    public let tokenUsage: AccountTokenUsageSummary?
    public let dailyUsageBuckets: [AccountTokenUsageDailyBucket]
    public let fetchedAt: Date

    public init(
        rateLimit: RateLimitSnapshot,
        resetCredits: ResetCreditInfo,
        planExpiresAt: Date? = nil,
        tokenUsage: AccountTokenUsageSummary?,
        dailyUsageBuckets: [AccountTokenUsageDailyBucket] = [],
        fetchedAt: Date = Date()
    ) {
        self.rateLimit = rateLimit
        self.resetCredits = resetCredits
        self.planExpiresAt = planExpiresAt
        self.tokenUsage = tokenUsage
        self.dailyUsageBuckets = dailyUsageBuckets
        self.fetchedAt = fetchedAt
    }
}

public struct CursorUsageSnapshot: Equatable, Sendable {
    public let planName: String?
    public let price: String?
    public let includedAmountCents: Int?
    public let billingCycleStart: Date?
    public let billingCycleEnd: Date?
    public let remainingCents: Int?
    public let limitCents: Int?
    public let totalPercentUsed: Double?
    public let autoSpendCents: Int?
    public let autoLimitCents: Int?
    public let autoPercentUsed: Double?
    public let apiSpendCents: Int?
    public let apiLimitCents: Int?
    public let apiPercentUsed: Double?
    public let displayMessage: String?
    public let fetchedAt: Date

    public init(
        planName: String?,
        price: String?,
        includedAmountCents: Int?,
        billingCycleStart: Date?,
        billingCycleEnd: Date?,
        remainingCents: Int?,
        limitCents: Int?,
        totalPercentUsed: Double?,
        autoSpendCents: Int?,
        autoLimitCents: Int?,
        autoPercentUsed: Double?,
        apiSpendCents: Int?,
        apiLimitCents: Int?,
        apiPercentUsed: Double?,
        displayMessage: String?,
        fetchedAt: Date = Date()
    ) {
        self.planName = planName
        self.price = price
        self.includedAmountCents = includedAmountCents
        self.billingCycleStart = billingCycleStart
        self.billingCycleEnd = billingCycleEnd
        self.remainingCents = remainingCents
        self.limitCents = limitCents
        self.totalPercentUsed = totalPercentUsed
        self.autoSpendCents = autoSpendCents
        self.autoLimitCents = autoLimitCents
        self.autoPercentUsed = autoPercentUsed
        self.apiSpendCents = apiSpendCents
        self.apiLimitCents = apiLimitCents
        self.apiPercentUsed = apiPercentUsed
        self.displayMessage = displayMessage
        self.fetchedAt = fetchedAt
    }

    public var usedPercent: Double {
        if let totalPercentUsed {
            return max(0, min(100, totalPercentUsed))
        }
        guard let remainingCents, let limitCents, limitCents > 0 else {
            return 0
        }
        return max(0, min(100, Double(limitCents - remainingCents) / Double(limitCents) * 100))
    }
}

public struct DesktopQuotaSnapshot: Equatable, Sendable {
    public let appName: String
    public let planName: String?
    public let billingStrategy: String?
    public let cycleStart: Date?
    public let cycleEnd: Date?
    public let dailyRemainingPercent: Int?
    public let weeklyRemainingPercent: Int?
    public let dailyResetAt: Date?
    public let weeklyResetAt: Date?
    public let overageBalanceMicros: Int64?
    public let isStaleFallback: Bool
    public let fetchedAt: Date

    public init(
        appName: String,
        planName: String?,
        billingStrategy: String?,
        cycleStart: Date?,
        cycleEnd: Date?,
        dailyRemainingPercent: Int?,
        weeklyRemainingPercent: Int?,
        dailyResetAt: Date?,
        weeklyResetAt: Date?,
        overageBalanceMicros: Int64?,
        isStaleFallback: Bool = false,
        fetchedAt: Date = Date()
    ) {
        self.appName = appName
        self.planName = planName
        self.billingStrategy = billingStrategy
        self.cycleStart = cycleStart
        self.cycleEnd = cycleEnd
        self.dailyRemainingPercent = dailyRemainingPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.dailyResetAt = dailyResetAt
        self.weeklyResetAt = weeklyResetAt
        self.overageBalanceMicros = overageBalanceMicros
        self.isStaleFallback = isStaleFallback
        self.fetchedAt = fetchedAt
    }

    public var dailyUsedPercent: Int? {
        if let dailyRemainingPercent {
            return max(0, min(100, 100 - dailyRemainingPercent))
        }
        return dailyResetAt == nil ? nil : 100
    }

    public var weeklyUsedPercent: Int? {
        if let weeklyRemainingPercent {
            return max(0, min(100, 100 - weeklyRemainingPercent))
        }
        return weeklyResetAt == nil ? nil : 100
    }

    public var shouldTreatQuotaUsageAsUnavailable: Bool {
        isStaleFallback && dailyRemainingPercent == 100 && weeklyRemainingPercent == 100
    }
}

public struct OpenCodeGoUsageSnapshot: Equatable, Sendable {
    public let rolling: OpenCodeGoUsageWindow?
    public let weekly: OpenCodeGoUsageWindow?
    public let monthly: OpenCodeGoUsageWindow?
    public let source: String?
    public let fetchedAt: Date

    public init(
        rolling: OpenCodeGoUsageWindow?,
        weekly: OpenCodeGoUsageWindow?,
        monthly: OpenCodeGoUsageWindow?,
        source: String? = nil,
        fetchedAt: Date = Date()
    ) {
        self.rolling = rolling
        self.weekly = weekly
        self.monthly = monthly
        self.source = source
        self.fetchedAt = fetchedAt
    }

    public var hasUsage: Bool {
        rolling != nil || weekly != nil || monthly != nil
    }
}

public struct OpenCodeGoUsageWindow: Equatable, Sendable {
    public let usedPercent: Double
    public let resetAt: Date?

    public init(usedPercent: Double, resetAt: Date?) {
        self.usedPercent = max(0, min(100, usedPercent))
        self.resetAt = resetAt
    }
}
