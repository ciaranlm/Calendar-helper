import Foundation

@MainActor
final class MeetingNudgeManager {
    private struct SentRecord: Codable, Hashable {
        let key: String
        let startDate: Date
    }

    private let notificationManager: NotificationManager
    private let defaults: UserDefaults
    private let sentRecordsKey = "meetingNudgeSentRecords"

    init(notificationManager: NotificationManager = NotificationManager(), defaults: UserDefaults = .standard) {
        self.notificationManager = notificationManager
        self.defaults = defaults
    }

    func requestNotificationPermissionIfNeeded() async -> Bool {
        await notificationManager.requestAuthorizationIfNeeded()
    }

    func check(nextEvent: CalendarEvent?, now: Date, settings: AppSettings) async -> Bool {
        guard settings.meetingNudgesEnabled, let event = nextEvent, !event.isAllDay else { return false }

        let secondsUntilStart = event.startDate.timeIntervalSince(now)
        guard secondsUntilStart > 0, secondsUntilStart <= TimeInterval(settings.nudgeTimeMinutes * 60) else {
            pruneSentRecords(before: now.addingTimeInterval(-24 * 60 * 60))
            return false
        }

        let key = nudgeKey(for: event)
        var records = sentRecords()
        guard !records.contains(where: { $0.key == key }) else { return false }

        records.insert(SentRecord(key: key, startDate: event.startDate))
        save(records)

        _ = await notificationManager.sendMeetingNudge(
            title: event.title,
            startDate: event.startDate,
            identifier: "meeting-nudge-\(key)",
            nudgeMinutes: settings.nudgeTimeMinutes,
            playSound: settings.playNudgeSound
        )

        return true
    }

    private func nudgeKey(for event: CalendarEvent) -> String {
        let stableEventID = event.eventIdentifier.isEmpty ? event.id : event.eventIdentifier
        return "\(stableEventID)-\(Int(event.startDate.timeIntervalSince1970))"
            .replacingOccurrences(of: "[^A-Za-z0-9-]", with: "-", options: .regularExpression)
    }

    private func sentRecords() -> Set<SentRecord> {
        guard let data = defaults.data(forKey: sentRecordsKey),
              let records = try? JSONDecoder().decode(Set<SentRecord>.self, from: data) else {
            return []
        }
        return records
    }

    private func save(_ records: Set<SentRecord>) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: sentRecordsKey)
    }

    private func pruneSentRecords(before date: Date) {
        let records = sentRecords().filter { $0.startDate >= date }
        save(Set(records))
    }
}
