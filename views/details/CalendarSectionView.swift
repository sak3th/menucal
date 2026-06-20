//
//  CalendarSectionView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 02/01/26.
//

import SwiftUI

struct CalendarSectionView: View {
  let event: Event
  
  var body: some View {
    VStack {
      Spacer().frame(height: 16)
      
      DetailSection {
        HStack(alignment: .center, spacing: 0) {
          Text("Calendar")
            .fontWeight(.regular)
            .singleLineCenteredText()
          
          Spacer()
          
          Label {
            Text(event.calendarTitle)
              .font(.system(size: 12, weight: .regular))
              .offset(x: -2.0)
          } icon: {
            Circle()
              .fill(event.calendarColor)
              .frame(width: 10, height: 10)
          }
        }
        .frame(height: 20)
      }
    }
  }
}

#Preview {
  CalendarSectionView(event: SampleEvent.event)
    .padding()
}
