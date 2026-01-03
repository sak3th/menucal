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

  
  /// A stable task identifier that changes when date or hidden calendars change
  private var taskID: String {
    let hidden = eventsVM.hiddenCalendarIDs.sorted().joined(separator: ",")
    return "\(date.timeIntervalSinceReferenceDate)|\(hidden)"
  }

  var body: some View {
    HStack {
      switch dayEventsVM.events.count {
      case 4...:
        ProportionalEventCapsule(events: dayEventsVM.events)
      case 3:
        HStack(spacing: 0) {
          EventCell(event: dayEventsVM.events.first)
          EventCell(event: dayEventsVM.events[1])
          EventCell(event: dayEventsVM.events.last)
        }
      case 2:
        HStack(spacing: 0) {
          EventCell(event: dayEventsVM.events.first)
          EventCell(event: dayEventsVM.events.last)
        }
      case 1:
        EventCell(event: dayEventsVM.events.first)
      case 0:
        EventCell(event: nil)
      default:
        EventCell(event: nil)
      }
    }
    .task(id: taskID) {
      await dayEventsVM.fetchEvents(for: date, hiddenCalendarIDs: eventsVM.hiddenCalendarIDs)
    }
    .clipShape(.capsule)
    .frame(maxWidth: ViewConstants.dayEventCapsuleMaxWidth)
  }

}

struct ProportionalEventCapsule: View {
  let events: [Event]
  
  var body: some View {
    Capsule()
      .fill(
        LinearGradient(
          stops: createStops(from: events),
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: ViewConstants.dayEventCapsuleMaxWidth, height: 4)
  }
  
  // Creates sharp color transitions instead of blurry fades
  func createStops(from events: [Event]) -> [Gradient.Stop] {
    var stops: [Gradient.Stop] = []
    let step = 1.0 / Double(events.count)
    
    for (index, event) in events.enumerated() {
      let start = Double(index) * step
      let end = Double(index + 1) * step
      stops.append(.init(color: event.calendarColor, location: start))
      stops.append(.init(color: event.calendarColor, location: end))
    }
    return stops
  }
}



struct EventCell: View {
  let event: Event?
  
  var body: some View {
    Rectangle()
      .frame(width: 4, height: 4)
      .foregroundStyle(event?.calendarColor ?? .clear)
  }
}

#Preview {
  let appVM = AppViewModel()
  let eventsVM = EventsViewModel()
  DayEventsCapsule(date: appVM.selectedDate)
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(appVM)
    .environment(eventsVM)
    .padding()
}

