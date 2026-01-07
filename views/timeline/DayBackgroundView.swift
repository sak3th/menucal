//
//  DayBackgroundView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 27/11/25.
//

import SwiftUI

struct DayBackgroundView: View {
  let hourSpacing: Int
  init(hourSpacing: Int? = nil) {
    self.hourSpacing = hourSpacing ?? 60
  }
  
  @State private var hourDividerHeight: CGFloat = 0
  @State private var currentTimeViewHeight: CGFloat = 0
  
  var body: some View {
    
    TimelineView(.everyMinute) { (context: TimelineViewDefaultContext) in
      let now = context.date
      
      var currentTimeOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        // Calculate offset from midnight
        let totalMinutes = CGFloat(hour * 60 + minute)
        let minutesPerHour: CGFloat = 60
        
        // Position = (hours * hourSpacing) + (minutes/60 * hourSpacing)
        return (totalMinutes / minutesPerHour) * CGFloat(hourSpacing) - currentTimeViewHeight/2
      }
      
      ScrollView {
        ZStack(alignment: .topLeading) {
          VStack(spacing: CGFloat(hourSpacing) - hourDividerHeight) {
            HourDivider(time: "12", amPm: "AM") { h in
              hourDividerHeight = h
            }
            
            ForEach(1...12, id: \.self) { index in
              HourDivider(time: "\(index)", amPm: "AM")
            }
            ForEach(13...24, id: \.self) { index in
              let hour = index - 12
              HourDivider(time: "\(hour)", amPm: "PM")
            }
          }
          
          CurrentTimeView(time: Self.formatter.string(from: now)) { h in
            currentTimeViewHeight = h
          }
          .offset(y: currentTimeOffset)
        }
        
      }
      .scrollIndicators(.hidden)
    }
  }
  
  
  
  private static let formatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "h:mm" // or use dateStyle/timeStyle
    return df
  }()
  
}

struct HourDivider: View {
  let time: String
  let amPm: String
  let onHeightCalculated: ((CGFloat) -> Void)?
  
  init(time: String, amPm: String, onHeightCalculated: ((CGFloat) -> Void)? = nil) {
    self.time = time
    self.amPm = amPm
    self.onHeightCalculated = onHeightCalculated
  }
  
  @State var height: CGFloat = 0
  
  var body: some View {
    HStack(alignment: .center, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(time)
          .font(.system(size: 11, weight: .regular))
          .opacity(0.6)
          .fixedSize(horizontal: true, vertical: false)  // Allow horizontal overflow
          .frame(width: 14)
        //.lineLimit(1, reservesSpace: true)
        Text(amPm)
        //.lineLimit(1, reservesSpace: true)
          .font(.system(size: 10, weight: .regular))
          .opacity(0.3)
          .baselineOffset(-0.06)
      }
      
      VStack {
        Divider()
      }
    }
    .background() {
      GeometryReader { geometry in
        Color.clear.onAppear {
          height = geometry.size.height
          onHeightCalculated?(geometry.size.height)
        }
      }
    }
    .offset(y: -height / 2)
  }
}

#Preview {
  DayBackgroundView(hourSpacing: 60)
    .padding(0)
}
