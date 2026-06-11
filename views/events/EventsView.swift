//
//  EventsView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 22/12/25.
//

import SwiftUI

struct EventsView: View {
  @Environment(AppViewModel.self) private var appVM
  @Environment(EventsViewModel.self) private var eventsVM
  
  @State private var dates: [Date] = []
  @State private var scrollPosition: Date?
  
  private let calendar = Calendar.current
  private let loadBatchSize = 15
  
  var body: some View {
    ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        ForEach(dates, id: \.self) { date in
          SingleDayEventsView(date: date, hiddenCalendarIDs: eventsVM.hiddenCalendarIDs)
            .frame(width: ViewConstants.monthViewWidth)
            .id(date)
        }
      }
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.paging)
    .scrollIndicators(.never)
    .scrollPosition(id: $scrollPosition)
    .onAppear {
      if dates.isEmpty {
        dates = generateDays(around: appVM.selectedDate)
        scrollPosition = appVM.selectedDate
      } else {
        // Sync on appear if needed
        scrollPosition = appVM.selectedDate
      }
    }
    .onChange(of: scrollPosition) { _, newDate in
      guard let date = newDate else { return }
      
      // Update VM if the date changed and it wasn't an external update
      if appVM.selectedDate != date {
        appVM.selectDate(date, source: .dayScroll)
      }
      
      // Buffer management
      if let index = dates.firstIndex(of: date) {
        if index < 5 {
          prependDays(count: 10, before: dates.first!)
        } else if index > dates.count - 5 {
          appendDays(count: 10, after: dates.last!)
        }
      }
    }
    .onChange(of: appVM.selectedDate) { _, newDate in
      // If the change came from outside (e.g. Month view), scroll to it
      if appVM.changeSource != .dayScroll {
        if !dates.contains(newDate) {
          dates = generateDays(around: newDate)
        }
        withAnimation {
          scrollPosition = newDate
        }
      }
    }
  }
  
  private func prependDays(count: Int, before date: Date) {
    var newItems: [Date] = []
    for i in 1...count {
      if let d = calendar.date(byAdding: .day, value: -i, to: date) {
        newItems.insert(d, at: 0)
      }
    }
    dates.insert(contentsOf: newItems, at: 0)
  }
  
  private func appendDays(count: Int, after date: Date) {
    var newItems: [Date] = []
    for i in 1...count {
      if let d = calendar.date(byAdding: .day, value: i, to: date) {
        newItems.append(d)
      }
    }
    dates.append(contentsOf: newItems)
  }
  
  private func generateDays(around date: Date) -> [Date] {
    var newDates: [Date] = []
    for offset in -loadBatchSize...loadBatchSize {
      if let d = calendar.date(byAdding: .day, value: offset, to: date) {
        newDates.append(d)
      }
    }
    return newDates
  }
}

struct SingleDayEventsView: View {
  let date: Date
  let hiddenCalendarIDs: Set<String>
  @Environment(EventsViewModel.self) private var eventsVM
  @State private var viewModel = DayEventsViewModel()
  
  var body: some View {
    ScrollView {
      if viewModel.allDayEvents.isEmpty && viewModel.events.isEmpty {
        ContentUnavailableView("No Events", systemImage: "calendar.badge.exclamationmark")
          .padding(.top, 32)
          .opacity(0.5)
      } else {
        VStack(alignment: .center, spacing: 0) {
          if !viewModel.allDayEvents.isEmpty {
            let allDayEvents = viewModel.allDayEvents
            ForEach(Array(allDayEvents.enumerated()), id: \.element.id) { index, event in
              VStack(spacing: 0) {
                if !event.isUnaccepted && (index == 0 || !allDayEvents[index - 1].isUnaccepted) {
                  Divider().opacity(0.5)
                }
                Spacer().frame(height: 8)
                DayEventView(event: event)
                  .padding(.horizontal, 8)
                Spacer().frame(height: 8)
              }
            }
          }
          
          if !viewModel.events.isEmpty {
            let events = viewModel.events
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
              VStack(spacing: 0) {
                if !event.isUnaccepted && (index == 0 || !events[index - 1].isUnaccepted) {
                  Divider().opacity(0.5)
                }
                Spacer().frame(height: 8)
                EventView(event: event)
                  .padding(.horizontal, 8)
                Spacer().frame(height: 8)
              }
            }
          }

          Spacer().frame(height: 48)
        }
      }
    }
    .scrollIndicators(.hidden)
    .task(id: date) {
      await viewModel.fetchEvents(for: date, hiddenCalendarIDs: hiddenCalendarIDs)
    }
    .onChange(of: hiddenCalendarIDs) {
      Task {
        await viewModel.fetchEvents(for: date, hiddenCalendarIDs: hiddenCalendarIDs)
      }
    }
    .onChange(of: eventsVM.refreshTick) {
      Task {
        await viewModel.fetchEvents(for: date, hiddenCalendarIDs: hiddenCalendarIDs)
      }
    }
    .scrollBounceBehavior(.always)
  }
}

struct DayEventView: View {
  @Environment(AppViewModel.self) private var appVM

