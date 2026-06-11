import EventKit
import Foundation
import SwiftUI

// Concrete implementation of the CalendarService protocol for Apple's EventKit.
class AppleCalendarService: CalendarService {
  // Use a shared instance to avoid creating multiple EKEventStore objects
  private static let sharedEventStore = EKEventStore()
  
  private var eventStore: EKEventStore {
    return Self.sharedEventStore
  }
  
  /// Requests access to the user's calendars.
  /// Throws an error if access is denied or restricted.
  private func requestAccess() async throws {
    // Prefer modern authorization APIs on newer OS versions, fall back otherwise
    if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
      // Check current status first
      let status = EKEventStore.authorizationStatus(for: .event)
      switch status {
      case .authorized:
        return
      case .fullAccess:
        return
      case .writeOnly:
        return
      case .restricted:
        throw CalendarAccessError.restricted
      case .denied:
        throw CalendarAccessError.denied
      case .notDetermined:
        // Request full access to events
        let granted: Bool = try await withCheckedThrowingContinuation { continuation in
          eventStore.requestFullAccessToEvents { granted, error in
            if let error = error {
              continuation.resume(throwing: error)
            } else {
              continuation.resume(returning: granted)
            }
          }
        }
        if !granted {
          throw CalendarAccessError.denied
        }
      
      @unknown default:
        throw CalendarAccessError.unknown
      }
    } else {
      // Legacy path for older OS versions
      let status = EKEventStore.authorizationStatus(for: .event)
      switch status {
      case .notDetermined:
        let granted = try await eventStore.requestAccess(to: .event)
        if !granted {
          throw CalendarAccessError.denied
        }
      case .restricted:
        throw CalendarAccessError.restricted
      case .denied:
        throw CalendarAccessError.denied
      case .authorized:
        return
      case .fullAccess:
        return
      case .writeOnly:
        return
      @unknown default:
        throw CalendarAccessError.unknown
      }
    }
  }
  
  func fetchEvents(for date: Date, hiddenCalendarIDs: Set<String> = []) async throws -> [Event] {
    try await requestAccess()
    
    let allCalendars = eventStore.calendars(for: .event)
    let calendars = allCalendars.filter { !hiddenCalendarIDs.contains($0.calendarIdentifier) }
    
    let startOfDay = Calendar.current.startOfDay(for: date)
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let predicate = eventStore.predicateForEvents(
      withStart: startOfDay, end: endOfDay, calendars: calendars)
    let ekEvents = eventStore.events(matching: predicate)
    
    return ekEvents.map { ekEvent in
      Event(
        id: ekEvent.eventIdentifier,
        title: ekEvent.title,
        startTime: ekEvent.startDate,
        endTime: ekEvent.endDate,
        isAllDay: ekEvent.isAllDay,
        calendarColor: Color(ekEvent.calendar.cgColor),
        location: ekEvent.location,
        notes: ekEvent.notes,
        url: ekEvent.url,
        isRecurring: ekEvent.hasRecurrenceRules,
        recurrenceRule: extractRecurrenceRule(from: ekEvent),
        organizer: extractParticipant(from: ekEvent.organizer),
        attendees: ekEvent.attendees?.compactMap { extractParticipant(from: $0) } ?? [],
        participationStatus: extractParticipationStatus(from: ekEvent),
        calendarTitle: ekEvent.calendar.title,
        calendarSource: ekEvent.calendar.source.title,
        externalIdentifier: ekEvent.calendarItemExternalIdentifier,
        occurrenceDate: ekEvent.occurrenceDate,
        isDetached: ekEvent.isDetached
      )
    }
  }

  func fetchEvents(from startDate: Date, to endDate: Date, hiddenCalendarIDs: Set<String> = []) async throws -> [Event] {
    try await requestAccess()
    
    let allCalendars = eventStore.calendars(for: .event)
    let calendars = allCalendars.filter { !hiddenCalendarIDs.contains($0.calendarIdentifier) }
    
    let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
    let ekEvents = eventStore.events(matching: predicate)
    
    return ekEvents.map { ekEvent in
      Event(
        id: ekEvent.eventIdentifier,
        title: ekEvent.title,
        startTime: ekEvent.startDate,
        endTime: ekEvent.endDate,
        isAllDay: ekEvent.isAllDay,
        calendarColor: Color(ekEvent.calendar.cgColor),
        location: ekEvent.location,
        notes: ekEvent.notes,
        url: ekEvent.url,
        isRecurring: ekEvent.hasRecurrenceRules,
        recurrenceRule: extractRecurrenceRule(from: ekEvent),
        organizer: extractParticipant(from: ekEvent.organizer),
        attendees: ekEvent.attendees?.compactMap { extractParticipant(from: $0) } ?? [],
        participationStatus: extractParticipationStatus(from: ekEvent),
        calendarTitle: ekEvent.calendar.title,
        calendarSource: ekEvent.calendar.source.title,
        externalIdentifier: ekEvent.calendarItemExternalIdentifier,
        occurrenceDate: ekEvent.occurrenceDate,
        isDetached: ekEvent.isDetached
      )
    }
  }

  func fetchCalendars() async throws -> [CalendarInfo] {
    try await requestAccess()
    let calendars = eventStore.calendars(for: .event)
    return calendars.map { ekCalendar in
      CalendarInfo(
        id: ekCalendar.calendarIdentifier,
        title: ekCalendar.title,
        color: Color(ekCalendar.cgColor),
        sourceTitle: ekCalendar.source.title
      )
    }
  }
  
  func refreshData() {
    eventStore.refreshSourcesIfNecessary()
  }
  
  func respondToEvent(event: Event, status: ParticipationStatus) async throws {
    // NOTE: Public EventKit API does not allow changing participant status directly for the current user
    // on received invitations in a straightforward way (properties are read-only).
    // We hand off: Google events deep-link into Google Calendar (local web app
    // if installed), everything else opens in Calendar.app.
    if event.isGoogleEvent, let url = GoogleCalendarDeepLink.eventURL(for: event) {
      NSLog("RSVP deeplink title=%@ uid=%@ recurring=%d detached=%d url=%@",
            event.title, event.externalIdentifier ?? "nil", event.isRecurring ? 1 : 0,
            event.isDetached ? 1 : 0, url.absoluteString)
      GoogleCalendarDeepLink.open(url)
      return
    }

    // Open the specific event in Calendar.app using ical:// URL scheme
    // Format: ical://ekevent/<eventIdentifier>?method=show&options=more
    if let encodedId = event.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
       let url = URL(string: "ical://ekevent/\(encodedId)?method=show&options=more") {
      NSWorkspace.shared.open(url)
    }
  }

  // MARK: - Helper Methods
  
  private func extractRecurrenceRule(from ekEvent: EKEvent) -> RecurrenceRule? {
    guard let recurrenceRule = ekEvent.recurrenceRules?.first else {
      return nil
    }
    
    let frequency: RecurrenceFrequency
    switch recurrenceRule.frequency {
    case .daily:
      frequency = .daily
    case .weekly:
      frequency = .weekly
    case .monthly:
      frequency = .monthly
    case .yearly:
      frequency = .yearly
    @unknown default:
      frequency = .daily
    }
    
    return RecurrenceRule(
      frequency: frequency,
      interval: recurrenceRule.interval,
      endDate: recurrenceRule.recurrenceEnd?.endDate,
      occurrenceCount: recurrenceRule.recurrenceEnd?.occurrenceCount
    )
  }
  
  private func extractParticipant(from ekParticipant: EKParticipant?) -> Participant? {
    guard let ekParticipant = ekParticipant else {
      return nil
    }
    
    // Use URL string as ID since EKParticipant doesn't have a stable identifier
    let id = ekParticipant.url.absoluteString
    let email = extractEmail(from: ekParticipant.url)
    
    // Extract participation status
    let status: ParticipationStatus
    switch ekParticipant.participantStatus {
    case .pending:
      status = .pending
    case .accepted:
      status = .accepted
    case .declined:
      status = .declined
    case .tentative:
      status = .tentative
    case .delegated:
      status = .unknown
    case .completed:
      status = .unknown
    case .inProcess:
      status = .unknown
    case .unknown:
      status = .unknown
    @unknown default:
      status = .unknown
    }
    
    return Participant(
      id: id,
      name: ekParticipant.name,
      email: email,
      isCurrentUser: ekParticipant.isCurrentUser,
      participationStatus: status
    )
  }
  
  private func extractEmail(from url: URL) -> String? {
    // EKParticipant URLs are in the format "mailto:email@example.com"
    let urlString = url.absoluteString
    if urlString.hasPrefix("mailto:") {
      return String(urlString.dropFirst(7))
    }
    
    return nil
  }
  
  private func extractParticipationStatus(from ekEvent: EKEvent) -> ParticipationStatus {
    // Find the current user's attendee status
    if let currentUserAttendee = ekEvent.attendees?.first(where: { $0.isCurrentUser }) {
      switch currentUserAttendee.participantStatus {
      case .pending:
        return .pending
      case .accepted:
        return .accepted
      case .declined:
        return .declined
      case .tentative:
        return .tentative
      case .delegated:
        return .unknown
      case .completed:
        return .unknown
      case .inProcess:
        return .unknown
      case .unknown:
        return .unknown
      @unknown default:
        return .unknown
      }
    }

    // If there are no attendees or the user is the organizer, assume accepted
    return .accepted
  }


}

// Custom error for handling calendar access issues.
enum CalendarAccessError: Error {
  case denied
  case restricted
  case unknown
}

