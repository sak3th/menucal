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
  
  @State private var currentTimeViewHeight: CGFloat = 0
  
  var body: some View {
    
    TimelineView(.everyMinute) { (context: TimelineViewDefaultContext) in
      let now = context.date
      
      var currentTimeOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        return (CGFloat(hour) * (CGFloat(hourSpacing) + ViewConstants.timelineDividerHeight)) + ViewConstants.timelineDividerHeight + (CGFloat(minute) / 60.0 * CGFloat(hourSpacing)) - currentTimeViewHeight/2
      }
      
      ScrollView {
        ZStack(alignment: .topLeading) {
          DayTimelineGrid(hourSpacing: hourSpacing)
          
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

struct DayTimelineGrid: View {
  let hourSpacing: Int

  init(hourSpacing: Int) {
    self.hourSpacing = hourSpacing
  }

  var body: some View {
    VStack(spacing: 0) {
      ForEach(0..<25, id: \.self) { hour in
        HourDivider(time: formatHour(hour), amPm: formatAmPm(hour))
          .frame(height: ViewConstants.timelineDividerHeight)
          .id("hour-\(hour)")

        if hour < 24 {
          Spacer().frame(height: CGFloat(hourSpacing))
        }
      }
    }
  }

  func formatHour(_ hour: Int) -> String {
    if hour == 0 || hour == 24 { return "12" }
    if hour == 12 { return "12" }
    return "\(hour > 12 ? hour - 12 : hour)"
  }

  func formatAmPm(_ hour: Int) -> String {
    if hour == 24 { return "AM" } // Next day
    return hour < 12 ? "AM" : "PM"
  }
}


struct HourDivider: View {
  let time: String
  let amPm: String
  
  var body: some View {
    HStack(alignment: .center, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(time)
          .font(.system(size: 11, weight: .regular))
          .opacity(0.6)
          .fixedSize(horizontal: true, vertical: false)
          .frame(width: 14)
        Text(amPm)
          .font(.system(size: 10, weight: .regular))
          .opacity(0.3)
          .baselineOffset(-0.06)
      }
      
      VStack {
        Divider().frame(height: ViewConstants.timelineDividerHeight)
      }
    }
  }
}

#Preview {
  DayBackgroundView(hourSpacing: 60)
    .padding(0)
}
