//
//  AppViewModel.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import Foundation
import EventKit

enum ChangeSource {
  case none, dayScroll, monthScroll, external
}

@Observable
class AppViewModel: Identifiable {

  let calendar = Calendar.current
  
  var changeSource: ChangeSource = .none

  var selectedEventsView: CalViewMode = .timeline

  func getEventsViewSymbol() -> String {
    switch selectedEventsView {
    case .timeline:
      return "calendar.day.timeline.left"
    case .list:
      return "list.dash"
    }
  }


  var selectedDate: Date
  var selectedMonth: Date
  var shouldScrollToSelection: Bool = false

  init() {
    let todayStart = calendar.startOfDay(for: Date())
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
    selectedDate = todayStart
    selectedMonth = monthStart
    changeSource = .external
    selectedEvent = nil
  }

  // MARK: - Intents

  func onAppStart() {
    let now = Date()
    selectedDate = calendar.startOfDay(for: now)
    selectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    changeSource = .external
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


  var selectedEvent: Event?
  func selectEvent(_ event: Event) {
    selectedEvent = event
  }

}


enum CalViewMode: Hashable {
  case timeline, list
}
