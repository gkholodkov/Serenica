import Foundation

enum RecurrenceType: Int, Codable {
    case none = 0
    case daily = 1
    case workingDays = 2
    case weekly = 3
    case monthly = 4
    case yearly = 5
}

struct Event: Identifiable, Equatable {
    var id: UUID
    var title: String
    var startDate: Date?
    var endDate: Date?
    var notes: String
    var userId: UUID
    var isCompleted: Bool
    var notificationId: UUID?
    var notificationInterval: Double?
    var isOverdue: Bool
    var recurrenceType: RecurrenceType
    var recurrenceInterval: Int       // For daily/workingDays this is typically 1.
    var recurrenceEndDate: Date?       // Optional end date for the recurrence
    var recurrenceExcludedDates: [Date]?
    
    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String = "",
        userId: UUID,
        isCompleted: Bool = false,
        notificationId: UUID? = nil,
        notificationInterval: Double? = nil,
        isOverdue: Bool = false,
        recurrenceType: RecurrenceType = .none,
        recurrenceInterval: Int = 1,
        recurrenceEndDate: Date? = nil,
        recurrenceExcludedDates: [Date]? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.userId = userId
        self.isCompleted = isCompleted
        self.notificationId = notificationId
        self.notificationInterval = notificationInterval
        self.isOverdue = isOverdue
        self.recurrenceType = recurrenceType
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceExcludedDates = recurrenceExcludedDates
    }
}
