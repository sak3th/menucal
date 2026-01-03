//
//  SampleEvent.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 29/12/25.
//

import Foundation
import SwiftUI

/// Sample event used for SwiftUI previews across detail views
enum SampleEvent {
  static let event = Event(
    id: "1",
    title: "Weekly Team Sync",
    startTime: Date(),
    endTime: Date().addingTimeInterval(3600),
    isAllDay: false,
    calendarColor: .blue,
    location: "Conference Room A",
    notes: "<b>Agenda:</b><br>1. Discuss project updates.<br>2. Review timeline.<br><a href='https://zoom.us/j/123456789'>Zoom Link</a>",
    url: URL(string: "https://zoom.us/j/123456789"),
    isRecurring: true,
    recurrenceRule: RecurrenceRule(frequency: .weekly, interval: 1, endDate: nil, occurrenceCount: nil),
    organizer: Participant(id: "org1", name: "Alice Manager", email: "alice@example.com", isCurrentUser: false, participationStatus: .accepted),
    attendees: [
      Participant(id: "att1", name: "Bob Developer", email: "bob@example.com", isCurrentUser: true, participationStatus: .accepted),
      Participant(id: "att2", name: "Charlie Designer", email: "charlie@example.com", isCurrentUser: false, participationStatus: .accepted),
      Participant(id: "att3", name: "Dave DevOps", email: "dave@example.com", isCurrentUser: false, participationStatus: .declined),
      Participant(id: "att4", name: "Eve External", email: "eve@example.com", isCurrentUser: false, participationStatus: .pending),
      Participant(id: "att5", name: "Charlie Designer", email: "charlie@example.com", isCurrentUser: false, participationStatus: .accepted),
      Participant(id: "att6", name: "Charlie Designer", email: "charlie@example.com", isCurrentUser: false, participationStatus: .accepted),
      Participant(id: "att7", name: "Charlie Designer", email: "charlie@example.com", isCurrentUser: false, participationStatus: .accepted),
      Participant(id: "att8", name: "Charlie Designer", email: "charlie@example.com", isCurrentUser: false, participationStatus: .accepted),
      Participant(id: "att9", name: "Charlie Designer", email: "charlie@example.com", isCurrentUser: false, participationStatus: .accepted),
    ],
    participationStatus: .accepted,
    calendarTitle: "v.saketh@gmail.com",
    calendarSource: "Exchange"
  )
}
