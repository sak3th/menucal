//
//  DayTimelineView.swift
//  MenuCal
//
//  Created by Gemini on 07/01/26.
//

import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

struct DayTimelineView: View {
  let date: Date
  @Binding var lastScrollHour: Int
  @Environment(AppViewModel.self) private var appVM
  @State private var viewModel = DayEventsViewModel()
  @State private var currentTimeViewHeight: CGFloat = 0
  @State private var scrolledID: String?
  @State private var isScrollReady = false
  @State private var hasPerformedInitialScroll = false

  // Layout Constants
  private let hourSpacing: CGFloat = 60
  private let timeColumnWidth: CGFloat = 42 // Space for hour labels
  private let minVisualDuration: TimeInterval = 10 * 60 // 10 minutes minimum visual duration
  private let eventVerticalPadding: CGFloat = 1

  // Scroll timing
  private let initialScrollDelay: Double = 0.05
  private let scrollSettleTime: Double = 0.15
  private let animationPause: Double = 0.6
  private let animationDuration: Double = 1.2
  private var animationSettleDelay: Double { animationDuration + 0.1 }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        ZStack(alignment: .topLeading) {
          // 1. Background Grid
          DayTimelineGrid(hourSpacing: Int(hourSpacing))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20) // Bottom buffer

          // 2. Events Layer
          GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let availableWidth = totalWidth - timeColumnWidth

            // Calculate Layout
            let layoutFrames = calculateLayout(
              events: viewModel.events,
              availableWidth: availableWidth
            )

