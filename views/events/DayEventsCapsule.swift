//
//  DayEventsCapsule.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 03/01/26.
//

import SwiftUI

struct DayEventsCapsule: View {
  @Environment(AppViewModel.self) private var appVM
  @Environment(EventsViewModel.self) private var eventsVM

  let date: Date

  @State private var dayEventsVM = DayEventsViewModel()

  /// All events for the day (excludes all-day events)
  var events: [Event] {
    dayEventsVM.events
  }

  /// All-day events for the day
  var allDayEvents: [Event] {
    dayEventsVM.allDayEvents
  }

  var body: some View {
    EmptyView()
      .task(id: date) {
        await fetchEventsForDay()
      }
  }

  /// Fetches all events for this day, respecting hidden calendars
  private func fetchEventsForDay() async {
    await dayEventsVM.fetchEvents(for: date, hiddenCalendarIDs: eventsVM.hiddenCalendarIDs)
  }
}

#Preview {
  let appVM = AppViewModel()
  let eventsVM = EventsViewModel()
  DayEventsCapsule(date: appVM.selectedDate)
    .environment(appVM)
    .environment(eventsVM)
}
