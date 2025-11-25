import Foundation

/// Defines a standard interface for fetching calendar events from any service (Apple, Google, etc.).
protocol CalendarService {
    /// Fetches events for a specific day.
    /// - Parameter date: The day for which to fetch events.
    /// - Returns: An array of `Event` objects.
    func fetchEvents(for date: Date) async throws -> [Event]
}
