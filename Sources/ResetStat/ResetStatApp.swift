import AppKit
import ResetStatCore
import SwiftUI

@main
struct ResetStatApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            ResetStatPopover(viewModel: viewModel)
                .frame(width: 460)
                .onAppear {
                    viewModel.start()
                    Task { await viewModel.refresh() }
                }
        } label: {
            MenuBarStatusLabel(title: viewModel.menuBarTitle, severity: viewModel.menuBarSeverity)
        }
        .menuBarExtraStyle(.window)
    }
}

enum ProviderTab: String, CaseIterable, Identifiable {
    case overview
    case codex
    case cursor
    case devin
    case openCodeGo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .devin: return "Devin"
        case .openCodeGo: return "OpenCode Go"
        }
    }

    var privateName: String {
        switch self {
        case .overview: return "Overview"
        case .codex: return "Provider 1"
        case .cursor: return "Provider 2"
        case .devin: return "Provider 3"
        case .openCodeGo: return "Provider 4"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "speedometer"
        case .codex: return "terminal"
        case .cursor: return "cursorarrow"
        case .devin: return "sparkles"
        case .openCodeGo: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct ResetStatPopover: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showsResetCreditDetails = false
    @State private var selectedTab: ProviderTab = .overview

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            tabBar

            switch viewModel.state {
            case .idle, .loading:
                loadingView
            case .loaded:
                contentView
            case .failed(let message):
                errorView(message: message)
            }

            footer
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            SMark()
            VStack(alignment: .leading, spacing: 2) {
                Text("ResetStat")
                    .font(.headline.weight(.semibold))
                Text("Personal AI Usage Dashboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .overview:
            overviewSection
        case .codex:
            if let snapshot = viewModel.snapshot {
                codexSection(snapshot)
            } else {
                unavailableView
            }
        case .cursor:
            cursorSection
        case .devin:
            desktopQuotaSection
        case .openCodeGo:
            openCodeGoSection
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(ProviderTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.bottom, 2)
    }

    private func tabButton(for tab: ProviderTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: providerIcon(tab.systemImage))
                    .font(.system(size: 10, weight: .semibold))
                Text(providerName(tab.displayName, privateName: tab.privateName))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor))
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(providerName(tab.displayName, privateName: tab.privateName))
    }

    private var loadingView: some View {
        StatusLine(icon: "hourglass", color: .secondary, text: "Loading usage...")
            .padding(.vertical, 18)
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch selectedTab {
            case .overview:
                overviewSection
            case .codex:
                if let snapshot = viewModel.snapshot {
                    codexSection(snapshot)
                }
                SectionBlock {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message))
                }
            case .cursor:
                cursorSection
            case .devin:
                desktopQuotaSection
            case .openCodeGo:
                openCodeGoSection
            }
        }
    }

    private var unavailableView: some View {
        SectionBlock {
            Text("Usage data is temporarily unavailable.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
    }

    private var footer: some View {
        HStack {
            if let fetchedAt = latestFetchDate {
                Text("Updated \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                viewModel.hidesProviderNames.toggle()
            } label: {
                Image(systemName: viewModel.hidesProviderNames ? "circle.fill" : "circle")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(viewModel.hidesProviderNames ? Color.accentColor : Color.secondary.opacity(0.55))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .help(viewModel.hidesProviderNames ? "Show provider names" : "Hide provider names")
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    private var latestFetchDate: Date? {
        ([viewModel.snapshot?.fetchedAt, viewModel.cursorSnapshot?.fetchedAt, viewModel.openCodeGoSnapshot?.fetchedAt]
            + viewModel.desktopQuotaSnapshots.map(\.fetchedAt))
            .compactMap(\.self)
            .max()
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var overviewSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Overview",
                    detail: overviewDetail,
                    systemImage: "speedometer"
                )

                billingExpirySection

                Divider()

                VStack(spacing: 8) {
                    ForEach(viewModel.providerSummaries) { summary in
                        overviewRow(summary)
                    }
                }
            }
        }
    }

    private var overviewDetail: String {
        let criticalCount = viewModel.providerSummaries.filter { $0.severity == .critical }.count
        if criticalCount > 0 {
            return "\(criticalCount) critical"
        }

        let warningCount = viewModel.providerSummaries.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            return "\(warningCount) warning"
        }

        let unavailableCount = viewModel.providerSummaries.filter { $0.severity == .unavailable }.count
        if unavailableCount > 0 {
            return "\(unavailableCount) unavailable"
        }

        return "All clear"
    }

    private func overviewRow(_ summary: ProviderUsageSummary) -> some View {
        Button {
            selectedTab = summary.tab
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(severityColor(summary.severity).opacity(0.16))
                    Image(systemName: providerIcon(summary.tab.systemImage))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(severityColor(summary.severity))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(providerName(summary.tab.displayName, privateName: summary.tab.privateName))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(providerSafeMessage(summary.subdetail))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(providerSafeMessage(summary.detail))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(summary.severity == .unavailable ? .secondary : .primary)
                    if let secondaryDetail = summary.secondaryDetail {
                        Text(providerSafeMessage(secondaryDetail))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(" ")
                            .font(.caption2.weight(.medium))
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var billingExpirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Billing & renewals")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(billingSummaryDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(viewModel.billingExpiries) { entry in
                    billingExpiryCell(entry)
                }
            }
        }
    }

    private func billingExpiryCell(_ entry: BillingExpiry) -> some View {
        let primaryText: String = entry.date.map { UsageFormatting.resetText(date: $0, now: viewModel.now) } ?? entry.amountText ?? "—"
        let secondaryText: String = entry.date.map { UsageFormatting.relativeDayText(date: $0, now: viewModel.now) } ?? entry.detailText ?? "No billing"
        let primaryColor: Color = entry.date == nil && entry.amountText == nil ? .secondary : (entry.date == nil ? .primary : expiryColor(entry.urgency))
        return HStack(spacing: 8) {
            Image(systemName: providerIcon(entry.tab.systemImage))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(expiryColor(entry.urgency))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(providerShortName(entry.tab))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(primaryText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                Text(secondaryText)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var billingSummaryDetail: String {
        let expiring = viewModel.billingExpiries.filter { $0.urgency == .expired || $0.urgency == .soon }.count
        if expiring > 0 { return "\(expiring) expiring soon" }
        let warn = viewModel.billingExpiries.filter { $0.urgency == .warning }.count
        if warn > 0 { return "\(warn) within 2w" }
        let healthy = viewModel.billingExpiries.filter { $0.urgency == .healthy }.count
        if healthy > 0 { return "Up to date" }
        return "—"
    }

    private func expiryColor(_ urgency: UsageFormatting.ExpiryUrgency) -> Color {
        switch urgency {
        case .expired: return .red
        case .soon: return .orange
        case .warning: return .yellow
        case .healthy: return .green
        case .unknown: return .secondary
        }
    }

    private func providerShortName(_ tab: ProviderTab) -> String {
        if viewModel.hidesProviderNames {
            switch tab {
            case .codex: return "P1"
            case .cursor: return "P2"
            case .devin: return "P3"
            case .openCodeGo: return "P4"
            default: return tab.privateName
            }
        }
        switch tab {
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .devin: return "Devin"
        case .openCodeGo: return "Go"
        default: return tab.displayName
        }
    }

    private func codexSection(_ snapshot: ResetStatSnapshot) -> some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: providerName("Codex", privateName: "Provider 1"),
                    detail: codexHeaderDetail(snapshot),
                    systemImage: "terminal"
                )

                VStack(spacing: 10) {
                    resetWindowView(title: "Primary", window: snapshot.rateLimit.primary, tint: .blue)
                    resetWindowView(title: "Secondary", window: snapshot.rateLimit.secondary, tint: .cyan)
                }

                Divider()

                resetCreditsView(snapshot.resetCredits)

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                    MetricTile(
                        title: "Lifetime tokens",
                        value: UsageFormatting.compactNumber(snapshot.tokenUsage?.lifetimeTokens)
                    )
                    MetricTile(
                        title: "Peak daily",
                        value: UsageFormatting.compactNumber(snapshot.tokenUsage?.peakDailyTokens)
                    )
                    MetricTile(
                        title: "Current streak",
                        value: streakText(snapshot.tokenUsage?.currentStreakDays)
                    )
                }

                if !snapshot.dailyUsageBuckets.isEmpty {
                    Divider()
                    DailyUsageChart(buckets: snapshot.dailyUsageBuckets)
                }
            }
        }
    }

    private func resetCreditsView(_ credits: ResetCreditInfo) -> some View {
        let expiry = resetCreditExpiry(credits)
        let expiringCredits = sortedExpiringCredits(credits)
        let canExpand = !expiringCredits.isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reset credits")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(resetCreditAvailabilityText(credits))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(credits.availableCount)")
                    .font(.callout.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(expiry.text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(expiry.color)
                        .lineLimit(1)
                    Text(expiry.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    showsResetCreditDetails.toggle()
                } label: {
                    HStack(spacing: 4) {
                        if canExpand {
                            Image(systemName: showsResetCreditDetails ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canExpand)
                .help(canExpand ? "Show all reset credit expiries" : "No additional reset credits")
            }

            if showsResetCreditDetails, canExpand {
                VStack(spacing: 7) {
                    ForEach(Array(expiringCredits.enumerated()), id: \.offset) { index, credit in
                        resetCreditDetailRow(index: index, credit: credit)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var cursorSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: providerName("Cursor", privateName: "Provider 2"), detail: cursorHeaderDetail, systemImage: "cursorarrow")

                if let cursor = viewModel.cursorSnapshot {
                    cursorUsageView(cursor)
                } else if case .loading = viewModel.cursorState {
                    StatusLine(icon: "hourglass", color: .secondary, text: "Loading provider usage...")
                } else if case .failed(let message) = viewModel.cursorState {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message))
                } else {
                    StatusLine(icon: "minus.circle", color: .secondary, text: "Provider usage unavailable.")
                }
            }
        }
    }

    private var cursorHeaderDetail: String? {
        if let plan = viewModel.cursorSnapshot?.planName {
            return plan
        }
        if case .failed = viewModel.cursorState {
            return "Unavailable"
        }
        return nil
    }

    @ViewBuilder
    private var desktopQuotaSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: providerName("Devin", privateName: "Provider 3"),
                    detail: desktopQuotaHeaderDetail,
                    systemImage: "sparkles"
                )

                if !viewModel.desktopQuotaSnapshots.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(viewModel.desktopQuotaSnapshots, id: \.appName) { quota in
                            desktopQuotaView(quota)
                        }
                    }
                } else if case .loading = viewModel.desktopQuotaState {
                    StatusLine(icon: "hourglass", color: .secondary, text: "Checking Devin quota...")
                } else if case .failed(let message) = viewModel.desktopQuotaState {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message))
                } else {
                    StatusLine(icon: "minus.circle", color: .secondary, text: "Devin quota unavailable.")
                }
            }
        }
    }

    private func providerName(_ name: String, privateName: String) -> String {
        viewModel.hidesProviderNames ? privateName : name
    }

    private func providerSafeMessage(_ message: String) -> String {
        guard viewModel.hidesProviderNames else { return message }
        return message
            .replacingOccurrences(of: "Codex", with: "Provider")
            .replacingOccurrences(of: "Cursor", with: "Provider")
            .replacingOccurrences(of: "Devin", with: "Provider")
            .replacingOccurrences(of: "OpenCode Go", with: "Provider")
            .replacingOccurrences(of: "OpenCode", with: "Provider")
    }

    private var desktopQuotaHeaderDetail: String? {
        viewModel.desktopQuotaSnapshots.first?.planName?.nilIfEmpty
    }

    @ViewBuilder
    private var openCodeGoSection: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: providerName("OpenCode Go", privateName: "Provider 4"),
                    detail: openCodeGoHeaderDetail,
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )

                if let snapshot = viewModel.openCodeGoSnapshot, snapshot.hasUsage {
                    openCodeGoUsageView(snapshot)
                    if let billing = snapshot.billing {
                        Divider()
                        openCodeGoBillingView(billing)
                    }
                } else if case .loading = viewModel.openCodeGoState {
                    StatusLine(icon: "hourglass", color: .secondary, text: "Checking OpenCode Go usage...")
                } else if case .failed(let message) = viewModel.openCodeGoState {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message))
                } else {
                    StatusLine(icon: "minus.circle", color: .secondary, text: "OpenCode Go usage unavailable.")
                }
            }
        }
    }

    private var openCodeGoHeaderDetail: String? {
        viewModel.openCodeGoSnapshot?.source?.nilIfEmpty ?? "Go"
    }

    private func codexHeaderDetail(_ snapshot: ResetStatSnapshot) -> String? {
        let plan = UsageFormatting.planTitle(snapshot.rateLimit.planType)
        guard let billingDate = snapshot.planExpiresAt else {
            return "\(plan) · Renewal unavailable"
        }
        return "\(plan) · Renews \(UsageFormatting.resetText(date: billingDate, now: viewModel.now))"
    }

    private func sectionHeader(title: String, detail: String?, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: providerIcon(systemImage))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func providerIcon(_ systemImage: String) -> String {
        viewModel.hidesProviderNames ? "circle.grid.2x2" : systemImage
    }

    private func resetWindowView(title: String, window: RateLimitWindow?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(UsageFormatting.timeRemainingText(timestamp: window?.resetsAt, now: viewModel.now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ProgressView(value: Double(window?.usedPercent ?? 0), total: 100)
                .tint(tint)

            HStack {
                Text("\(window?.usedPercent ?? 0)% used")
                Spacer()
                Text("Resets \(UsageFormatting.resetText(timestamp: window?.resetsAt, now: viewModel.now))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func cursorUsageView(_ cursor: CursorUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(cursor.usedPercent.rounded()))% used")
                        .font(.title3.weight(.semibold))
                    Text("Resets \(cursorResetText(cursor.billingCycleEnd))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(UsageFormatting.usd(cents: cursor.remainingCents))
                        .font(.callout.weight(.semibold))
                    Text("of \(UsageFormatting.usd(cents: cursor.limitCents)) left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: cursor.usedPercent, total: 100)
                .tint(.purple)

            if cursor.autoPercentUsed != nil || cursor.apiPercentUsed != nil {
                VStack(spacing: 9) {
                    cursorLimitView(
                        title: "Auto",
                        percentUsed: cursor.autoPercentUsed,
                        spendCents: cursor.autoSpendCents,
                        limitCents: cursor.autoLimitCents,
                        tint: .purple
                    )
                    cursorLimitView(
                        title: "API",
                        percentUsed: cursor.apiPercentUsed,
                        spendCents: cursor.apiSpendCents,
                        limitCents: cursor.apiLimitCents,
                        tint: .indigo
                    )
                }
                .padding(.top, 2)
            }
        }
    }

    private func cursorLimitView(
        title: String,
        percentUsed: Double?,
        spendCents: Int?,
        limitCents: Int?,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(percentText(percentUsed))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ProgressView(value: percentUsed ?? 0, total: 100)
                .tint(tint)

            if spendCents != nil || limitCents != nil {
                HStack {
                    Text("\(UsageFormatting.usd(cents: spendCents)) used")
                    Spacer()
                    Text("Limit \(UsageFormatting.usd(cents: limitCents))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func desktopQuotaView(_ quota: DesktopQuotaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            quotaBar(
                title: "Daily",
                usedPercent: quota.dailyUsedPercent,
                isUnavailable: quota.shouldTreatQuotaUsageAsUnavailable,
                resetAt: advancedResetDate(quota.dailyResetAt, interval: 86_400),
                tint: .green
            )
            quotaBar(
                title: "Weekly",
                usedPercent: quota.weeklyUsedPercent,
                isUnavailable: quota.shouldTreatQuotaUsageAsUnavailable,
                resetAt: advancedResetDate(quota.weeklyResetAt, interval: 7 * 86_400),
                tint: .orange
            )

            if quota.overageBalanceMicros != nil || quota.cycleEnd != nil {
                Divider()

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Extra usage balance")
                            .font(.caption.weight(.semibold))
                        if let cycleEnd = quota.cycleEnd {
                            Text("Plan ends \(UsageFormatting.resetText(date: cycleEnd, now: viewModel.now))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(UsageFormatting.usd(micros: quota.overageBalanceMicros))
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private func openCodeGoUsageView(_ snapshot: OpenCodeGoUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            openCodeGoUsageBar(title: "Rolling", window: snapshot.rolling, tint: .mint)
            openCodeGoUsageBar(title: "Weekly", window: snapshot.weekly, tint: .orange)
            openCodeGoUsageBar(title: "Monthly", window: snapshot.monthly, tint: .blue)
        }
    }

    private func openCodeGoBillingView(_ billing: OpenCodeGoBilling) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Billing")
                    .font(.caption.weight(.semibold))
                Spacer()
                if billing.autoReloadEnabled {
                    Text("Auto-reload on")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current balance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(billing.balanceText ?? "—")
                        .font(.callout.weight(.semibold))
                }
                Spacer()
                if let last4 = billing.cardLast4 {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("•••• \(last4)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !billing.payments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Payments")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 5) {
                        ForEach(Array(billing.payments.prefix(5).enumerated()), id: \.offset) { _, payment in
                            HStack(alignment: .firstTextBaseline) {
                                Text(payment.dateText.isEmpty ? (payment.date.map { UsageFormatting.resetText(date: $0, now: viewModel.now) } ?? "—") : payment.dateText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(payment.amountText.isEmpty ? "—" : payment.amountText)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(payment.refunded ? .secondary : .primary)
                                    .strikethrough(payment.refunded)
                                if payment.refunded {
                                    Text("refunded")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func openCodeGoUsageBar(title: String, window: OpenCodeGoUsageWindow?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(UsageFormatting.timeRemainingText(date: window?.resetAt, now: viewModel.now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(window?.resetAt == nil ? .secondary : .primary)
            }

            ProgressView(value: window?.usedPercent ?? 0, total: 100)
                .tint(tint)

            HStack {
                Text(window.map { "\(Int($0.usedPercent.rounded()))% used" } ?? "Usage not reported")
                Spacer()
                Text("Resets \(quotaResetText(window?.resetAt))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func quotaBar(
        title: String,
        usedPercent: Int?,
        isUnavailable: Bool,
        resetAt: Date?,
        tint: Color
    ) -> some View {
        let displayedPercent = isUnavailable ? nil : usedPercent
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(resetAt.map { UsageFormatting.timeRemainingText(date: $0, now: viewModel.now) } ?? "Unknown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(resetAt == nil ? .secondary : .primary)
            }

            ProgressView(value: Double(displayedPercent ?? 0), total: 100)
                .tint(tint)

            HStack {
                Text(displayedPercent.map { "\($0)% used" } ?? "Usage not reported")
                Spacer()
                Text("Resets \(quotaResetText(resetAt))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func resetCreditExpiry(_ credits: ResetCreditInfo) -> (text: String, detail: String, color: Color) {
        guard credits.availableCount > 0 else {
            return ("None available", "No reset credits to spend", .secondary)
        }
        guard let expiresAt = credits.nextExpiringCredit?.expiresAt else {
            return ("Expiry not reported", "Credit dates unavailable", .secondary)
        }

        let text = "Expires \(UsageFormatting.relativeDayText(date: expiresAt, now: viewModel.now))"
        let detail = UsageFormatting.resetText(date: expiresAt, now: viewModel.now)
        switch UsageFormatting.expiryUrgency(expiresAt: expiresAt, now: viewModel.now) {
        case .expired, .soon:
            return (text, detail, .red)
        case .warning:
            return (text, detail, .yellow)
        case .healthy:
            return (text, detail, .green)
        case .unknown:
            return (text, detail, .secondary)
        }
    }

    private func resetCreditAvailabilityText(_ credits: ResetCreditInfo) -> String {
        guard let total = credits.totalEarnedCount, total >= credits.availableCount, total > 0 else {
            return credits.availableCount == 1 ? "1 available" : "\(credits.availableCount) available"
        }
        return "\(credits.availableCount) of \(total) available"
    }

    private func resetCreditDetailRow(index: Int, credit: ResetCredit) -> some View {
        let expiry = resetCreditExpiry(date: credit.expiresAt)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(credit.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Credit \(index + 1)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(resetCreditSubtitle(credit))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expiry.text)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(expiry.color)
                    .lineLimit(1)
                Text(expiry.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func resetCreditExpiry(date: Date?) -> (text: String, detail: String, color: Color) {
        guard let date else {
            return ("Expiry unknown", "Date unavailable", .secondary)
        }

        let text = UsageFormatting.relativeDayText(date: date, now: viewModel.now)
        let detail = UsageFormatting.resetText(date: date, now: viewModel.now)
        switch UsageFormatting.expiryUrgency(expiresAt: date, now: viewModel.now) {
        case .expired, .soon:
            return (text, detail, .red)
        case .warning:
            return (text, detail, .yellow)
        case .healthy:
            return (text, detail, .green)
        case .unknown:
            return (text, detail, .secondary)
        }
    }

    private func resetCreditSubtitle(_ credit: ResetCredit) -> String {
        [credit.resetType, credit.status]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
            .joined(separator: " · ")
            .nilIfEmpty ?? "Reset credit"
    }

    private func sortedExpiringCredits(_ credits: ResetCreditInfo) -> [ResetCredit] {
        credits.credits
            .filter { $0.expiresAt != nil }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }

    private func streakText(_ days: Int64?) -> String {
        guard let days else { return "--" }
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func cursorResetText(_ date: Date?) -> String {
        guard let date else { return "unknown" }
        return UsageFormatting.resetText(date: date, now: viewModel.now)
    }

    private func quotaResetText(_ date: Date?) -> String {
        guard let date else { return "unknown" }
        return UsageFormatting.resetText(date: date, now: viewModel.now)
    }

    private func advancedResetDate(_ date: Date?, interval: TimeInterval) -> Date? {
        guard var date else { return nil }
        while date < viewModel.now {
            date = date.addingTimeInterval(interval)
        }
        return date
    }

    private func quotaPercentText(_ remainingPercent: Int?) -> String {
        guard let remainingPercent else { return "-- remaining" }
        return "\(remainingPercent)% remaining"
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    private func severityColor(_ severity: UsageSeverity) -> Color {
        switch severity {
        case .critical:
            return .red
        case .warning:
            return .orange
        case .healthy:
            return .green
        case .unavailable:
            return .secondary
        }
    }
}

private struct MenuBarStatusLabel: View {
    let title: String
    let severity: UsageSeverity

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(color)
    }

    private var color: Color {
        switch severity {
        case .critical:
            return .red
        case .warning:
            return .orange
        case .healthy, .unavailable:
            return .primary
        }
    }
}

private struct SectionBlock<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DailyUsageChart: View {
    let buckets: [AccountTokenUsageDailyBucket]

    private var displayedBuckets: [AccountTokenUsageDailyBucket] {
        Array(buckets.sorted { $0.startDate < $1.startDate }.suffix(14))
    }

    private var maxTokens: Int64 {
        max(displayedBuckets.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Codex tokens")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(displayedBuckets.count)d")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(displayedBuckets.enumerated()), id: \.offset) { _, bucket in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.accentColor.opacity(0.78))
                            .frame(height: barHeight(for: bucket.tokens))
                        Text(dayLabel(bucket.startDate))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .bottom)
                    .help("\(UsageFormatting.compactNumber(bucket.tokens)) tokens")
                }
            }
            .frame(height: 62)
        }
    }

    private func barHeight(for tokens: Int64) -> CGFloat {
        let ratio = CGFloat(Double(tokens) / Double(maxTokens))
        return max(4, ratio * 42)
    }

    private func dayLabel(_ startDate: String) -> String {
        guard let day = startDate.split(separator: "-").last else { return startDate }
        return String(day)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    var caption: String?
    var captionColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(captionColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
    }
}

private struct StatusLine: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SMark: View {
    var body: some View {
        Text("S")
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.11, blue: 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(red: 0.22, green: 0.38, blue: 0.58), lineWidth: 1)
            )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
