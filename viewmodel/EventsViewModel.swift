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
  var isRefreshing: Bool = false
  // Bumped whenever underlying data may have changed; day views re-fetch on it.
  var refreshTick: Int = 0

  private let calendarService: CalendarService = AppleCalendarService()
  private var storeChangedObserver: NSObjectProtocol?

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
        self?.refreshTick &+= 1
        await self?.fetchCalendars()
      }
    }
  }

  deinit {
    if let storeChangedObserver {
      NotificationCenter.default.removeObserver(storeChangedObserver)
    }
  }
  
  func refreshAll() async {
    isRefreshing = true
    calendarService.refreshData()
    await fetchCalendars()
    try? await Task.sleep(for: .seconds(1))
    isRefreshing = false
    refreshTick &+= 1
  }
  
  func fetchCalendars() async {
    do {
      let fetched = try await calendarService.fetchCalendars()
      calendars = fetched
    } catch {
      print("Error fetching calendars: \(error)")
    }
  }
  
  func toggleCalendarVisibility(id: String) {
    if hiddenCalendarIDs.contains(id) {
      hiddenCalendarIDs.remove(id)
    } else {
      hiddenCalendarIDs.insert(id)
    }
  }

  func respondToEvent(event: Event, status: ParticipationStatus) async {
    do {
      try await calendarService.respondToEvent(event: event, status: status)
      await refreshAll()
    } catch {
      print("Failed to respond to event: \(error)")
    }
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
      let fetchedEvents = try await calendarService.fetchEvents(for: date, hiddenCalendarIDs: hiddenCalendarIDs)
      self.allDayEvents = fetchedEvents.filter { $0.isAllDay }
      self.events = fetchedEvents.filter { !$0.isAllDay }.sorted { $0.startTime < $1.startTime }
    } catch {
      print("Error fetching events: \(error)")
      self.events = []
      self.allDayEvents = []
    }
  }
}