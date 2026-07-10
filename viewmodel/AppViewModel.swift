//
//  AppViewModel.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import Foundation
import EventKit
import AppKit

enum ChangeSource {
  case none, dayScroll, monthScroll, weekScroll, external
}

enum OverlayMode: Hashable {
  case none, eventsMenu, calendarViewMenu, calendarList, settings
}

enum CalendarViewMode: String, Hashable {
  case month, week
}

@Observable
class AppViewModel: Identifiable {

  let calendar = Calendar.current

  var changeSource: ChangeSource = .none

  // Live popover height, scaled to whichever display the popover opens on.
  // Every height frame reads this single value so they always agree.
  var appHeight: CGFloat = ViewConstants.appHeight

  func updateAppHeight(for screen: NSScreen?, fraction: CGFloat = ViewConstants.appHeightFraction) {
    let visibleHeight = (screen ?? NSScreen.main)?.visibleFrame.height ?? 900
    let height = min(
      max(visibleHeight * fraction, ViewConstants.minAppHeight),
      ViewConstants.maxAppHeight
    )
    if height != appHeight { appHeight = height }
  }

  var activeOverlay: OverlayMode = .none

  func dismissOverlays() {
    activeOverlay = .none
  }

  var selectedEventsView: CalViewMode = .timeline {
    didSet { UserDefaults.standard.set(selectedEventsView.rawValue, forKey: "selectedEventsView") }
  }
  var selectedCalendarView: CalendarViewMode = .month {
    didSet { UserDefaults.standard.set(selectedCalendarView.rawValue, forKey: "selectedCalendarView") }
  }

  func getEventsViewSymbol() -> String {
    switch selectedEventsView {
    case .timeline:
      return "calendar.day.timeline.left"
    case .list:
      return "list.dash"
    }
  }

  func getCalendarViewSymbol() -> String {
    switch selectedCalendarView {
    case .month:
      return "31.square"
    case .week:
      return "7.square"
    }
  }

  func toggleCalendarView() {
    selectedCalendarView = selectedCalendarView == .month ? .week : .month
  }

  func toggleEventsView() {
    selectedEventsView = selectedEventsView == .timeline ? .list : .timeline
  }


  var selectedDate: Date
  var selectedMonth: Date
  // Bumped when the popover becomes key after a day rollover moved the
  // selection, so views kept alive while hidden can resync the scroll they
  // couldn't perform offscreen. Not bumped on ordinary reopens, which would
  // clobber the user's browsed position.
  private(set) var daySyncTick: Int = 0
  private var needsDaySync = false
  private(set) var lastKnownToday: Date

  private var dayChangeObserver: NSObjectProtocol?

  init() {
    let todayStart = calendar.startOfDay(for: Date())
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
    selectedDate = todayStart
    selectedMonth = monthStart
    lastKnownToday = todayStart
    changeSource = .external
    selectedEvent = nil

    // Restore the last-used views.
    let defaults = UserDefaults.standard
    if let raw = defaults.string(forKey: "selectedEventsView"), let v = CalViewMode(rawValue: raw) {
      selectedEventsView = v
    }
    if let raw = defaults.string(forKey: "selectedCalendarView"), let v = CalendarViewMode(rawValue: raw) {
      selectedCalendarView = v
    }

    dayChangeObserver = NotificationCenter.default.addObserver(
      forName: .NSCalendarDayChanged,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.handleDayChanged()
      }
    }
  }

  deinit {
    if let dayChangeObserver {
      NotificationCenter.default.removeObserver(dayChangeObserver)
    }
  }

  // MARK: - Intents

  func onAppStart() {
    handleDayChanged()
  }

  func handleWindowBecameKey(resetToToday: Bool = false) {
    handleDayChanged()
    if resetToToday {
      goHome()
      needsDaySync = true
    }
    if needsDaySync {
      needsDaySync = false
      daySyncTick &+= 1
    }
  }

  // Close the menu bar popover (no public API; order the panel out).
  func dismissPopover() {
    for window in NSApp.windows
    where abs(window.frame.width - ViewConstants.appWidth) < 80 {
      window.orderOut(nil)
    }
  }

  // Return to a clean starting state: today, no event detail, no menus.
  func goHome() {
    selectedEvent = nil
    activeOverlay = .none
    let now = Date()
    selectedDate = calendar.startOfDay(for: now)
    selectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    changeSource = .external
  }

  func handleDayChanged() {
    let newToday = calendar.startOfDay(for: Date())
    guard !calendar.isDate(newToday, inSameDayAs: lastKnownToday) else { return }
    let wasOnPreviousToday = calendar.isDate(selectedDate, inSameDayAs: lastKnownToday)
    lastKnownToday = newToday

    if wasOnPreviousToday {
      selectedDate = newToday
      selectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: newToday)) ?? newToday
      changeSource = .external
      needsDaySync = true
    }
  }

  func onMonthScrolled(_ date: Date) {
    let now = Date()
    // If scrolled to the current month, select Today's date
    if calendar.isDate(date, equalTo: now, toGranularity: .month) {
      selectedDate = calendar.startOfDay(for: now)
    } else {
      // Otherwise select the 1st of that month
      selectedDate = date
    }
    
    selectedMonth = date
    changeSource = .monthScroll
  }

  func onTodayClicked() {
    let now = Date()
    selectedDate = calendar.startOfDay(for: now)
    selectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    changeSource = .external
  }

  func selectDate(_ date: Date, source: ChangeSource = .external) {
    selectedDate = calendar.startOfDay(for: date)
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) ?? selectedDate

    changeSource = source

    if !calendar.isDate(monthStart, inSameDayAs: selectedMonth) {
      selectedMonth = monthStart
    }
  }

  // MARK: - Keyboard Navigation

  func goToPrevDate() {
    if let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
      selectDate(newDate, source: .external)
    }
  }

  func goToNextDate() {
    if let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
      selectDate(newDate, source: .external)
    }
  }

  func goToPrevMonth() {
    if let newMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
      onMonthScrolled(newMonth)
      changeSource = .external
    }
  }

  func goToNextMonth() {
    if let newMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
      onMonthScrolled(newMonth)
      changeSource = .external
    }
  }

  func goToPrevWeek() {
    if let startOfWeek = startOfWeek(for: selectedDate),
       let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek) {
      onWeekScrolled(prevWeekStart)
      changeSource = .external
    }
  }

  func goToNextWeek() {
    if let startOfWeek = startOfWeek(for: selectedDate),
       let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) {
      onWeekScrolled(nextWeekStart)
      changeSource = .external
    }
  }

  func onWeekScrolled(_ date: Date) {
    let now = Date()
    // If scrolled to the current week, select today
    if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) &&
       calendar.isDate(date, equalTo: now, toGranularity: .yearForWeekOfYear) {
      selectedDate = calendar.startOfDay(for: now)
    } else {
      // Select the start of that week
      if let weekStart = startOfWeek(for: date) {
        selectedDate = weekStart
      } else {
        selectedDate = calendar.startOfDay(for: date)
      }
    }

    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) ?? selectedDate
    if !calendar.isDate(monthStart, inSameDayAs: selectedMonth) {
      selectedMonth = monthStart
    }
    changeSource = .weekScroll
  }

  private func startOfWeek(for date: Date) -> Date? {
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return calendar.date(from: components)
  }


  var selectedEvent: Event?
  func selectEvent(_ event: Event) {
    selectedEvent = event
  }

}


enum CalViewMode: String, Hashable {
  case timeline, list
}
