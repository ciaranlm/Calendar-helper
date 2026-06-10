import Foundation
import UserNotifications

final class NotificationManager {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func sendMeetingNudge(title eventTitle: String, startDate: Date, identifier: String, nudgeMinutes: Int, playSound: Bool) async -> Bool {
        guard await requestAuthorizationIfNeeded() else { return false }

        let content = UNMutableNotificationContent()
        content.title = nudgeMinutes == 1 ? "Meeting starts in 1 minute" : "Meeting starts in \(nudgeMinutes) minutes"
        content.body = "\(eventTitle) starts at \(DateFormatter.pulseTimeFormatter.string(from: startDate))"
        if playSound {
            content.sound = .default
        }

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}
