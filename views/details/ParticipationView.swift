//
//  ParticipationStatus.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 03/01/26.
//

import SwiftUI

// One control for every state. Previously this swapped between three separate
// views — respond / sending / respond-again — which meant the layout changed
// shape twice per RSVP. A segmented control expresses all three: no highlight
// means no response yet, a highlight means that's your answer, and a spinner
// on the highlighted segment means it's still going.
struct ParticipationView: View {
  @Environment(EventsViewModel.self) private var eventsVM
  let event: Event

  @Namespace private var selectionNamespace

  private static let options: [ParticipationStatus] = [.accepted, .tentative, .declined]

  // Nil until the user has actually responded, so an unanswered invite shows
  // three equal choices rather than a default that looks like an answer.
  private var selected: ParticipationStatus? {
    let status = eventsVM.displayStatus(for: event)
    return Self.options.contains(status) ? status : nil
  }

  var body: some View {
    VStack {
      Spacer().frame(height: 16)

      GlassEffectContainer {
        HStack(spacing: 0) {
          ForEach(Self.options, id: \.self) { status in
            ResponseButton(
              title: Self.label(for: status),
              color: status.color,
              isSelected: selected == status,
              namespace: selectionNamespace
            ) {
              guard selected != status else { return }
              eventsVM.respondToEvent(event: event, status: status)
            }
          }
        }
        .padding(4)
        .glassEffect(in: Capsule())
      }
      .animation(.smooth(duration: 0.28), value: selected)
    }
  }

  // The control offers actions, so the segments read as verbs even once one is
  // selected — "Accept" highlighted says the same thing as "Accepted" without
  // the text changing width under the selection capsule.
  private static func label(for status: ParticipationStatus) -> String {
    switch status {
    case .accepted: return "Accept"
    case .tentative: return "Maybe"
    case .declined: return "Decline"
    default: return status.rawValue
    }
  }
}

#Preview("Responded") {
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
