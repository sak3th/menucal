import Foundation
import SwiftUI

// A service-agnostic representation of a calendar event.
// It's Identifiable so SwiftUI can easily work with collections of events.
struct Event: Identifiable {
  let id: String
  let uuid = UUID()
  let title: String
  let startTime: Date
  let endTime: Date
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


