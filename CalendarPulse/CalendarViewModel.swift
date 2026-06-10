import Combine
import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
final class CalendarViewModel: ObservableObject {
    enum StatusKind: Equatable {
        case loading
        case free
        case nextSoon
        case busy
        case done
        case noAccess
        case error
    }

    struct Status {
        let kind: StatusKind
        let menuText: String
        let title: String
        let detail: String
        let color: Color
        let symbolName: String
    }

    @Published private(set) var accessState: CalendarAccessState = .notDetermined
    @Published private(set) var timedEvents: [CalendarEvent] = []
    @Published private(set) var allDayEvents: [CalendarEvent] = []
    @Published private(set) var freeBlocks: [FreeBlock] = []
    @Published private(set) var currentEvent: CalendarEvent?
    @Published private(set) var nextEvent: CalendarEvent?
    @Published private(set) var status: Status = .loading
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastRefreshDate: Date?

    private let service: CalendarService
    private let settings: AppSettings
    private var timer: Timer?

    init(service: CalendarService = CalendarService(), settings: AppSettings = .shared) {
        self.service = service
        self.settings = settings
        self.accessState = service.accessState
        configureTimer()
    }

    func start() {
        configureTimer()
        Task { await refresh(requestPermission: true) }
    }

    func popoverOpened() {
        Task { await refresh(requestPermission: true) }
    }

    func refresh(requestPermission: Bool = false) async {
        isLoading = true
        errorMessage = nil

        if requestPermission {
            accessState = await service.requestAccessIfNeeded()
        } else {
            accessState = service.accessState
        }

        guard accessState == .authorized else {
            clearSchedule()
            status = Status(
                kind: .noAccess,
                menuText: "No access",
                title: "No calendar access",
                detail: "Calendar access is needed to show your schedule.",
                color: .gray,
                symbolName: "calendar.badge.exclamationmark"
            )
            isLoading = false
            return
        }

        do {
            let snapshot = try service.fetchToday()
            timedEvents = snapshot.timedEvents
            allDayEvents = snapshot.allDayEvents
            recalculate(now: Date())
            lastRefreshDate = Date()
        } catch {
            clearSchedule()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            status = Status(
                kind: .error,
                menuText: "No data",
                title: "Calendar unavailable",
                detail: errorMessage ?? "Unable to load calendar events.",
                color: .gray,
                symbolName: "exclamationmark.triangle"
            )
        }

        isLoading = false
    }

    func settingsChanged() {
        configureTimer()
        recalculate(now: Date())
    }

    func openCalendar() {
        service.openCalendarApp()
    }

    func openPrivacySettings() {
        service.openPrivacySettings()
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func relativeDuration(from start: Date, to end: Date) -> String {
        Self.compactDuration(end.timeIntervalSince(start))
    }

    static func compactDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(ceil(interval / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.refreshIntervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        timer?.tolerance = min(10, TimeInterval(settings.refreshIntervalSeconds) * 0.1)
    }

    private func recalculate(now: Date) {
        currentEvent = timedEvents.first { $0.startDate <= now && now < $0.endDate }
        nextEvent = timedEvents.first { $0.startDate > now }
        freeBlocks = calculateFreeBlocks(now: now)
        status = calculateStatus(now: now)
    }

    private func calculateStatus(now: Date) -> Status {
        if let currentEvent {
            let duration = Self.compactDuration(currentEvent.endDate.timeIntervalSince(now))
            let title = settings.showEventTitlesInMenuBar ? "Busy \(duration) · \(currentEvent.title)" : "Busy \(duration)"
            return Status(
                kind: .busy,
                menuText: title,
                title: "Busy until \(DateFormatter.pulseTimeFormatter.string(from: currentEvent.endDate))",
                detail: currentEvent.title,
                color: .red,
                symbolName: "circle.fill"
            )
        }

        if let nextEvent {
            let duration = Self.compactDuration(nextEvent.startDate.timeIntervalSince(now))
            let minutesUntilNext = nextEvent.startDate.timeIntervalSince(now) / 60
            let kind: StatusKind = minutesUntilNext <= 30 ? .nextSoon : .free
            let menuPrefix = kind == .nextSoon ? "Next" : "Free"
            let detailPrefix = kind == .nextSoon ? "Starts in" : "Free for"
            let eventTitle = settings.showEventTitlesInMenuBar ? " · \(nextEvent.title)" : ""

            return Status(
                kind: kind,
                menuText: "\(menuPrefix) \(duration)\(eventTitle)",
                title: "\(detailPrefix) \(duration)",
                detail: nextEvent.title,
                color: kind == .nextSoon ? .yellow : .green,
                symbolName: kind == .nextSoon ? "clock.fill" : "checkmark.circle.fill"
            )
        }

        return Status(
            kind: .done,
            menuText: "Done today",
            title: "Done today",
            detail: "No more timed events today.",
            color: .gray,
            symbolName: "moon.fill"
        )
    }

    private func calculateFreeBlocks(now: Date) -> [FreeBlock] {
        let workday = settings.workdayInterval(on: now)
        let cursorStart = max(now, workday.start)
        guard cursorStart < workday.end else { return [] }

        var blocks: [FreeBlock] = []
        var cursor = cursorStart

        for event in timedEvents where event.endDate > cursorStart && event.startDate < workday.end {
            let eventStart = max(event.startDate, workday.start)
            let eventEnd = min(event.endDate, workday.end)

            if eventStart > cursor {
                blocks.append(FreeBlock(startDate: cursor, endDate: eventStart))
            }

            if eventEnd > cursor {
                cursor = eventEnd
            }
        }

        if cursor < workday.end {
            blocks.append(FreeBlock(startDate: cursor, endDate: workday.end))
        }

        return blocks.filter { $0.duration >= 60 }
    }

    private func clearSchedule() {
        timedEvents = []
        allDayEvents = []
        freeBlocks = []
        currentEvent = nil
        nextEvent = nil
    }
}

private extension CalendarViewModel.Status {
    static let loading = CalendarViewModel.Status(
        kind: .loading,
        menuText: "Loading",
        title: "Loading calendar",
        detail: "Checking today’s schedule…",
        color: .gray,
        symbolName: "calendar"
    )
}
