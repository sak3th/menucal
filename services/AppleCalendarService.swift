import EventKit
import Foundation
import SwiftUI

// Concrete implementation of the CalendarService protocol for Apple's EventKit.
class AppleCalendarService: CalendarService {
  private let eventStore = EKEventStore()

  /// Requests access to the user's calendars.
  /// Throws an error if access is denied or restricted.
  private func requestAccess() async throws {
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
      break
    @unknown default:
      throw CalendarAccessError.unknown
    }
  }

  func fetchEvents(for date: Date) async throws -> [Event] {
    try await requestAccess()

    let calendars = eventStore.calendars(for: .event)
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
        calendarSource: ekEvent.calendar.source.title
      )
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
    case .delegated, .completed, .inProcess:
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
      case .delegated, .completed, .inProcess:
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
