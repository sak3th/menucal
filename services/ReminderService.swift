import Foundation

/// Defines a standard interface for fetching reminders from any service.
protocol ReminderService {
    /// Fetches all incomplete reminders.
    /// - Returns: An array of `Reminder` objects.
    func fetchReminders() async throws -> [Reminder]
}
