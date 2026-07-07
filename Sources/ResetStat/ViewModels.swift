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

enum MenuBarIndicatorState: Equatable {
    case loading
    case healthy
    case warning
    case critical
    case stale(UsageSeverity)
    case unavailable
}

struct MenuBarProviderIndicator: Identifiable, Equatable {
    let tab: ProviderTab
    let state: MenuBarIndicatorState
    let percentUsed: Double?
    let message: String
    let barGlyph: String

    var id: ProviderTab { tab }
}

struct MenuBarStatusSnapshot: Equatable {
    let title: String
    let severity: UsageSeverity
    let indicators: [MenuBarProviderIndicator]
    let helpText: String
    let accessibilityLabel: String
    let isRefreshing: Bool
    let hidesProviderNames: Bool
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
    @Published private(set) var isRefreshing = false
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
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

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

    var menuBarStatus: MenuBarStatusSnapshot {
        let summaries = providerSummaries
        let indicators = summaries.map { menuBarIndicator(for: $0) }

        let hasUnavailableOrStale = indicators.contains { indicator in
            switch indicator.state {
            case .stale, .unavailable:
                return true
            case .loading, .healthy, .warning, .critical:
                return false
            }
        }

        let title = indicators.map(\.barGlyph).joined(separator: " ")
        let severity = hasUnavailableOrStale
            ? .unavailable
            : (summaries.map(\.severity).max() ?? .healthy)

        let helpText = indicators.map { indicatorHelpText($0) }.joined(separator: ", ")
        return MenuBarStatusSnapshot(
            title: title,
            severity: severity,
            indicators: indicators,
            helpText: helpText,
            accessibilityLabel: helpText,
            isRefreshing: isRefreshing,
            hidesProviderNames: hidesProviderNames
        )
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

    private func menuBarIndicator(for summary: ProviderUsageSummary) -> MenuBarProviderIndicator {
        let state = menuBarIndicatorState(
            loadState: loadState(for: summary.tab),
            hasSnapshot: hasUsableSnapshot(for: summary.tab),
            severity: summary.severity
        )
        return MenuBarProviderIndicator(
            tab: summary.tab,
            state: state,
            percentUsed: summary.percentUsed,
            message: menuBarMessage(for: summary, state: state),
            barGlyph: barGlyph(for: state, percentUsed: summary.percentUsed)
        )
    }

    private func menuBarIndicatorState(
        loadState: LoadState,
        hasSnapshot: Bool,
        severity: UsageSeverity
    ) -> MenuBarIndicatorState {
        switch loadState {
        case .idle, .loading:
            return hasSnapshot ? menuBarIndicatorState(for: severity) : .loading
        case .failed:
            return hasSnapshot ? .stale(severity) : .unavailable
        case .loaded:
            return menuBarIndicatorState(for: severity)
        }
    }

    private func menuBarIndicatorState(for severity: UsageSeverity) -> MenuBarIndicatorState {
        switch severity {
        case .critical:
            return .critical
        case .warning:
            return .warning
        case .healthy:
            return .healthy
        case .unavailable:
            return .unavailable
        }
    }

    private func menuBarMessage(for summary: ProviderUsageSummary, state: MenuBarIndicatorState) -> String {
        let name = hidesProviderNames ? summary.tab.privateName : summary.tab.displayName
        let stateDetail = menuBarStateDetail(state, percentUsed: summary.percentUsed)
        switch state {
        case .loading, .unavailable:
            return "\(name) \(stateDetail)"
        case .healthy, .warning, .critical, .stale:
            return "\(name) \(providerSafeDetail(summary.detail)) (\(stateDetail)), \(providerSafeDetail(summary.subdetail))"
        }
    }

    private func indicatorHelpText(_ indicator: MenuBarProviderIndicator) -> String {
        guard isRefreshing, indicatorShowsCachedData(indicator.state) else {
            return indicator.message
        }

        let name = hidesProviderNames ? indicator.tab.privateName : indicator.tab.displayName
        let detail = menuBarStateDetail(indicator.state, percentUsed: indicator.percentUsed, isRefreshing: true)
        return "\(name) \(detail)"
    }

    private func menuBarStateDetail(
        _ state: MenuBarIndicatorState,
        percentUsed: Double?,
        isRefreshing: Bool = false
    ) -> String {
        let prefix = isRefreshing ? "refreshing " : ""
        switch state {
        case .loading:
            return "loading"
        case .healthy:
            return "\(prefix)healthy\(percentSuffix(percentUsed))"
        case .warning:
            return "\(prefix)warning\(percentSuffix(percentUsed))"
        case .critical:
            return "\(prefix)critical\(percentSuffix(percentUsed))"
        case .stale(let severity):
            return "stale \(severityText(severity))\(percentSuffix(percentUsed))"
        case .unavailable:
            return "unavailable"
        }
    }

    private func indicatorShowsCachedData(_ state: MenuBarIndicatorState) -> Bool {
        switch state {
        case .healthy, .warning, .critical:
            return true
        case .loading, .stale, .unavailable:
            return false
        }
    }

    private func percentSuffix(_ percentUsed: Double?) -> String {
        guard let percentUsed else { return "" }
        return " \(Int(percentUsed.rounded()))%"
    }

    private func providerSafeDetail(_ detail: String) -> String {
        guard hidesProviderNames else { return detail }
        return detail
            .replacingOccurrences(of: "Codex", with: "Provider")
            .replacingOccurrences(of: "Cursor", with: "Provider")
            .replacingOccurrences(of: "Devin", with: "Provider")
            .replacingOccurrences(of: "OpenCode Go", with: "Provider")
            .replacingOccurrences(of: "OpenCode", with: "Provider")
    }

    private func barGlyph(for state: MenuBarIndicatorState, percentUsed: Double?) -> String {
        switch state {
        case .loading:
            return "·"
        case .unavailable:
            return "?"
        case .healthy, .warning, .critical, .stale:
            return usageBarGlyph(percentUsed: percentUsed)
        }
    }

    private func usageBarGlyph(percentUsed: Double?) -> String {
        guard let percentUsed else { return "?" }
        let clamped = max(0, min(100, percentUsed))
        switch clamped {
        case 0..<12.5:
            return "▁"
        case 12.5..<25:
            return "▂"
        case 25..<37.5:
            return "▃"
        case 37.5..<50:
            return "▄"
        case 50..<62.5:
            return "▅"
        case 62.5..<75:
            return "▆"
        case 75..<87.5:
            return "▇"
        default:
            return "█"
        }
    }

    private func severityText(_ severity: UsageSeverity) -> String {
        switch severity {
        case .critical:
            return "critical"
        case .warning:
            return "warning"
        case .healthy:
            return "healthy"
        case .unavailable:
            return "unavailable"
        }
    }

    private func loadState(for tab: ProviderTab) -> LoadState {
        switch tab {
        case .codex:
            return state
        case .cursor:
            return cursorState
        case .devin:
            return desktopQuotaState
        case .openCodeGo:
            return openCodeGoState
        case .overview:
            return .loaded
        }
    }

    private func hasUsableSnapshot(for tab: ProviderTab) -> Bool {
        switch tab {
        case .codex:
            return snapshot != nil
        case .cursor:
            return cursorSnapshot != nil
        case .devin:
            return !desktopQuotaSnapshots.isEmpty
        case .openCodeGo:
            return openCodeGoSnapshot?.hasUsage == true
        case .overview:
            return true
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
            await refresh()
            try? await Task.sleep(for: .seconds(300))
        }
    }

    private func clockLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            now = Date()
        }
    }
}
