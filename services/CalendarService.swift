import Foundation
import SwiftUI

// Whether an RSVP was actually recorded, or merely handed off to another app
// for the user to finish. The UI can only show an optimistic status for the
// former.
enum RespondOutcome {
    case written
    case handedOff
}

struct CalendarInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let color: Color
    let sourceTitle: String
    /// Whether this calendar lives on a Google account — the only kind whose
    /// RSVPs MenuCal can write directly.
    let isGoogle: Bool
}

/// A Google account as EventKit knows it. Sign-in is offered per account
/// rather than once, because each one needs its own OAuth grant before its
/// invites can be answered in place.
struct CalendarAccount: Identifiable, Hashable {
    /// The EventKit source identifier — stable, and the only handle that
    /// survives the account being renamed in Internet Accounts.
    let id: String
    /// Whatever the account is called in Internet Accounts. User-chosen, so
    /// it can be anything ("Work", "Spry"); only shown when no email is known.
    let title: String
    /// The account address, read off the primary calendar. Nil when every
    /// calendar has been renamed, in which case the account can still be
    /// connected — Google just has to be asked which one it is.
    let email: String?
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

    /// Fetches the Google accounts configured on this Mac.
    func fetchGoogleAccounts() async throws -> [CalendarAccount]
    
    /// Refreshes the underlying data sources (e.g. syncs with servers).
    func refreshData()

    /// Responds to an event invitation.
    /// - Returns: `.written` if the response actually reached the server,
    ///   `.handedOff` if the user was sent elsewhere to complete it.
    @discardableResult
    func respondToEvent(event: Event, status: ParticipationStatus) async throws -> RespondOutcome
}