            ForEach(viewModel.events) { event in
              if let frame = layoutFrames[event.id] {
                DayEventCard(event: event)
                  .frame(width: frame.width, height: frame.height)
                  .position(
                    x: timeColumnWidth + frame.x + frame.width / 2 ,
                    y: frame.y + frame.height / 2
                  )
                  .zIndex(frame.zIndex)
              }
            }
          }
          // The height of GeometryReader content needs to match the grid
          .frame(height: (25 * ViewConstants.timelineDividerHeight) + (24 * hourSpacing))

          // 3. Current Time Indicator
          if Calendar.current.isDateInToday(date) {
            TimelineView(.everyMinute) { context in
              CurrentTimeIndicator(date: context.date, hourSpacing: hourSpacing, dividerHeight: ViewConstants.timelineDividerHeight, height: $currentTimeViewHeight)
            }
            .zIndex(1000) // Ensure on top of everything
          }
        }
        .background(
          GeometryReader { geo in
            Color.clear.preference(key: ScrollOffsetKey.self,
              value: -geo.frame(in: .named("timelineScroll")).origin.y)
          }
        )
      }
      .coordinateSpace(name: "timelineScroll")
      .scrollPosition(id: $scrolledID, anchor: .top)
      .onPreferenceChange(ScrollOffsetKey.self) { offset in
        guard isScrollReady else { return }
        let hour = Int(offset / (hourSpacing + ViewConstants.timelineDividerHeight))
        lastScrollHour = max(0, min(23, hour))
      }
      .onAppear {
        guard appVM.selectedDate == date, !hasPerformedInitialScroll else { return }
        performInitialScroll(proxy: proxy)
      }
      .onChange(of: appVM.selectedDate) { _, newDate in
        guard newDate == date, !hasPerformedInitialScroll else { return }
        performInitialScroll(proxy: proxy)
      }
    }
    .task(id: date) {
      await viewModel.fetchEvents(for: date)
    }
  }

  private func performInitialScroll(proxy: ScrollViewProxy) {
    hasPerformedInitialScroll = true
    isScrollReady = false
    let scrollTarget = lastScrollHour

    // Use scrollPosition binding for immediate jump (reliable for buffer views)
    scrolledID = "hour-\(scrollTarget)"

    if Calendar.current.isDateInToday(date) {
      let currentHour = max(0, Calendar.current.component(.hour, from: Date()) - 1)
      DispatchQueue.main.asyncAfter(deadline: .now() + animationPause) {
        // Use ScrollViewReader proxy for animated scroll (reliable for active view)
        withAnimation(.easeInOut(duration: animationDuration)) {
          proxy.scrollTo("hour-\(currentHour)", anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animationSettleDelay) {
          lastScrollHour = currentHour
          isScrollReady = true
        }
      }
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + scrollSettleTime) {
        isScrollReady = true
      }
    }
  }

  // MARK: - Layout Logic

  struct LayoutFrame {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let zIndex: Double
  }

  private func calculateLayout(events: [Event], availableWidth: CGFloat) -> [String: LayoutFrame] {
    var frames: [String: LayoutFrame] = [:]
    let groupingThreshold: TimeInterval = 30 * 60 // Allow grouping of events within 30 mins to handle text overlap

    // 1. Sort events
    let sortedEvents = events.sorted {
       if $0.startTime != $1.startTime {
         return $0.startTime < $1.startTime
       }
       // secondary sort by duration descending (longer events first)
       return ($0.endTime.timeIntervalSince($0.startTime)) > ($1.endTime.timeIntervalSince($1.startTime))
    }

    // 2. Group overlapping events
    var groups: [[Event]] = []
    var currentGroup: [Event] = []
    var groupEnd: Date = .distantPast

    for event in sortedEvents {
      let visualEnd = max(event.endTime, event.startTime.addingTimeInterval(minVisualDuration))

      if currentGroup.isEmpty {
        currentGroup.append(event)
        groupEnd = visualEnd
      } else {
        // Check overlap with the *group's* range
        // Note: A simple check against groupEnd works for contiguous groups
        if event.startTime < groupEnd.addingTimeInterval(groupingThreshold) {
          currentGroup.append(event)
          if visualEnd > groupEnd {
            groupEnd = visualEnd
          }
        } else {
          groups.append(currentGroup)
          currentGroup = [event]
          groupEnd = visualEnd
        }
      }
    }
    if !currentGroup.isEmpty {
      groups.append(currentGroup)
    }

    // 3. Process each group
    for group in groups {
      processGroup(group, availableWidth: availableWidth, into: &frames)
    }

    return frames
  }

  private func processGroup(_ group: [Event], availableWidth: CGFloat, into frames: inout [String: LayoutFrame]) {
    var eventDepths: [String: Int] = [:]
    let headerClearance: TimeInterval = 10 * 60 // 10 mins clearance for title
    let stackThreshold: TimeInterval = 30 * 60 // Minimum time overlap for side-by-side

    for event in group {
      var depth = 0
      for other in group {
        if event.id == other.id { continue }
        let e1 = other
        let e2 = event

        // Strict containment with Header Clearance:
        if e1.startTime.addingTimeInterval(headerClearance) <= e2.startTime && e1.endTime >= e2.endTime {
          depth += 1
        }
      }
      eventDepths[event.id] = depth
    }

    let maxDepth = eventDepths.values.max() ?? 0

    for depth in 0...maxDepth {
      let eventsInLayer = group.filter { (eventDepths[$0.id] ?? 0) == depth }
      if eventsInLayer.isEmpty { continue }

      var columns: [[Event]] = []
      for event in eventsInLayer {
        var placed = false
        for (colIndex, column) in columns.enumerated() {
          if let lastEvent = column.last {
            let lastVisualEnd = max(lastEvent.endTime, lastEvent.startTime.addingTimeInterval(minVisualDuration))

            // Placement Condition:
            // 1. Must fit vertically (no overlap with visual end of last event).
            // 2. Must start significantly later than the last event's START (to prevent "staircasing" of very short events).
            //    If event starts within `stackThreshold` of lastEvent's start, force new column.
            if event.startTime >= lastVisualEnd && event.startTime >= lastEvent.startTime.addingTimeInterval(stackThreshold) {
              columns[colIndex].append(event)
              placed = true
              break
            }
          }
        }
        if !placed {
          columns.append([event])
        }
      }

      let numColumns = CGFloat(columns.count)
      let indent = CGFloat(depth) * 10.0
      let layerAvailableWidth = availableWidth - indent
      let columnWidth = layerAvailableWidth / numColumns

      for (colIndex, column) in columns.enumerated() {
        for event in column {
          let y = yPosition(for: event.startTime)

          let rawDuration = event.endTime.timeIntervalSince(event.startTime)
          let visualDuration = max(rawDuration, minVisualDuration)
          let height = (CGFloat(visualDuration / 3600.0) * hourSpacing) - eventVerticalPadding

          let width = columnWidth - 2
          let x = indent + CGFloat(colIndex) * columnWidth

          frames[event.id] = LayoutFrame(x: x, y: y, width: width, height: height, zIndex: Double(depth))
        }
      }
    }
  }

  private func yPosition(for date: Date) -> CGFloat {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    return (CGFloat(hour) * (hourSpacing + ViewConstants.timelineDividerHeight)) + ViewConstants.timelineDividerHeight + (CGFloat(minute) / 60.0 * hourSpacing)
  }
}

