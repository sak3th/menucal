//
//  EventsViewModel.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import Foundation
import SwiftUI
import EventKit

@Observable
class EventsViewModel {
  var hiddenCalendarIDs: Set<String> = [] {
    didSet {
      UserDefaults.standard.set(Array(hiddenCalendarIDs), forKey: "hiddenCalendarIDs")
    }
  }

  var calendars: [CalendarInfo] = []
  /// The Google accounts EventKit knows about — sign-in is offered per
  /// account, so this is what the setup window and Settings list.
  var googleAccounts: [CalendarAccount] = []
  /// Whether the lists above have actually been read once. An empty
  /// `googleAccounts` otherwise can't be told apart from "haven't looked yet",
  /// and setup would act on the difference.
  private(set) var hasFetchedCalendars = false
  var isRefreshing: Bool = false
  // Bumped whenever underlying data may have changed; day views re-fetch on it.
  var refreshTick: Int = 0

  private let calendarService: CalendarService = AppleCalendarService()
  private var storeChangedObserver: NSObjectProtocol?
  private var refreshTimeoutTask: Task<Void, Never>?
  private var refreshStartedAt: Date?
  // Store-changed notifications within this window of a refresh are treated as
  // the initial local store load, not a completed network sync, so they
  // re-fetch but don't stop the spinner.
  private let refreshGrace: TimeInterval = 2

  init() {
    if let saved = UserDefaults.standard.array(forKey: "hiddenCalendarIDs") as? [String] {
      hiddenCalendarIDs = Set(saved)
    }

    // EventKit syncs sources asynchronously; when fresh data actually lands
    // (or an external edit occurs) it posts .EKEventStoreChanged. Re-fetch
    // then, rather than guessing with a fixed delay after refreshSources.
    storeChangedObserver = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        self.refreshTick &+= 1
        await self.fetchCalendars()
        // Stop the spinner only once we're past the grace window (a real
        // server sync); ignore the early store-load notification.
        if let started = self.refreshStartedAt,
           Date().timeIntervalSince(started) >= self.refreshGrace {
          self.stopRefreshing()
        }
      }
    }
  }

  deinit {
    if let storeChangedObserver {
      NotificationCenter.default.removeObserver(storeChangedObserver)
    }
  }

  @MainActor
  func refreshAll() async {
    // Already syncing — skip redundant refreshes (e.g. repeated window-key
    // events) until the current one resolves.
    guard !isRefreshing else { return }
    isRefreshing = true
    refreshStartedAt = Date()
    calendarService.refreshData()
    await fetchCalendars()
    refreshTick &+= 1

    // Keep the spinner up until fresh data actually lands
    // (.EKEventStoreChanged stops it), capped at 60s so it can't spin forever.
    refreshTimeoutTask?.cancel()
    refreshTimeoutTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(60))
      guard !Task.isCancelled else { return }
      self?.stopRefreshing()
    }
  }

  @MainActor
  private func stopRefreshing() {
    refreshTimeoutTask?.cancel()
    refreshTimeoutTask = nil
    refreshStartedAt = nil
    isRefreshing = false
  }
  
  func fetchCalendars() async {
    do {
      let fetched = try await calendarService.fetchCalendars()
      calendars = fetched
      googleAccounts = try await calendarService.fetchGoogleAccounts()
      hasFetchedCalendars = true
    } catch {
      print("Error fetching calendars: \(error)")
    }
  }

  /// Gates the Google setup step. Someone whose calendars are all iCloud has
  /// nothing to connect, and someone who has connected every account is done.
  @MainActor
  var hasUnconnectedGoogleAccounts: Bool {
    googleAccounts.contains { !GoogleAuth.shared.isConnected($0.email) }
  }

  func toggleCalendarVisibility(id: String) {
    if hiddenCalendarIDs.contains(id) {
      hiddenCalendarIDs.remove(id)
    } else {
      hiddenCalendarIDs.insert(id)
    }
  }

  /// Pending response first, then whatever EventKit last reported for that
  /// occurrence. The event's own value comes last: the detail view holds a
  /// snapshot taken when it was opened, so it goes stale as soon as anything
  /// changes underneath it.
  func displayStatus(for event: Event) -> ParticipationStatus {
    RSVPOverrides.shared.status(for: event)
      ?? RSVPOverrides.shared.confirmedStatus(for: event)
      ?? event.participationStatus
  }

  /// Records the response and redraws immediately; the write to Google runs
  /// behind it. Nothing in the UI waits on the network, so there's no in-flight
  /// state to show — the response either stands or is quietly rolled back.
  @MainActor
  func respondToEvent(event: Event, status: ParticipationStatus) {
    let previous = RSVPOverrides.shared.status(for: event)
    // Only show the answer straight away when we're actually going to write
    // it. Everything else hands off to another app, where the user still has
    // to respond — claiming it here would flash the new status and revert it a
    // moment later, on every RSVP, for anyone without Google connected.
    let willWrite = event.isOnGoogleAccount && GoogleAuth.shared.canRespond(as: event.currentUserEmail)
    if willWrite {
      RSVPOverrides.shared.set(status, for: event)
      refreshTick &+= 1
    }

    Task { @MainActor in
      do {
        let outcome = try await calendarService.respondToEvent(event: event, status: status)
        // A hand-off means the user still has to respond in the other app, so
        // don't leave a response showing that they never made.
        if outcome != .written, willWrite { rollBack(to: previous, for: event, ifStill: status) }
        await refreshAll()
      } catch {
        if willWrite { rollBack(to: previous, for: event, ifStill: status) }
        print("Failed to respond to event: \(error)")
      }
    }
  }

  /// Only undoes our own write. Tapping through several responses leaves
  /// requests in flight together, and a late failure must not clobber a newer
  /// answer the user has since given.
  @MainActor
  private func rollBack(to previous: ParticipationStatus?, for event: Event, ifStill status: ParticipationStatus) {
    guard RSVPOverrides.shared.status(for: event) == status else { return }
    RSVPOverrides.shared.set(previous, for: event)
    refreshTick &+= 1
  }
}

@Observable
class DayEventsViewModel {
  var events: [Event] = []
  var allDayEvents: [Event] = []
  
  private let calendarService: CalendarService = AppleCalendarService()
  
  @MainActor
  func fetchEvents(for date: Date, hiddenCalendarIDs: Set<String> = []) async {
    do {
      let fetchedEvents = RSVPOverrides.shared.apply(
        to: try await calendarService.fetchEvents(for: date, hiddenCalendarIDs: hiddenCalendarIDs))
      self.allDayEvents = fetchedEvents.filter { $0.isAllDay }
      self.events = fetchedEvents.filter { !$0.isAllDay }.sorted { $0.startTime < $1.startTime }
    } catch {
      print("Error fetching events: \(error)")
      self.events = []
      self.allDayEvents = []
    }
  }
}