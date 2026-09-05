//
//  EventDetailView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 29/12/25.
//

import SwiftUI

struct EventDetailView: View {

  let event: Event

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      
      EventTitleView(event: event)
      
      EventTimeView(event: event)
      
      VideoCallView(event: event)
      
      CalendarSectionView(event: event)
      
      ParticipantsView(event: event)
      
      NotesView(event: event)
    }
    
    
  }
}

// MARK: - Preview

#Preview {
  ScrollView {
    EventDetailView(event: SampleEvent.event)
      .padding()
  }
  .frame(width: ViewConstants.appWidth, height: 700)
  .environment(EventsViewModel())
}

