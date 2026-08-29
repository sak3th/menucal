import Foundation
import SwiftUI

// A service-agnostic representation of a calendar event.
// It's Identifiable so SwiftUI can easily work with collections of events.
struct Event: Identifiable {
  let id: String
  let title: String
  // var so an event can be clamped to a single day for per-day layout; see
  // `clampedToDay(from:to:)`.
  var startTime: Date
  var endTime: Date
  let isAllDay: Bool
  let calendarColor: Color

  // Extended properties
  let location: String?
  let notes: String?
  let url: URL?

  // Recurrence
  let isRecurring: Bool
  let recurrenceRule: RecurrenceRule?

  // Organizer and attendees
  let organizer: Participant?
  let attendees: [Participant]

  // Participation status
  let participationStatus: ParticipationStatus

  // Calendar metadata
  let calendarTitle: String
  let calendarSource: String

  // Service-level identifier (iCalUID for synced events)
  var externalIdentifier: String? = nil
  // Whether the event's calendar lives on a Google account, regardless of
  // where the event itself was created (foreign-UID invites)
  var isOnGoogleAccount: Bool = false
  // Original start of this occurrence within a recurring series, and whether
  // it was detached from the series (modified single occurrence)
  var occurrenceDate: Date? = nil
  var isDetached: Bool = false
  // Real start of an event trimmed to a single day; nil when untrimmed.
  var untrimmedStart: Date? = nil

  // The part of this event that falls inside [from, to]. A day view lays out
  // its own slice of an event spanning midnight — the same event on the
  // neighbouring day lays out the other slice — so overlap, containment and
  // position are all about what's actually on that day's grid.
  func clampedToDay(from: Date, to: Date) -> Event {
    var clamped = self
    clamped.startTime = min(max(startTime, from), to)
    clamped.endTime = min(max(endTime, from), to)
    // Trimming makes every continuation look like it starts at midnight, which
    // would lose the fact that one began earlier than another. Keep the real
    // start so ordering can still tell them apart.
    if clamped.startTime != startTime {
      clamped.untrimmedStart = startTime
    }
    return clamped
  }

  // Video conference link (Zoom, Meet, Teams, etc.)
  var videoCallLink: URL? {
    // Try to extract from URL first
    if let url = url, isVideoConferenceURL(url) {
      return url
    }

    // Try to extract from notes
    if let notes = notes {
      return extractVideoCallLink(from: notes)
    }

    return nil
  }

  // Helper to check if URL is a video conference link
  private func isVideoConferenceURL(_ url: URL) -> Bool {
    let host = url.host?.lowercased() ?? ""
    return host.contains("zoom.us") || host.contains("meet.google.com")
      || host.contains("teams.microsoft.com") || host.contains("webex.com")
      || host.contains("gotomeeting.com") || host.contains("bluejeans.com")
      || host.contains("whereby.com") || host.contains("skype.com")
  }

