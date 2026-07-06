import Foundation
import ResetStatCore
import SwiftUI

enum UsageSeverity: Int, Comparable {
    case unavailable
    case healthy
    case warning
    case critical

    static func < (lhs: UsageSeverity, rhs: UsageSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(percentUsed: Double?) -> UsageSeverity {
        guard let percentUsed else { return .unavailable }
        if percentUsed >= 90 {
            return .critical
        }
        if percentUsed >= 70 {
            return .warning
        }
        return .healthy
    }
}

struct ProviderUsageSummary: Identifiable {
    let tab: ProviderTab
    let detail: String
    let subdetail: String
    let secondaryDetail: String?
    let percentUsed: Double?
    let resetAt: Date?
    let severity: UsageSeverity

    var id: ProviderTab { tab }

    var menuTitle: String {
        if severity == .unavailable {
            return "S ?"
        }
        guard let percentUsed, severity >= .warning else { return "S" }
        return "S \(Int(percentUsed.rounded()))%"
    }
}

struct BillingExpiry: Identifiable {
    let tab: ProviderTab
    let label: String
    let date: Date?
    let amountText: String?
    let detailText: String?
    let urgency: UsageFormatting.ExpiryUrgency

    var id: ProviderTab { tab }
}

private struct LimitCandidate {
    let title: String
    let percent: Int
    let resetAt: Date?
    let durationMinutes: Int64
}

@MainActor
final class UsageViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var snapshot: ResetStatSnapshot?
    @Published private(set) var cursorSnapshot: CursorUsageSnapshot?
    @Published private(set) var desktopQuotaSnapshots: [DesktopQuotaSnapshot] = []
    @Published private(set) var openCodeGoSnapshot: OpenCodeGoUsageSnapshot?
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var cursorState: LoadState = .idle
    @Published private(set) var desktopQuotaState: LoadState = .idle
    @Published private(set) var openCodeGoState: LoadState = .idle
    @Published var hidesProviderNames = false
    @Published var now = Date()

    private let service: CodexUsageFetching
    private let cursorService: CursorUsageFetching
    private let desktopQuotaService: DesktopQuotaFetching
    private let openCodeGoService: OpenCodeGoUsageFetching
    private var didStartLoops = false

    init(
        service: CodexUsageFetching = CodexAppServerClient(),
        cursorService: CursorUsageFetching = CursorUsageClient(),
        desktopQuotaService: DesktopQuotaFetching = DesktopQuotaClient(),
        openCodeGoService: OpenCodeGoUsageFetching = OpenCodeGoUsageClient()
    ) {
        self.service = service
        self.cursorService = cursorService
        self.desktopQuotaService = desktopQuotaService
        self.openCodeGoService = openCodeGoService
    }

