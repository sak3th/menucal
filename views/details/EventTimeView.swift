//
//  EventTimeView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 02/01/26.
//

import SwiftUI

struct EventTimeView: View {
  let event: Event

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Spacer().frame(height: 16)
      
      Text(formatDate(event.startTime))
        .font(.subheadline)
        .foregroundStyle(.primary)

      Text("\(formatTime(event.startTime)) - \(formatTime(event.endTime))")
        .font(.subheadline)
        .foregroundStyle(.primary)

      if let recurrence = event.recurrenceRule {
        Text(recurrence.description)
          .font(.subheadline)
          .foregroundStyle(.red)
      }
    }
  }

  // MARK: - Formatters

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    return formatter.string(from: date)
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}

#Preview {
  EventTimeView(event: SampleEvent.event)
    .padding()
}