  // Helper to extract video call links from notes
  private func extractVideoCallLink(from text: String) -> URL? {
    let patterns = [
      "https://[\\w.-]*zoom\\.us/[^\\s]+",
      "https://meet\\.google\\.com/[^\\s]+",
      "https://teams\\.microsoft\\.com/[^\\s]+",
      "https://[\\w.-]*webex\\.com/[^\\s]+",
      "https://[\\w.-]*gotomeeting\\.com/[^\\s]+",
      "https://[\\w.-]*bluejeans\\.com/[^\\s]+",
      "https://whereby\\.com/[^\\s]+",
    ]

    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern, options: []),
        let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
        let range = Range(match.range, in: text)
      {
        let urlString = String(text[range])
        return URL(string: urlString)
      }
    }

    return nil
  }

  // Helper to determine the meeting provider name
  var meetingProvider: String {
    guard let url = videoCallLink, let host = url.host?.lowercased() else { return "Video Call" }

    if host.contains("zoom.us") { return "Zoom" }
    if host.contains("meet.google.com") || host.contains("google.com") { return "Google Meet" }
    if host.contains("teams.microsoft.com") { return "Microsoft Teams" }
    if host.contains("webex.com") { return "Webex" }
    if host.contains("gotomeeting.com") { return "GoToMeeting" }
    if host.contains("bluejeans.com") { return "BlueJeans" }
    if host.contains("whereby.com") { return "Whereby" }
    if host.contains("skype.com") { return "Skype" }

    return host
  }
  
  var isUnaccepted: Bool {
    return participationStatus == .pending || participationStatus == .tentative
  }

  // MARK: - Google Calendar

  private static let googleUIDSuffix = "@google.com"

  // EventKit appends "/RID=<timestamp>" to the iCalUID of detached
  // occurrences — strip it to get the series UID.
  private var normalizedUID: String? {
    guard let uid = externalIdentifier else { return nil }
    if let ridRange = uid.range(of: "/RID=") {
      return String(uid[..<ridRange.lowerBound])
    }
    return uid
  }

  // The RID is the occurrence's original start as seconds since the Apple
  // reference date — authoritative for rescheduled occurrences.
  private var ridDate: Date? {
    guard let uid = externalIdentifier,
          let ridRange = uid.range(of: "/RID="),
          let interval = TimeInterval(uid[ridRange.upperBound...]) else { return nil }
    return Date(timeIntervalSinceReferenceDate: interval)
  }

  var isGoogleEvent: Bool {
    normalizedUID?.hasSuffix(Self.googleUIDSuffix) == true
  }

  var currentUserEmail: String? {
    if let email = attendees.first(where: { $0.isCurrentUser })?.email {
      return email
    }
    // Group invites may not list the user individually. Google primary
    // calendars are titled with the account email; CalDAV source titles
    // sometimes are too.
    if calendarTitle.contains("@") { return calendarTitle }
    if calendarSource.contains("@") { return calendarSource }
    return nil
  }

  // Google's event id for deep links: the iCalUID prefix, plus — for
  // occurrences of a recurring series (including detached ones) — the
  // instance suffix Google derives from the occurrence's original start in
  // UTC. Split series carry an "_R<timestamp>" segment in the series id that
  // instance ids drop.
  var googleEventId: String? {
    guard isGoogleEvent, let uid = normalizedUID else { return nil }
    var base = String(uid.dropLast(Self.googleUIDSuffix.count))
    guard isRecurring || isDetached else { return base }

    if let rRange = base.range(of: "_R[0-9]{8}T[0-9]{6}$", options: .regularExpression) {
      base.removeSubrange(rRange)
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = isAllDay ? "yyyyMMdd" : "yyyyMMdd'T'HHmmss'Z'"
    return "\(base)_\(formatter.string(from: ridDate ?? occurrenceDate ?? startTime))"
  }
}

// Represents a participant (organizer or attendee)
struct Participant: Identifiable {
  let id: String
  let name: String?
  let email: String?
  let isCurrentUser: Bool
  let participationStatus: ParticipationStatus

  var displayName: String {
    if let name = name, !name.isEmpty {
      return name
    }
    return email ?? "Unknown"
  }
}

// Participation status for the current user
enum ParticipationStatus: String, CaseIterable {
  case unknown = "Unknown"
  case pending = "Pending"
  case accepted = "Accepted"
  case declined = "Declined"
  case tentative = "Tentative"

  var icon: String {
    switch self {
    case .accepted: return "checkmark.circle"
    case .declined: return "xmark.circle"
    case .tentative: return "questionmark.circle"
    case .pending: return "questionmark.circle"
    case .unknown: return "questionmark.circle"
    }
  }

  var color: Color {
    switch self {
    case .accepted: return .green
    case .declined: return .red
    case .tentative: return .orange
    case .pending: return .gray
    case .unknown: return .gray
    }
  }
}

// Recurrence rule information
struct RecurrenceRule {
  let frequency: RecurrenceFrequency
  let interval: Int  // e.g., every 2 weeks
  let endDate: Date?
  let occurrenceCount: Int?  // e.g., repeat 10 times

  var description: String {
    var parts: [String] = []

    // Frequency
    if interval == 1 {
      parts.append("Repeats \(frequency.rawValue.lowercased())")
    } else {
      parts.append("Repeats \(interval) \(frequency.plural.lowercased())")
    }

    // End condition
    if let count = occurrenceCount {
      parts.append("(\(count) times)")
    } else if let end = endDate {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      parts.append("until \(formatter.string(from: end))")
    }

    return parts.joined(separator: " ")
  }
}

enum RecurrenceFrequency: String, CaseIterable {
  case daily = "Daily"
  case weekly = "Weekly"
  case monthly = "Monthly"
  case yearly = "Yearly"

  var plural: String {
    switch self {
    case .daily: return "days"
    case .weekly: return "weeks"
    case .monthly: return "months"
    case .yearly: return "years"
    }
  }
}


