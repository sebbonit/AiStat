import Foundation

/// Builds a contiguous daily chart window ending on the current local day.
///
/// Codex profile usage often omits today's still-open bucket. Filling that day
/// (and any gaps) keeps the Recent Codex tokens chart aligned to "now".
public enum DailyUsageChartBuckets {
    public static func displayed(
        from buckets: [AccountTokenUsageDailyBucket],
        dayCount: Int = 14,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [AccountTokenUsageDailyBucket] {
        guard dayCount > 0, !buckets.isEmpty else { return buckets }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) else {
            return buckets.sorted { $0.startDate < $1.startDate }
        }

        let tokensByDay = Dictionary(
            buckets.map { ($0.startDate, $0.tokens) },
            uniquingKeysWith: { _, latest in latest }
        )

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: windowStart) else {
                return nil
            }
            let startDate = formatter.string(from: day)
            return AccountTokenUsageDailyBucket(
                startDate: startDate,
                tokens: tokensByDay[startDate] ?? 0
            )
        }
    }
}