    func start() {
        guard !didStartLoops else { return }
        didStartLoops = true

        Task { await refreshLoop() }
        Task { await clockLoop() }
    }

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshCodex() }
            group.addTask { await self.refreshCursor() }
            group.addTask { await self.refreshDesktopQuotas() }
            group.addTask { await self.refreshOpenCodeGo() }
        }
    }

    var providerSummaries: [ProviderUsageSummary] {
        [
            codexSummary,
            cursorSummary,
            desktopQuotaSummary,
            openCodeGoSummary
        ]
    }

    var prioritySummary: ProviderUsageSummary? {
        providerSummaries
            .sorted {
                if $0.severity != $1.severity {
                    return $0.severity > $1.severity
                }
                return ($0.percentUsed ?? -1) > ($1.percentUsed ?? -1)
            }
            .first
    }

    var billingExpiries: [BillingExpiry] {
        [
            codexBillingExpiry,
            cursorBillingExpiry,
            devinBillingExpiry,
            openCodeGoBillingExpiry
        ]
    }

    private var codexBillingExpiry: BillingExpiry {
        let date = snapshot?.planExpiresAt
        return BillingExpiry(
            tab: .codex,
            label: "Renews",
            date: date,
            amountText: nil,
            detailText: nil,
            urgency: UsageFormatting.expiryUrgency(expiresAt: date, now: now)
        )
    }

    private var cursorBillingExpiry: BillingExpiry {
        let date = cursorSnapshot?.billingCycleEnd
        return BillingExpiry(
            tab: .cursor,
            label: "Cycle ends",
            date: date,
            amountText: nil,
            detailText: nil,
            urgency: UsageFormatting.expiryUrgency(expiresAt: date, now: now)
        )
    }

    private var devinBillingExpiry: BillingExpiry {
        let date = desktopQuotaSnapshots.first?.cycleEnd
        return BillingExpiry(
            tab: .devin,
            label: "Cycle ends",
            date: date,
            amountText: nil,
            detailText: nil,
            urgency: UsageFormatting.expiryUrgency(expiresAt: date, now: now)
        )
    }

    private var openCodeGoBillingExpiry: BillingExpiry {
        let billing = openCodeGoSnapshot?.billing
        let lastPayment = billing?.lastPayment
        let balance = billing?.balanceText

        let label: String
        if lastPayment != nil {
            label = "Last payment"
        } else if billing == nil {
            label = "No billing"
        } else {
            label = "No payments"
        }

        return BillingExpiry(
            tab: .openCodeGo,
            label: label,
            date: lastPayment?.date,
            amountText: balance,
            detailText: lastPayment.flatMap { $0.dateText.isEmpty ? nil : $0.dateText },
            urgency: .unknown
        )
    }

    var menuBarTitle: String {
        prioritySummary?.menuTitle ?? "S"
    }

    var menuBarSeverity: UsageSeverity {
        prioritySummary?.severity ?? .healthy
    }

    private func refreshCodex() async {
        state = snapshot == nil ? .loading : .loaded
        do {
            snapshot = try await service.fetchSnapshot()
            state = .loaded
        } catch let error as CodexUsageError {
            state = .failed(error.localizedDescription)
        } catch {
            state = .failed("Usage data is temporarily unavailable.")
        }
    }

    private func refreshCursor() async {
        cursorState = cursorSnapshot == nil ? .loading : .loaded
        do {
            cursorSnapshot = try await cursorService.fetchSnapshot()
            cursorState = .loaded
        } catch let error as CursorUsageError {
            cursorState = .failed(error.localizedDescription)
        } catch {
            cursorState = .failed("Cursor usage is temporarily unavailable.")
        }
    }

    private func refreshDesktopQuotas() async {
        desktopQuotaState = desktopQuotaSnapshots.isEmpty ? .loading : .loaded
        do {
            let snapshots = try await desktopQuotaService.fetchSnapshots()
            desktopQuotaSnapshots = snapshots
            desktopQuotaState = snapshots.isEmpty ? .failed("Devin quota cache unavailable.") : .loaded
        } catch {
            desktopQuotaState = .failed("Devin quotas are temporarily unavailable.")
        }
    }

    private func refreshOpenCodeGo() async {
        openCodeGoState = openCodeGoSnapshot == nil ? .loading : .loaded
        do {
            openCodeGoSnapshot = try await openCodeGoService.fetchSnapshot()
            openCodeGoState = .loaded
        } catch let error as CodexUsageError {
            openCodeGoState = .failed(error.localizedDescription)
        } catch {
            openCodeGoState = .failed("OpenCode Go usage is temporarily unavailable.")
        }
    }

    private var codexSummary: ProviderUsageSummary {
        guard let snapshot else {
            return ProviderUsageSummary(
                tab: .codex,
                detail: loadStateDetail(state, unavailable: "Codex unavailable"),
                subdetail: "Usage not loaded",
                secondaryDetail: nil,
                percentUsed: nil,
                resetAt: nil,
                severity: severity(for: state)
            )
        }

        let candidates = [
            snapshot.rateLimit.primary.map { limitCandidate(title: limitTitle(for: $0, fallback: "Primary"), percent: $0.usedPercent, resetTimestamp: $0.resetsAt, durationMinutes: $0.windowDurationMins) },
            snapshot.rateLimit.secondary.map { limitCandidate(title: limitTitle(for: $0, fallback: "Secondary"), percent: $0.usedPercent, resetTimestamp: $0.resetsAt, durationMinutes: $0.windowDurationMins) }
        ].compactMap(\.self)
        let selected = closestActiveLimit(candidates)
        let resetAt = selected?.resetAt
        let percent = selected.map { Double($0.percent) }

        return ProviderUsageSummary(
            tab: .codex,
            detail: selected.map { "\($0.title) \($0.percent)% used" } ?? "Usage unavailable",
            subdetail: resetAt.map { "Resets \(UsageFormatting.timeRemainingText(date: $0, now: now))" } ?? "Reset unknown",
            secondaryDetail: nextLimit(after: selected, in: candidates).map(limitDetail),
            percentUsed: percent,
            resetAt: resetAt,
            severity: UsageSeverity.from(percentUsed: percent)
        )
    }

    private var cursorSummary: ProviderUsageSummary {
        guard let cursorSnapshot else {
            return ProviderUsageSummary(
                tab: .cursor,
                detail: loadStateDetail(cursorState, unavailable: "Cursor unavailable"),
                subdetail: "Usage not loaded",
                secondaryDetail: nil,
                percentUsed: nil,
                resetAt: nil,
                severity: severity(for: cursorState)
            )
        }

        let percent = cursorSnapshot.usedPercent
        return ProviderUsageSummary(
            tab: .cursor,
            detail: "\(Int(percent.rounded()))% used",
            subdetail: cursorSnapshot.billingCycleEnd.map { "Resets \(UsageFormatting.timeRemainingText(date: $0, now: now))" } ?? "Reset unknown",
            secondaryDetail: nil,
            percentUsed: percent,
            resetAt: cursorSnapshot.billingCycleEnd,
            severity: UsageSeverity.from(percentUsed: percent)
        )
    }

    private var desktopQuotaSummary: ProviderUsageSummary {
        guard let quota = desktopQuotaSnapshots.first else {
            return ProviderUsageSummary(
                tab: .devin,
                detail: loadStateDetail(desktopQuotaState, unavailable: "Devin unavailable"),
                subdetail: "Quota not loaded",
                secondaryDetail: nil,
                percentUsed: nil,
                resetAt: nil,
                severity: severity(for: desktopQuotaState)
            )
        }

        let candidates = [
            (quota.dailyUsedPercent, quota.dailyResetAt, 86_400.0, "Daily", 1_440),
            (quota.weeklyUsedPercent, quota.weeklyResetAt, 7 * 86_400.0, "Weekly", 10_080)
        ].compactMap { percent, resetAt, interval, title, durationMinutes -> LimitCandidate? in
            guard !quota.shouldTreatQuotaUsageAsUnavailable, let percent else { return nil }
            return LimitCandidate(
                title: title,
                percent: percent,
                resetAt: resetAt.map { advancedResetDate($0, interval: interval) },
                durationMinutes: Int64(durationMinutes)
            )
        }
        let selected = closestActiveLimit(candidates)
        let percent = selected.map { Double($0.percent) }
        let resetAt = selected?.resetAt

        return ProviderUsageSummary(
            tab: .devin,
            detail: selected.map { "\($0.title) \($0.percent)% used" } ?? "Usage not reported",
            subdetail: resetAt.map { "Resets \(UsageFormatting.timeRemainingText(date: $0, now: now))" } ?? "Reset unknown",
            secondaryDetail: nextLimit(after: selected, in: candidates).map(limitDetail),
            percentUsed: percent,
            resetAt: resetAt,
            severity: UsageSeverity.from(percentUsed: percent)
        )
    }

    private var openCodeGoSummary: ProviderUsageSummary {
        guard let openCodeGoSnapshot, openCodeGoSnapshot.hasUsage else {
            return ProviderUsageSummary(
                tab: .openCodeGo,
                detail: loadStateDetail(openCodeGoState, unavailable: "OpenCode Go unavailable"),
                subdetail: "Usage not loaded",
                secondaryDetail: nil,
                percentUsed: nil,
                resetAt: nil,
                severity: severity(for: openCodeGoState)
            )
        }

        let candidates = [
            (openCodeGoSnapshot.rolling, "Rolling", 300),
            (openCodeGoSnapshot.weekly, "Weekly", 10_080),
            (openCodeGoSnapshot.monthly, "Monthly", 43_200)
        ].compactMap { window, title, durationMinutes -> LimitCandidate? in
            guard let window else { return nil }
            return LimitCandidate(
                title: title,
                percent: Int(window.usedPercent.rounded()),
                resetAt: window.resetAt,
                durationMinutes: Int64(durationMinutes)
            )
        }
        let selected = closestActiveLimit(candidates)
        let percent = selected.map { Double($0.percent) }

        return ProviderUsageSummary(
            tab: .openCodeGo,
            detail: selected.map { "\($0.title) \($0.percent)% used" } ?? "Usage not reported",
            subdetail: selected?.resetAt.map { "Resets \(UsageFormatting.timeRemainingText(date: $0, now: now))" } ?? "Reset unknown",
            secondaryDetail: nextLimit(after: selected, in: candidates).map(limitDetail),
            percentUsed: percent,
            resetAt: selected?.resetAt,
            severity: UsageSeverity.from(percentUsed: percent)
        )
    }

    private func loadStateDetail(_ state: LoadState, unavailable: String) -> String {
        switch state {
        case .idle, .loading:
            return "Loading"
        case .loaded, .failed:
            return unavailable
        }
    }

    private func severity(for state: LoadState) -> UsageSeverity {
        if case .failed = state {
            return .unavailable
        }
        return .healthy
    }

    private func limitCandidate(title: String, percent: Int, resetTimestamp: Int64?, durationMinutes: Int64?) -> LimitCandidate {
        LimitCandidate(
            title: title,
            percent: max(0, min(100, percent)),
            resetAt: resetTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            durationMinutes: durationMinutes ?? Int64.max
        )
    }

    private func closestActiveLimit(_ candidates: [LimitCandidate]) -> LimitCandidate? {
        let sorted = candidates.sorted {
            if $0.durationMinutes != $1.durationMinutes {
                return $0.durationMinutes < $1.durationMinutes
            }
            return $0.percent > $1.percent
        }

        return sorted.first { $0.percent < 100 } ?? sorted.last
    }

    private func nextLimit(after selected: LimitCandidate?, in candidates: [LimitCandidate]) -> LimitCandidate? {
        guard let selected else { return nil }
        return candidates
            .filter { $0.durationMinutes > selected.durationMinutes }
            .sorted {
                if $0.durationMinutes != $1.durationMinutes {
                    return $0.durationMinutes < $1.durationMinutes
                }
                return $0.percent > $1.percent
            }
            .first
    }

    private func limitDetail(_ limit: LimitCandidate) -> String {
        "\(limit.title) \(limit.percent)% used"
    }

    private func limitTitle(for window: RateLimitWindow, fallback: String) -> String {
        guard let minutes = window.windowDurationMins else { return fallback }
        if minutes < 60 {
            return "\(minutes)m"
        }
        if minutes == 1_440 {
            return "Daily"
        }
        if minutes == 10_080 {
            return "Weekly"
        }
        if minutes % 1_440 == 0 {
            return "\(minutes / 1_440)d"
        }
        if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        }
        return fallback
    }

    private func advancedResetDate(_ date: Date, interval: TimeInterval) -> Date {
        var resetDate = date
        while resetDate < now {
            resetDate = resetDate.addingTimeInterval(interval)
        }
        return resetDate
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(300))
            await refresh()
        }
    }

    private func clockLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            now = Date()
        }
    }
}
