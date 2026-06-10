import Foundation

struct FreeBlock: Identifiable, Equatable {
    let id = UUID()
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    var timeRangeText: String {
        let formatter = DateFormatter.pulseTimeFormatter
        return "\(formatter.string(from: startDate))–\(formatter.string(from: endDate))"
    }
}
