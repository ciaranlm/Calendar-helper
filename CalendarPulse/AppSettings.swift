import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var workdayStartMinutes: Int {
        didSet { defaults.set(workdayStartMinutes, forKey: Keys.workdayStartMinutes) }
    }

    @Published var workdayEndMinutes: Int {
        didSet { defaults.set(workdayEndMinutes, forKey: Keys.workdayEndMinutes) }
    }

    @Published var includeAllDayEventsInList: Bool {
        didSet { defaults.set(includeAllDayEventsInList, forKey: Keys.includeAllDayEventsInList) }
    }

    @Published var showEventTitlesInMenuBar: Bool {
        didSet { defaults.set(showEventTitlesInMenuBar, forKey: Keys.showEventTitlesInMenuBar) }
    }

    @Published var refreshIntervalSeconds: Int {
        didSet { defaults.set(refreshIntervalSeconds, forKey: Keys.refreshIntervalSeconds) }
    }

    @Published var meetingNudgesEnabled: Bool {
        didSet { defaults.set(meetingNudgesEnabled, forKey: Keys.meetingNudgesEnabled) }
    }

    @Published var nudgeTimeMinutes: Int {
        didSet { defaults.set(nudgeTimeMinutes, forKey: Keys.nudgeTimeMinutes) }
    }

    @Published var playNudgeSound: Bool {
        didSet { defaults.set(playNudgeSound, forKey: Keys.playNudgeSound) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let workdayStartMinutes = "workdayStartMinutes"
        static let workdayEndMinutes = "workdayEndMinutes"
        static let includeAllDayEventsInList = "includeAllDayEventsInList"
        static let showEventTitlesInMenuBar = "showEventTitlesInMenuBar"
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
        static let meetingNudgesEnabled = "meetingNudgesEnabled"
        static let nudgeTimeMinutes = "nudgeTimeMinutes"
        static let playNudgeSound = "playNudgeSound"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.workdayStartMinutes = defaults.object(forKey: Keys.workdayStartMinutes) as? Int ?? 9 * 60
        self.workdayEndMinutes = defaults.object(forKey: Keys.workdayEndMinutes) as? Int ?? (17 * 60) + 30
        self.includeAllDayEventsInList = defaults.object(forKey: Keys.includeAllDayEventsInList) as? Bool ?? true
        self.showEventTitlesInMenuBar = defaults.object(forKey: Keys.showEventTitlesInMenuBar) as? Bool ?? false
        self.refreshIntervalSeconds = defaults.object(forKey: Keys.refreshIntervalSeconds) as? Int ?? 60
        self.meetingNudgesEnabled = defaults.object(forKey: Keys.meetingNudgesEnabled) as? Bool ?? true
        self.nudgeTimeMinutes = defaults.object(forKey: Keys.nudgeTimeMinutes) as? Int ?? 1
        self.playNudgeSound = defaults.object(forKey: Keys.playNudgeSound) as? Bool ?? false
    }

    var workdayStartDate: Date {
        get { dateForMinutes(workdayStartMinutes) }
        set { workdayStartMinutes = minutesSinceMidnight(from: newValue) }
    }

    var workdayEndDate: Date {
        get { dateForMinutes(workdayEndMinutes) }
        set { workdayEndMinutes = minutesSinceMidnight(from: newValue) }
    }

    func workdayInterval(on date: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let startOfDay = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .minute, value: workdayStartMinutes, to: startOfDay) ?? startOfDay
        let end = calendar.date(byAdding: .minute, value: workdayEndMinutes, to: startOfDay) ?? start
        return DateInterval(start: min(start, end), end: max(start, end))
    }

    private func dateForMinutes(_ minutes: Int) -> Date {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .minute, value: minutes, to: startOfDay) ?? startOfDay
    }

    private func minutesSinceMidnight(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case thirtySeconds = 30
    case sixtySeconds = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .thirtySeconds:
            return "30 seconds"
        case .sixtySeconds:
            return "60 seconds"
        case .fiveMinutes:
            return "5 minutes"
        }
    }
}


enum NudgeTime: Int, CaseIterable, Identifiable {
    case oneMinute = 1
    case twoMinutes = 2
    case fiveMinutes = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .oneMinute:
            return "1 minute before"
        case .twoMinutes:
            return "2 minutes before"
        case .fiveMinutes:
            return "5 minutes before"
        }
    }
}
