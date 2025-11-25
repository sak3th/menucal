import Foundation

// A service-agnostic representation of a reminder or task.
struct Reminder: Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date? // A reminder may not have a due date.
}
