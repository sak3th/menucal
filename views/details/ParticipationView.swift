//
//  ParticipationStatus.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 03/01/26.
//

import SwiftUI

struct ParticipationView: View {
  
  @Environment(EventsViewModel.self) private var eventsVM
  let event: Event
  

  var body: some View {
    VStack {
      Spacer().frame(height: 16)
      
      if [.accepted, .tentative, .declined].contains(event.participationStatus) {
        ChangeResponseView(event: event)
      } else {
        RespondView(event: event)
      }
    }
  }
}

struct ChangeResponseView: View {
  @Environment(EventsViewModel.self) private var eventsVM
  let event: Event
  @State private var selectedStatus: ParticipationStatus = .unknown
  
  init(event: Event) {
    self.event = event
    _selectedStatus = State(initialValue: event.participationStatus)
  }
  
  var body: some View {
      DetailSection {
        HStack {
          Text("My status").fontWeight(.regular)
          Picker("My status", selection: $selectedStatus) {
            ForEach([ParticipationStatus.accepted, .tentative, .declined], id: \.self) { status in
              Label {
                Text(status.rawValue).fontWeight(.bold)
              } icon : {
                Image(systemName: status.icon).tint(status.color)
              }
            }
          }
          .pickerStyle(.menu)
          .buttonStyle(.accessoryBar)
          .onChange(of: selectedStatus) { _, newStatus in
            Task {
              await eventsVM.respondToEvent(event: event, status: newStatus)
            }
          }

          Spacer()
        }
      }
  }
}

struct RespondView: View {
  @Environment(EventsViewModel.self) private var eventsVM
  let event: Event
  
  var body: some View {
    HStack {
      Button("Maybe") {
        Task {
          await eventsVM.respondToEvent(event: event, status: .tentative)
        }
      }
      Spacer()
      Button("Decline") {
        Task {
          await eventsVM.respondToEvent(event: event, status: .declined)
        }
      }
      Button("Accept") {
        Task {
          await eventsVM.respondToEvent(event: event, status: .accepted)
        }
      }
    }
    
  }
  
}

#Preview("Change response") {
  ParticipationView(event: SampleEvent.event)
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth)
    .padding()
}

#Preview("Not responded") {
  let event = Event(
    id: "empty",
    title: "Solo Event",
    startTime: Date(),
    endTime: Date().addingTimeInterval(3600),
    isAllDay: false,
    calendarColor: .blue,
    location: nil,
    notes: nil,
    url: nil,
    isRecurring: false,
    recurrenceRule: nil,
    organizer: nil,
    attendees: [],
    participationStatus: .unknown,
    calendarTitle: "Personal",
    calendarSource: "iCloud"
  )
  ParticipationView(event: event)
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth)
    .padding()
}
