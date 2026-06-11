//
//  DayTimelineView.swift
//  MenuCal
//
//  Created by Gemini on 07/01/26.
//

import SwiftUI

struct DayTimelineContent: View {
  let date: Date
  @Environment(AppViewModel.self) private var appVM
  @Environment(EventsViewModel.self) private var eventsVM
  @State private var viewModel = DayEventsViewModel()
  @State private var currentTimeViewHeight: CGFloat = 0

  // Layout Constants
  private let hourSpacing: CGFloat = 60
  private let timeColumnWidth: CGFloat = 42 // Space for hour labels
  private let minVisualDuration: TimeInterval = 10 * 60 // 10 minutes minimum visual duration
  private let eventVerticalPadding: CGFloat = 1

  var body: some View {
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
    .task(id: date) {
      await viewModel.fetchEvents(for: date, hiddenCalendarIDs: eventsVM.hiddenCalendarIDs)
    }
    .onChange(of: eventsVM.hiddenCalendarIDs) {
      Task {
        await viewModel.fetchEvents(for: date, hiddenCalendarIDs: eventsVM.hiddenCalendarIDs)
      }
    }
    .onChange(of: eventsVM.refreshTick) {
      Task {
        await viewModel.fetchEvents(for: date, hiddenCalendarIDs: eventsVM.hiddenCalendarIDs)
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

  // Standard calendar interval-partitioning layout:
  // events are clustered into connected overlap groups; within a cluster each
  // event takes the leftmost free column and all columns share the width equally.
  private func calculateLayout(events: [Event], availableWidth: CGFloat) -> [String: LayoutFrame] {
    var frames: [String: LayoutFrame] = [:]

    func visualEnd(_ event: Event) -> Date {
      max(event.endTime, event.startTime.addingTimeInterval(minVisualDuration))
    }

    // 1. Sort events
    let sortedEvents = events.sorted {
       if $0.startTime != $1.startTime {
         return $0.startTime < $1.startTime
       }
       // secondary sort by duration descending (longer events first)
       return ($0.endTime.timeIntervalSince($0.startTime)) > ($1.endTime.timeIntervalSince($1.startTime))
    }

    // 2. Cluster events that visually overlap
    var clusters: [[Event]] = []
    var currentCluster: [Event] = []
    var clusterEnd: Date = .distantPast

    for event in sortedEvents {
      if currentCluster.isEmpty || event.startTime < clusterEnd {
        currentCluster.append(event)
        clusterEnd = max(clusterEnd, visualEnd(event))
      } else {
        clusters.append(currentCluster)
        currentCluster = [event]
        clusterEnd = visualEnd(event)
      }
    }
    if !currentCluster.isEmpty {
      clusters.append(currentCluster)
    }

    // 3. Within each cluster, assign each event the leftmost free column
    for cluster in clusters {
      var columns: [[Event]] = []
      var columnIndex: [String: Int] = [:]

      for event in cluster {
        var placed = false
        for (colIndex, column) in columns.enumerated() {
          if let last = column.last, visualEnd(last) <= event.startTime {
            columns[colIndex].append(event)
            columnIndex[event.id] = colIndex
            placed = true
            break
          }
        }
        if !placed {
          columns.append([event])
          columnIndex[event.id] = columns.count - 1
        }
      }

      let columnWidth = availableWidth / CGFloat(columns.count)

      for event in cluster {
        let y = yPosition(for: event.startTime)

        let rawDuration = event.endTime.timeIntervalSince(event.startTime)
        let visualDuration = max(rawDuration, minVisualDuration)
        let height = (CGFloat(visualDuration / 3600.0) * hourSpacing) - eventVerticalPadding

        let x = CGFloat(columnIndex[event.id] ?? 0) * columnWidth

        frames[event.id] = LayoutFrame(x: x, y: y, width: columnWidth - 2, height: height, zIndex: 0)
      }
    }

    return frames
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
  @State private var isHoveringOnVideoLink = false

  @Environment(\.openURL) private var openURL

  private var isDeclined: Bool { event.participationStatus == .declined }
  private var isUnaccepted: Bool { event.isUnaccepted }

  var body: some View {
    GeometryReader { geometry in
      let height = geometry.size.height
      let isSmall = height < 20

      ZStack(alignment: .topLeading) {
        // Background
        if isUnaccepted {
          SlantedStripes(color: event.calendarColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
          RoundedRectangle(cornerRadius: 4)
            .fill(event.calendarColor.opacity(isHovering ? 0.3 : 0.2))
        }

        HStack(alignment: .top, spacing: 0) {
          RoundedRectangle(cornerRadius: 8)
            .fill(event.calendarColor)
            .frame(width: 3)
            .padding(.horizontal, 3)
            .padding(.vertical, 4)

          VStack(alignment: .leading, spacing: 0) {
            Text(event.title)
              .font(.system(size: isSmall ? 10 : 11, weight: .medium))
              .strikethrough(isDeclined)
              .lineLimit(1)
              .foregroundColor(isDeclined ? .secondary : .primary)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.trailing, event.isRecurring ? 12 : 0) // Space for repeat icon

            if !isSmall && height > 34 {
              Spacer().frame(height: 1)
              if let url = event.videoCallLink {
                Link(destination: url) {
                  HStack(spacing: 3) {
                    Image(systemName: "video.fill")
                    Text(event.meetingProvider)
                      .strikethrough(isDeclined)
                  }
                }
                .buttonStyle(.plain)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
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
                Button(action: {
                  if let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                     let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                    openURL(url)
                  }
                }) {
                  HStack(spacing: 3) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(location)
                      .strikethrough(isDeclined)
                  }
                }
                .buttonStyle(.plain)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .onHover { inside in
                  if inside { NSCursor.pointingHand.push() }
                  else { NSCursor.pop() }
                }
              } else if height > 45 {
                 Text(formatTimeRange(start: event.startTime, end: event.endTime))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .strikethrough(isDeclined)
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
  @Environment(EventsViewModel.self) private var eventsVM
  @State private var allDayVM = DayEventsViewModel()

  @State private var dates: [Date] = []
  @State private var scrollPosition: Date?
  @State private var isInitialAppear = true
  @State private var scrollToNowTask: Task<Void, Never>?

  private let calendar = Calendar.current
  private let loadBatchSize = 15

  private let hourSpacing: CGFloat = 60
  private let defaultScrollHour = 8
  private var totalTimelineHeight: CGFloat {
    (25 * ViewConstants.timelineDividerHeight) + (24 * hourSpacing) + 20
  }

  private func scrollHour(for date: Date) -> Int {
    if calendar.isDateInToday(date) {
      let hour = calendar.component(.hour, from: Date())
      // Show 1 hour before current time so the indicator is visible, not at the very top
      return max(0, min(23, hour - 1))
    }
    return defaultScrollHour
  }

  var body: some View {
    VStack(spacing: 0) {
      if !allDayVM.allDayEvents.isEmpty {
        VStack(spacing: 0) {
          ForEach(allDayVM.allDayEvents) { event in
            DayEventView(event: event)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
          }
          Divider().opacity(0.5)
        }
      }
      pagedTimeline
    }
    .task(id: appVM.selectedDate) {
      await allDayVM.fetchEvents(for: appVM.selectedDate, hiddenCalendarIDs: eventsVM.hiddenCalendarIDs)
    }
    .onChange(of: eventsVM.hiddenCalendarIDs) {
      Task {
        await allDayVM.fetchEvents(for: appVM.selectedDate, hiddenCalendarIDs: eventsVM.hiddenCalendarIDs)
      }
    }
    .onChange(of: eventsVM.refreshTick) {
      Task {
        await allDayVM.fetchEvents(for: appVM.selectedDate, hiddenCalendarIDs: eventsVM.hiddenCalendarIDs)
      }
    }
  }

  private var pagedTimeline: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical) {
        ZStack(alignment: .topLeading) {
          // Invisible vertical anchors for ScrollViewReader
          VStack(spacing: 0) {
            ForEach(0..<25, id: \.self) { hour in
              Color.clear
                .frame(height: ViewConstants.timelineDividerHeight)
                .id("hour-\(hour)")
              if hour < 24 {
                Spacer().frame(height: hourSpacing)
              }
            }
          }

          // Horizontal paging content
          ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
              ForEach(dates, id: \.self) { date in
                DayTimelineContent(date: date)
                  .frame(width: ViewConstants.monthViewWidth)
                  .id(date)
              }
            }
            .scrollTargetLayout()
          }
          .scrollTargetBehavior(.paging)
          .scrollIndicators(.never)
          .scrollPosition(id: $scrollPosition)
          .frame(height: totalTimelineHeight)
        }
      }
      .scrollIndicators(.hidden)
      .onAppear {
        let targetDate = appVM.selectedDate
        dates = generateDays(around: targetDate)
        scrollPosition = targetDate
        // Immediate scroll on first appear — no animation needed
        proxy.scrollTo("hour-\(scrollHour(for: targetDate))", anchor: .top)
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(100))
          isInitialAppear = false
        }
      }
      .onChange(of: scrollPosition) { _, newDate in
        guard let date = newDate else { return }

        if appVM.selectedDate != date {
          appVM.selectDate(date, source: .dayScroll)
        }

        // Orchestrated scroll to current time when landing on today
        if !isInitialAppear && calendar.isDateInToday(date) {
          scrollToNowTask?.cancel()
          let delay: Duration = appVM.changeSource == .dayScroll ? .milliseconds(150) : .milliseconds(350)
          scrollToNowTask = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
              proxy.scrollTo("hour-\(scrollHour(for: date))", anchor: .top)
            }
          }
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
  }

  private func prependDays(count: Int, before date: Date) {
    var newItems: [Date] = []
    for i in 1...count {
      if let d = calendar.date(byAdding: .day, value: -i, to: date) {
        newItems.insert(calendar.startOfDay(for: d), at: 0)
      }
    }
    dates.insert(contentsOf: newItems, at: 0)
  }

  private func appendDays(count: Int, after date: Date) {
    var newItems: [Date] = []
    for i in 1...count {
      if let d = calendar.date(byAdding: .day, value: i, to: date) {
        newItems.append(calendar.startOfDay(for: d))
      }
    }
    dates.append(contentsOf: newItems)
  }

  private func generateDays(around date: Date) -> [Date] {
    let baseDate = calendar.startOfDay(for: date)
    var newDates: [Date] = []
    for offset in -loadBatchSize...loadBatchSize {
      if let d = calendar.date(byAdding: .day, value: offset, to: baseDate) {
        newDates.append(calendar.startOfDay(for: d))
      }
    }
    return newDates
  }
}

#Preview {
  DayTimelineContent(date: Date())
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth, height: ViewConstants.appHeight)
}
