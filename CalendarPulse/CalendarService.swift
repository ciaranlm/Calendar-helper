import EventKit
import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

enum CalendarAccessState: Equatable {
    case notDetermined
    case authorized
    case denied
}

enum CalendarServiceError: LocalizedError, Equatable {
    case accessDenied
    case noCalendars
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access is needed to show your schedule."
        case .noCalendars:
            return "No calendars were found."
        case .fetchFailed(let message):
            return "Unable to load calendar events: \(message)"
        }
    }
}

struct CalendarDaySnapshot {
    let timedEvents: [CalendarEvent]
    let allDayEvents: [CalendarEvent]
}

final class CalendarService {
    private let eventStore = EKEventStore()
    private let calendar = Calendar.current

    var accessState: CalendarAccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .authorized, .fullAccess:
            return .authorized
        case .denied, .restricted, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAccessIfNeeded() async -> CalendarAccessState {
        switch accessState {
        case .authorized, .denied:
            return accessState
        case .notDetermined:
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                return granted ? .authorized : .denied
            } catch {
                return .denied
            }
        }
    }

    func fetchToday() throws -> CalendarDaySnapshot {
        try fetchEvents(on: Date())
    }

    func fetchEvents(on date: Date) throws -> CalendarDaySnapshot {
        guard accessState == .authorized else {
            throw CalendarServiceError.accessDenied
        }

        let calendars = eventStore.calendars(for: .event)
        guard !calendars.isEmpty else {
            throw CalendarServiceError.noCalendars
        }

        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) else {
            throw CalendarServiceError.fetchFailed("Could not calculate the end of today.")
        }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = eventStore.events(matching: predicate)
            .filter { event in
                !isDeclinedByCurrentUser(event)
            }
            .map(mapEvent)
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.endDate < rhs.endDate
                }
                return lhs.startDate < rhs.startDate
            }

        return CalendarDaySnapshot(
            timedEvents: events.filter { event in !event.isAllDay },
            allDayEvents: events.filter { event in event.isAllDay }
        )
    }

    func openCalendarApp() {
#if os(macOS)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.open(url)
        }
#endif
    }

    func openPrivacySettings() {
#if os(macOS)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
            ?? URL(string: "x-apple.systempreferences:com.apple.preference.security")!
        NSWorkspace.shared.open(url)
#endif
    }

    private func isDeclinedByCurrentUser(_ event: EKEvent) -> Bool {
        event.attendees?.contains { participant in
            participant.isCurrentUser && participant.participantStatus == EKParticipantStatus.declined
        } ?? false
    }

    private func mapEvent(_ event: EKEvent) -> CalendarEvent {
        let explicitURL = event.url
        let detectedVideoURL = detectVideoURL(in: [event.location, event.notes])

        return CalendarEvent(
            id: event.eventIdentifier ?? UUID().uuidString,
            eventIdentifier: event.eventIdentifier ?? "",
            title: event.title?.isEmpty == false ? event.title : "Untitled Event",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location?.nilIfBlank,
            notes: event.notes?.nilIfBlank,
            calendarTitle: event.calendar.title,
            calendarColor: Color(cgColor: event.calendar.cgColor),
            isAllDay: event.isAllDay,
            url: explicitURL,
            videoCallURL: detectedVideoURL ?? explicitURL
        )
    }

    private func detectVideoURL(in strings: [String?]) -> URL? {
        let videoHosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "webex.com", "facetime.apple.com"]
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

        for text in strings.compactMap({ $0 }) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = detector?.matches(in: text, options: [], range: range) ?? []
            for match in matches {
                guard let url = match.url, let host = url.host(percentEncoded: false)?.lowercased() else { continue }
                if videoHosts.contains(where: { host.contains($0) }) {
                    return url
                }
            }
        }

        return nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