  let event: Event
  
  var body: some View {
    HStack {
      Image(systemName: "calendar")
        .font(.system(size: 11))
        .foregroundStyle(event.calendarColor.contrastingForegroundColor)
        .padding(4)
        .background(Circle().fill(event.calendarColor))
      
      Text(event.title).fontWeight(.medium).singlelineText()
      Spacer()
      Text("all-day").fontWeight(.light).foregroundStyle(.secondary)
    }
    .contentShape(Rectangle()) // Make the whole row tappable
    .onTapGesture {
      appVM.selectedEvent = event
    }
  }
}

struct EventView: View {
  @Environment(AppViewModel.self) private var appVM

  let event: Event
  
  @State private var isHovering = false
  @State private var isHoveringOnVideoLink = false
  
  private var isDeclined: Bool {
    event.participationStatus == .declined
  }
  
  private var isUnaccepted: Bool {
    event.participationStatus == .pending || event.participationStatus == .tentative
  }
  
  private var timeFormatter: DateFormatter {
    let df = DateFormatter()
    df.dateStyle = .none
    df.dateFormat = "h:mma"
    return df
  }
  
  var body: some View {
    HStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 10)
        .frame(width: 3)
        .foregroundColor(event.calendarColor)
      
      VStack(alignment: .leading, spacing: 2) {
        // First Row: Title + Start Time
        HStack {
          Text(event.title)
            .font(.system(size: 13, weight: .medium))
            .strikethrough(isDeclined)
            .singlelineText()
          Spacer()
          
          Text(event.startTime.formattedTime(timeSize: 13, amPmSize: 10))
            .font(.system(.body, weight: .light))
            .strikethrough(isDeclined)
            .monospacedDigit()
        }
        .foregroundStyle(isDeclined ? .secondary : .primary)
        
        // Second Row: Icon + Location/Link + End Time
        HStack {
          Group {
            if let url = event.videoCallLink {
              Link(destination: url) {
                HStack(spacing: 4) {
                  Image(systemName: "video")
                  Text(event.meetingProvider)
                    .strikethrough(isDeclined)
                    .singlelineText()
                }
              }
              .buttonStyle(.plain)
              .onHover { inside in
                isHoveringOnVideoLink = inside
                if inside { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
              }
              .background(
                Group {
                  if isHoveringOnVideoLink {
                    RoundedRectangle(cornerRadius: 4)
                      .fill(Color.gray.opacity(0.15))
                      .padding(.horizontal, -4)
                      .padding(.vertical, -2)
                  } else {
                    Color.clear
                  }
                }
              )
            } else if let location = event.location, !location.isEmpty {
              LocationButton(location: location, isDeclined: isDeclined)
            } else {
              Text(" ") // Placeholder to keep height if needed, or EmptyView
            }
          }
          .font(.caption)
          .lineLimit(1)
          
          Spacer()
          
          Text(event.endTime.formattedTime(timeSize: 13, amPmSize: 10))
            .font(.system(.body, weight: .light))
            .monospacedDigit()
            .strikethrough(isDeclined)
        }
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 0)
    }
    //.frame(height: 40) // Ensure consistent height approx 2 lines
    .background {
      if isUnaccepted {
        SlantedStripes(color: event.calendarColor.opacity(0.15))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .padding(.horizontal, -8)
          .padding(.vertical, -8)
      } else {
        Group {
          if isHovering {
            RoundedRectangle(cornerRadius: 4)
              .fill(event.calendarColor.opacity(0.15))
              .padding(.horizontal, -8)
              .padding(.vertical, -8)
          } else {
            Color.clear
          }
        }
      }
    }
    .contentShape(Rectangle()) // Make the whole row tappable
    .onTapGesture {
      appVM.selectedEvent = event
    }
    .onHover() { inside in
      isHovering = inside
    }
  }
}

struct SlantedStripes: View {
  let color: Color
  let width: CGFloat = 4
  let spacing: CGFloat = 8
  
  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let diagonal = sqrt(size.width * size.width + size.height * size.height)
      let count = Int(diagonal / spacing)
      
      Path { path in
        for i in -count...count + 20 {
          let x = CGFloat(i) * spacing
          path.move(to: CGPoint(x: x, y: 0))
          path.addLine(to: CGPoint(x: x - size.height, y: size.height))
        }
      }
      .stroke(color, lineWidth: width)
      .clipped()
    }
  }
}

struct LocationButton: View {
  let location: String
  var isDeclined: Bool = false
  @Environment(\.openURL) var openURL
  
  var body: some View {
    Button(action: {
      if let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
         let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
        openURL(url)
      }
    }) {
      HStack(spacing: 4) {
        Image(systemName: "mappin.and.ellipse")
        Text(location)
          .strikethrough(isDeclined)
          .singlelineText()
      }
    }
    .buttonStyle(.plain)
    .onHover { inside in
      if inside { NSCursor.pointingHand.push() }
      else { NSCursor.pop() }
    }
  }
}

#Preview("") {
  EventsView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .padding(8)
    .frame(width: ViewConstants.appWidth)
}

