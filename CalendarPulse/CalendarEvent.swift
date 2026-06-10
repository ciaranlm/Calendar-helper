import Foundation
import SwiftUI

struct CalendarEvent: Identifiable {
    let id: String
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let calendarTitle: String
    let calendarColor: Color
    let isAllDay: Bool
    let url: URL?
    let videoCallURL: URL?

    var timeRangeText: String {
        let formatter = DateFormatter.pulseTimeFormatter
        return "\(formatter.string(from: startDate))–\(formatter.string(from: endDate))"
    }
}

extension DateFormatter {
    static let pulseTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