// MARK: - Subviews

struct DayEventCard: View {
  let event: Event
  @Environment(AppViewModel.self) private var appVM
  @State private var isHovering = false

  var body: some View {
    GeometryReader { geometry in
      let height = geometry.size.height
      let isSmall = height < 20

      ZStack(alignment: .topLeading) {
        // Background
        RoundedRectangle(cornerRadius: 4)
          .fill(event.calendarColor.opacity(isHovering ? 0.3 : 0.2))

        HStack(alignment: .top, spacing: 0) {
          RoundedRectangle(cornerRadius: 8)
            .fill(event.calendarColor)
            .frame(width: 3)
            .padding(.horizontal, 3)
            .padding(.vertical, 4)

          VStack(alignment: .leading, spacing: 0) {
            Text(event.title)
              .font(.system(size: isSmall ? 10 : 11, weight: .medium))
              .lineLimit(1)
              .foregroundColor(.primary)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.trailing, event.isRecurring ? 12 : 0) // Space for repeat icon

            if !isSmall && height > 34 {
              Spacer().frame(height: 1)
              if let _ = event.videoCallLink {
                HStack(spacing: 3) {
                  Image(systemName: "video.fill")
                  Text(event.meetingProvider)
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
              } else if let location = event.location, !location.isEmpty {
                HStack(spacing: 3) {
                  Image(systemName: "mappin.circle.fill")
                  Text(location)
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
              } else if height > 45 {
                 Text(formatTimeRange(start: event.startTime, end: event.endTime))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
              }
            }
          }
          .padding(.vertical, isSmall ? 1 : 3)
          .padding(.trailing, 2)
        }
        .padding(.leading, 1)

        if event.isRecurring {
          Image(systemName: "repeat")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.secondary)
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 0))
      .contentShape(Rectangle())
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.1)) {
          isHovering = hovering
        }
      }
      .onTapGesture {
        appVM.selectedEvent = event
      }
    }
  }

  private func formatTimeRange(start: Date, end: Date) -> String {
    let df = DateFormatter()
    df.dateFormat = "h:mm"
    return "\(df.string(from: start)) - \(df.string(from: end))"
  }
}

struct CurrentTimeIndicator: View {
  let date: Date
  let hourSpacing: CGFloat
  let dividerHeight: CGFloat
  @Binding var height: CGFloat

  var body: some View {
    CurrentTimeView(time: formatter.string(from: date)) { h in
      height = h
    }
    .offset(y: offset)
  }

  private var offset: CGFloat {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    return (CGFloat(hour) * (hourSpacing + dividerHeight)) + dividerHeight + (CGFloat(minute) / 60.0 * hourSpacing) - height / 2
  }

  private var formatter: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "h:mm"
    return df
  }
}

struct PagedDayTimelineView: View {
  @Environment(AppViewModel.self) private var appVM

  @State private var dates: [Date] = []
  @State private var scrollPosition: Date?
  @State private var lastScrollHour: Int = 8

  private let calendar = Calendar.current
  private let loadBatchSize = 15

  var body: some View {
    ScrollView(.horizontal) {
      LazyHStack(spacing: 0) {
        ForEach(dates, id: \.self) { date in
          DayTimelineView(date: date, lastScrollHour: $lastScrollHour)
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
        scrollPosition = appVM.selectedDate
      }
    }
    .onChange(of: scrollPosition) { _, newDate in
      guard let date = newDate else { return }

      if appVM.selectedDate != date {
        appVM.selectDate(date, source: .dayScroll)
      }

      if let index = dates.firstIndex(of: date) {
        if index < 5 {
          prependDays(count: 10, before: dates.first!)
        } else if index > dates.count - 5 {
          appendDays(count: 10, after: dates.last!)
        }
      }
    }
    .onChange(of: appVM.selectedDate) { _, newDate in
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

#Preview {
  DayTimelineView(date: Date(), lastScrollHour: .constant(8))
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth, height: ViewConstants.appHeight)
}
