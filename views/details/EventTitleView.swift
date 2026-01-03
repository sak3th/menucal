//
//  EventTitleView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 02/01/26.
//

import SwiftUI

struct EventTitleView: View {
  let event: Event

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(event.title)
        .font(.title2)
        .fontWeight(.medium)

      if let location = event.location, !location.isEmpty {
        Text(location)
          .font(.subheadline)
          .foregroundStyle(.primary)
      }
    }
  }
}

#Preview {
  EventTitleView(event: SampleEvent.event)
    .padding()
}
