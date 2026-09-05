//
//  RSVPOverrides.swift
//  MenuCal
//

import Foundation

// EventKit can't be told about an RSVP — `participantStatus` is read-only —
// and a Google-side write won't come back through CalDAV for seconds to
// minutes. So responses are held here and layered onto events as they're
// fetched, which is the one place every view goes through. Without this the
// event keeps its unaccepted striping after you've accepted it.
@Observable
@MainActor
final class RSVPOverrides {
  static let shared = RSVPOverrides()

  private struct Pending: Codable {
    let status: ParticipationStatus
    let setAt: Date
  }

  private var pending: [String: Pending] = [:] {
    didSet { persist() }
  }

  // An override is only ever recorded after Google returned 200, so the server
  // has the response and EventKit will agree eventually — whenever it gets
  // round to syncing. Dropping on agreement is the real exit; this is just a
  // backstop against entries that somehow never reconcile.
  private let ttl: TimeInterval = 24 * 60 * 60
  private static let storageKey = "rsvpOverrides"

  private init() {
    guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
          let saved = try? JSONDecoder().decode([String: Pending].self, from: data) else { return }
    // Survives relaunch: refreshSourcesIfNecessary() is only a hint and
    // .EKEventStoreChanged has no timing guarantee, so a quit inside the sync
    // window must not resurrect the pre-RSVP striping.
    pending = saved.filter { Date().timeIntervalSince($0.value.setAt) < ttl }
  }

  private func persist() {
    guard let data = try? JSONEncoder().encode(pending) else { return }
    UserDefaults.standard.set(data, forKey: Self.storageKey)
  }

  // EventKit gives every occurrence of a recurring series the same
  // eventIdentifier, so the occurrence has to be part of the key or one RSVP
  // would appear to apply to the whole series. startTime is excluded because
  // clampedToDay mutates it.
  private func key(for event: Event) -> String {
    let occurrence = event.occurrenceDate ?? event.untrimmedStart ?? event.startTime
    return "\(event.id)|\(occurrence.timeIntervalSinceReferenceDate)"
  }

  // Passing nil clears the override, which is how a failed or handed-off
  // response is rolled back to whatever was showing before.
  func set(_ status: ParticipationStatus?, for event: Event) {
    guard let status else {
      pending[key(for: event)] = nil
      return
    }
    pending[key(for: event)] = Pending(status: status, setAt: Date())
  }

  func status(for event: Event) -> ParticipationStatus? {
    guard let p = pending[key(for: event)],
          Date().timeIntervalSince(p.setAt) < ttl else { return nil }
    return p.status
  }

  // What EventKit last reported for each occurrence. The event detail holds an
  // Event captured when it was opened and never refreshed, so once an override
  // is dropped its own participationStatus is stale — falling back to it would
  // revert the control to the pre-RSVP answer. This is the live value to fall
  // back on instead. In memory only; it's a cache of the store, not a record
  // of anything the user did.
  private var lastSeen: [String: ParticipationStatus] = [:]
  // MenuCal runs for weeks; browsing months of events would otherwise grow
  // this forever. Dropping the cache only costs a fallback to the event's own
  // (possibly stale) status, so clearing wholesale is safe.
  private let lastSeenLimit = 2000

  func confirmedStatus(for event: Event) -> ParticipationStatus? {
    lastSeen[key(for: event)]
  }

  // Layers pending responses onto freshly fetched events, and drops any the
  // server has caught up with — the reconciliation step. Called on every
  // fetch, so an override lives exactly as long as it's still telling the
  // user something EventKit hasn't learned yet.
  func apply(to events: [Event]) -> [Event] {
    if lastSeen.count > lastSeenLimit { lastSeen.removeAll() }
    return events.map { event in
      let k = key(for: event)
      lastSeen[k] = event.participationStatus
      guard let p = pending[k] else { return event }
      guard event.participationStatus != p.status,
            Date().timeIntervalSince(p.setAt) < ttl else {
        pending[k] = nil
        return event
      }
      var overridden = event
      overridden.participationStatus = p.status
      return overridden
    }
  }

  func clear() {
    pending.removeAll()
    UserDefaults.standard.removeObject(forKey: Self.storageKey)
  }
}
