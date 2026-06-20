//
//  ParticipantsView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 02/01/26.
//

import SwiftUI

struct ParticipantsView: View {
  let event: Event
  
  /// Returns true if there are no meaningful participants to display.
  /// This includes: no organizer and no attendees, or only a single attendee who is the current user.
  private var hasNoParticipants: Bool {
    let hasValidOrganizer = event.organizer != nil && event.organizer?.displayName != "Unknown Organizer"
    let hasAttendees = !event.attendees.isEmpty
    let onlyCurrentUser = event.attendees.count == 1 && event.attendees.first?.isCurrentUser == true
    
    if !hasValidOrganizer && !hasAttendees {
      return true
    }
    
    if !hasValidOrganizer && onlyCurrentUser {
      return true
    }
    
    return false
  }
  
  var body: some View {
    if hasNoParticipants {
      EmptyView()
    } else {
      VStack {
        Spacer().frame(height: 16)
        
        DetailSection {
          VStack(alignment: .leading, spacing: 2) {
            // Organizer / Inviter
            if let organizer = event.organizer {
              VStack(alignment: .leading, spacing: 2) {
                Text("Invitation from")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                
                ParticipantRow(participant: organizer)
                
                if !event.attendees.isEmpty {
                  Divider().frame(height: 8)
                }
              }
            }
            
            // Invitees Grouped by status (excluding current user from display)
            let attendeesExcludingCurrentUser = event.attendees.filter { !$0.isCurrentUser }
            let accepted = attendeesExcludingCurrentUser.filter { $0.participationStatus == .accepted }
            let declined = attendeesExcludingCurrentUser.filter { $0.participationStatus == .declined }
            let pending = attendeesExcludingCurrentUser.filter {
              $0.participationStatus == .pending ||
              $0.participationStatus == .tentative ||
              $0.participationStatus == .unknown
            }
            
            if !attendeesExcludingCurrentUser.isEmpty {
              if !accepted.isEmpty {
                ParticipantGroup(participants: accepted)
              }
              if !declined.isEmpty {
                Spacer().frame(height: 4)
                ParticipantGroup(participants: declined)
              }
              if !pending.isEmpty {
                Spacer().frame(height: 4)
                ParticipantGroup(participants: pending)
              }
            }
          }
        }
      }
    }
  }
}

// MARK: - ParticipantGroup

private struct ParticipantGroup: View {
  let participants: [Participant]
  
  let columns = [
    GridItem(.flexible(), alignment: .leading),
    GridItem(.flexible(), alignment: .leading)
  ]
  
  var body: some View {
    LazyVGrid(columns: columns, spacing: 2) {
      ForEach(participants) { participant in
        ParticipantRow(participant: participant)
      }
    }
  }
}

// MARK: - ParticipantRow

private struct ParticipantRow: View {
  let participant: Participant
  
  var body: some View {
    Label {
      Text(participant.displayName)
        .font(.system(size: 12, weight: .regular))
        .truncationMode(.tail)
        .offset(x: -4.0)
        .singlelineText()
    } icon: {
      Image(systemName: iconName)
        .foregroundStyle(participant.participationStatus.color)
        .font(.system(size: 12))
    }
  }
  
  var iconName: String {
    switch participant.participationStatus {
    case .accepted: return "checkmark.circle"
    case .declined: return "xmark.circle"
    case .tentative, .pending, .unknown: return "questionmark.circle"
    }
  }
}

// MARK: - Previews

#Preview("With Organizer and Attendees") {
  ParticipantsView(event: SampleEvent.event)
    .padding()
}

#Preview("No Participants") {
  let emptyEvent = Event(
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
    participationStatus: .accepted,
    calendarTitle: "Personal",
    calendarSource: "iCloud"
  )
  
  VStack {
    Text("ParticipantsView returns EmptyView:")
    ParticipantsView(event: emptyEvent)
    Text("(nothing above this line)")
  }
  .padding()
}

#Preview("Only Current User") {
  let currentUserOnlyEvent = Event(
    id: "current-user-only",
    title: "My Personal Event",
    startTime: Date(),
    endTime: Date().addingTimeInterval(3600),
    isAllDay: false,
    calendarColor: .green,
    location: nil,
    notes: nil,
    url: nil,
    isRecurring: false,
    recurrenceRule: nil,
    organizer: nil,
    attendees: [
      Participant(id: "me", name: "Current User", email: "me@example.com", isCurrentUser: true, participationStatus: .accepted)
    ],
    participationStatus: .accepted,
    calendarTitle: "Personal",
    calendarSource: "iCloud"
  )
  
  VStack {
    Text("ParticipantsView returns EmptyView (only current user):")
    ParticipantsView(event: currentUserOnlyEvent)
    Text("(nothing above this line)")
  }
  .padding()
}
