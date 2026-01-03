import Foundation
import SwiftUI

struct CalendarInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let color: Color
    let sourceTitle: String
}

/// Defines a standard interface for fetching calendar events from any service (Apple, Google, etc.).
protocol CalendarService {
    /// Fetches events for a specific day.
    /// - Parameter date: The day for which to fetch events.
    /// - Parameter hiddenCalendarIDs: IDs of calendars to exclude.
    /// - Returns: An array of `Event` objects.
    func fetchEvents(for date: Date, hiddenCalendarIDs: Set<String>) async throws -> [Event]
    
    /// Fetches events for a date range.
    func fetchEvents(from startDate: Date, to endDate: Date, hiddenCalendarIDs: Set<String>) async throws -> [Event]
    
    /// Fetches all available calendars.
    /// - Returns: An array of `CalendarInfo` objects.
    func fetchCalendars() async throws -> [CalendarInfo]
    
    /// Refreshes the underlying data sources (e.g. syncs with servers).
    func refreshData()

    /// Responds to an event invitation.
    func respondToEvent(id: String, status: ParticipationStatus) async throws
}
