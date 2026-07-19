import Foundation
import Testing
@testable import LimitLensCore

@Suite("Daily usage chart buckets")
struct DailyUsageChartBucketsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Includes the current day when Codex omits today's bucket")
    func includesCurrentDayWhenOmitted() {
        let now = date(year: 2026, month: 7, day: 17)
        let buckets = [
            AccountTokenUsageDailyBucket(startDate: "2026-07-15", tokens: 100),
            AccountTokenUsageDailyBucket(startDate: "2026-07-16", tokens: 250)
        ]

        let displayed = DailyUsageChartBuckets.displayed(
            from: buckets,
            dayCount: 3,
            now: now,
            calendar: calendar
        )

        #expect(displayed.map(\.startDate) == ["2026-07-15", "2026-07-16", "2026-07-17"])
        #expect(displayed.map(\.tokens) == [100, 250, 0])
    }

    @Test("Preserves today's token count when the API already includes it")
    func preservesExistingCurrentDay() {
        let now = date(year: 2026, month: 7, day: 17)
        let buckets = [
            AccountTokenUsageDailyBucket(startDate: "2026-07-16", tokens: 100),
            AccountTokenUsageDailyBucket(startDate: "2026-07-17", tokens: 42)
        ]

        let displayed = DailyUsageChartBuckets.displayed(
            from: buckets,
            dayCount: 2,
            now: now,
            calendar: calendar
        )

        #expect(displayed.map(\.startDate) == ["2026-07-16", "2026-07-17"])
        #expect(displayed.map(\.tokens) == [100, 42])
    }

    @Test("Fills gaps inside the recent window with zero-token days")
    func fillsGapsWithZeros() {
        let now = date(year: 2026, month: 7, day: 17)
        let buckets = [
            AccountTokenUsageDailyBucket(startDate: "2026-07-14", tokens: 10),
            AccountTokenUsageDailyBucket(startDate: "2026-07-16", tokens: 30)
        ]

        let displayed = DailyUsageChartBuckets.displayed(
            from: buckets,
            dayCount: 4,
            now: now,
            calendar: calendar
        )

        #expect(displayed.map(\.startDate) == [
            "2026-07-14",
            "2026-07-15",
            "2026-07-16",
            "2026-07-17"
        ])
        #expect(displayed.map(\.tokens) == [10, 0, 30, 0])
    }

    @Test("Leaves an empty series untouched")
    func leavesEmptySeriesUntouched() {
        let displayed = DailyUsageChartBuckets.displayed(
            from: [],
            dayCount: 14,
            now: date(year: 2026, month: 7, day: 17),
            calendar: calendar
        )

        #expect(displayed.isEmpty)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 15
        return calendar.date(from: components)!
    }
}
