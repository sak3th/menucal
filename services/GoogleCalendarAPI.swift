//
//  GoogleCalendarAPI.swift
//  MenuCal
//

import Foundation

// The one thing EventKit can't do: set your own participation status.
// `EKParticipant.participantStatus` and `EKCalendarItem.attendees` are both
// read-only, so for events on a Google account we write the RSVP through
// Google's API instead.
enum GoogleCalendarAPI {
  private static let base = "https://www.googleapis.com/calendar/v3"

  static func setResponseStatus(for event: Event, to status: ParticipationStatus) async throws {
    guard let response = status.googleResponseStatus else {
      throw GoogleCalendarError.unsupportedStatus(status)
    }
    // The event lives on the user's own copy of the calendar, which Google
    // addresses by their account email.
    guard let calendarID = event.currentUserEmail else {
      throw GoogleCalendarError.noCalendarID
    }

    let token = try await GoogleAuth.shared.validAccessToken(for: calendarID)
    let eventID = try await resolveEventID(for: event, calendarID: calendarID, token: token)
    let path = "/calendars/\(esc(calendarID))/events/\(esc(eventID))"

    let remote = try await send("GET", path, token: token)
    guard var attendees = remote["attendees"] as? [[String: Any]] else {
      throw GoogleCalendarError.notAnInvite
    }

    var matched = false
    for i in attendees.indices where attendees[i]["self"] as? Bool == true {
      attendees[i]["responseStatus"] = response
      matched = true
    }
    guard matched else { throw GoogleCalendarError.notAnAttendee }

    // Arrays overwrite wholesale in Google's patch semantics, so the entire
    // attendee list goes back — sending only our own entry would delete
    // everyone else from the event.
    _ = try await send("PATCH", path, token: token,
                       query: [URLQueryItem(name: "sendUpdates", value: "all")],
                       body: ["attendees": attendees])
  }

  // MARK: - Event id

  private static func resolveEventID(for event: Event, calendarID: String, token: String) async throws -> String {
    if let id = event.googleEventId { return id }

    // Invites created outside Google carry a foreign iCalUID, so the id can't
    // be derived — ask Google which event that UID maps to. This is the case
    // that previously fell through to the day-view deep link.
    guard let uid = event.normalizedUID else { throw GoogleCalendarError.noEventID }
    let window: TimeInterval = 24 * 60 * 60
    let anchor = event.occurrenceDate ?? event.startTime
    let items = try await send("GET", "/calendars/\(esc(calendarID))/events", token: token, query: [
      URLQueryItem(name: "iCalUID", value: uid),
      URLQueryItem(name: "singleEvents", value: "true"),
      URLQueryItem(name: "timeMin", value: iso(anchor.addingTimeInterval(-window))),
      URLQueryItem(name: "timeMax", value: iso(anchor.addingTimeInterval(window))),
    ])
    guard let first = (items["items"] as? [[String: Any]])?.first,
          let id = first["id"] as? String else {
      throw GoogleCalendarError.noEventID
    }
    return id
  }

  // MARK: - Transport

  private static func send(
    _ method: String,
    _ path: String,
    token: String,
    query: [URLQueryItem] = [],
    body: [String: Any]? = nil
  ) async throws -> [String: Any] {
    var comps = URLComponents(string: base + path)!
    if !query.isEmpty { comps.queryItems = query }
    var request = URLRequest(url: comps.url!)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    let (data, response) = try await URLSession.shared.data(for: request)
    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
      let message = ((json["error"] as? [String: Any])?["message"] as? String)
        ?? "HTTP \(http.statusCode)"
      throw GoogleCalendarError.server(status: http.statusCode, message: message)
    }
    return json
  }

  private static func esc(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
  }

  private static func iso(_ date: Date) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.string(from: date)
  }
}

extension ParticipationStatus {
  // Google only accepts these three from an attendee; `pending` maps to
  // needsAction, which is a state you leave rather than one you set.
  var googleResponseStatus: String? {
    switch self {
    case .accepted: return "accepted"
    case .declined: return "declined"
    case .tentative: return "tentative"
    case .pending, .unknown: return nil
    }
  }
}

enum GoogleCalendarError: LocalizedError {
  case noCalendarID
  case noEventID
  case notAnInvite
  case notAnAttendee
  case unsupportedStatus(ParticipationStatus)
  case server(status: Int, message: String)

  var errorDescription: String? {
    switch self {
    case .noCalendarID: return "Couldn't tell which Google account this event belongs to."
    case .noEventID: return "Couldn't find this event in Google Calendar."
    case .notAnInvite: return "This event has no attendees."
    case .notAnAttendee: return "You're not listed as an attendee."
    case .unsupportedStatus(let s): return "Can't set status \(s.rawValue)."
    case .server(let status, let message): return "Google returned \(status): \(message)"
    }
  }
}
