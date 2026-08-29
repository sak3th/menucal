//
//  DayTimelineView.swift
//  MenuCal
//
//  Created by Gemini on 07/01/26.
//

import SwiftUI

// A time span that can flow through the column-packing primitives. Real events
// and synthetic title-strip blockers (Layers mode) both conform.
private protocol Interval {
  var intervalID: String { get }
  var intervalStart: Date { get }
  var intervalEnd: Date { get }
  // Blockers sort ahead of same-start events so they claim the leftmost column.
  var sortsFirstOnTie: Bool { get }
  // Start used to break ties between intervals that begin at the same point on
  // this grid — for a continuation, the time it really began.
  var orderingStart: Date { get }
}

extension Interval {
  var orderingStart: Date { intervalStart }
}

extension Event: Interval {
  var intervalID: String { id }
  var intervalStart: Date { startTime }
  var intervalEnd: Date { endTime }
  var sortsFirstOnTie: Bool { false }
  var orderingStart: Date { untrimmedStart ?? startTime }
}

// A non-drawn placeholder that reserves a background's title row in the
// foreground column layout so overlapping events can't cover the title.
private struct Blocker: Interval {
  let intervalID: String
  let intervalStart: Date
  let intervalEnd: Date
  var sortsFirstOnTie: Bool { true }
}

struct DayTimelineContent: View {
  let date: Date
  @Environment(AppViewModel.self) private var appVM
  @Environment(EventsViewModel.self) private var eventsVM
  @Environment(SettingsViewModel.self) private var settings
  @State private var viewModel = DayEventsViewModel()
  @State private var currentTimeViewHeight: CGFloat = 0

  // Layout Constants
  private let hourSpacing: CGFloat = 60
  private let timeColumnWidth = ViewConstants.timelineTimeColumnWidth // Space for hour labels
  private let minVisualDuration: TimeInterval = 10 * 60 // 10 minutes minimum visual duration
  private let eventVerticalPadding: CGFloat = 1
  // A contained event must start at least this far below its container so the
  // container's title stays visible; closer starts fall back to columns.
  private let titleClearance: TimeInterval = 18 * 60
  // Only hosts at least this long render as a faded background band; shorter
  // hosts (a normal meeting that happens to host an overlap) keep normal styling.
  private let backgroundMinDuration: TimeInterval = 3 * 3600

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

        // Lay out the day's *slices* of the events, not the events themselves:
        // an overnight event reaching into this day is just its own midnight-to-
        // end segment here, so overlap, containment, title clearance and
        // position all agree with what's drawn. Cards still show real times.
        let slices = dayEvents

        // Calculate Layout — nested (containment forest), layers (background +
        // foreground), or plain columns per setting.
        let layoutFrames: [String: LayoutFrame] = {
          switch settings.timelineLayout {
          case .nested:  return layoutNested(events: slices, availableWidth: availableWidth)
          case .layers:  return layoutLayers(events: slices, availableWidth: availableWidth)
          case .columns: return calculateLayout(events: slices, availableWidth: availableWidth)
          }
        }()

        ForEach(viewModel.events) { event in
          if let frame = layoutFrames[event.id] {
            DayEventCard(event: event, isBackground: frame.isBackground)
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
    var isBackground: Bool = false
  }

  // Standard calendar interval-partitioning layout:
  // events are clustered into connected overlap groups; within a cluster each
  // event takes the leftmost free column and all columns share the width equally.
  private func calculateLayout(events: [Event], availableWidth: CGFloat) -> [String: LayoutFrame] {
    var frames: [String: LayoutFrame] = [:]

    func visualEnd(_ event: Event) -> Date {
      max(event.endTime, event.startTime.addingTimeInterval(minVisualDuration))
    }

    // 1. Sort events — same ordering the other layouts use.
    let sortedEvents = events.sorted { intervalOrder($0, $1) }

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

    // 3. Within each cluster, assign columns and expand-to-fill (shared helper).
    for cluster in clusters {
      let (packed, colCount) = packColumns(cluster)
      let columnWidth = availableWidth / CGFloat(colCount)

      for event in cluster {
        let (c, span) = packed[event.id] ?? (0, 1)

        let y = yPosition(for: event.startTime)
        let height = heightFor(event)

        let x = CGFloat(c) * columnWidth
        let width = columnWidth * CGFloat(span) - 2

        frames[event.id] = LayoutFrame(x: x, y: y, width: width, height: height, zIndex: 0)
      }
    }

    return frames
  }

  // MARK: - Nested (containment-forest) layout

  // Google/Apple-style layout: an event that *contains* others (with title
  // clearance) is drawn full-width behind them; the contained events render on
  // top; events that only partially overlap go side-by-side in columns.
  private func layoutNested(events: [Event], availableWidth: CGFloat) -> [String: LayoutFrame] {
    var frames: [String: LayoutFrame] = [:]
    for clusterAny in overlapClusters(events) {
      let cluster = clusterAny.compactMap { $0 as? Event }
      // Build a containment forest: each event's parent is its tightest host
      // among *all* events in the cluster (hosting isn't transitive, so this
      // must consider every event, not just the roots).
      var childrenOf: [String: [Event]] = [:]
      var hasParent: Set<String> = []
      for e in cluster {
        if let parent = tightestHost(of: e, among: cluster) {
          childrenOf[parent.id, default: []].append(e)
          hasParent.insert(e.id)
        }
      }
      let roots = cluster.filter { !hasParent.contains($0.id) }
      layoutSiblings(roots, childrenOf: childrenOf,
                     regionX: 0, regionWidth: availableWidth, depth: 0, into: &frames)
    }
    return frames
  }

  // Lay out a set of siblings (children of one node, or the roots) within a
  // region, then recurse into each node's own children.
  private func layoutSiblings(
    _ siblings: [Event], childrenOf: [String: [Event]],
    regionX: CGFloat, regionWidth: CGFloat, depth: Int,
    into frames: inout [String: LayoutFrame]
  ) {
    guard !siblings.isEmpty else { return }
    let inset: CGFloat = 6

    // Non-overlapping siblings each keep full width; overlapping ones share
    // columns and expand-to-fill.
    for clusterAny in overlapClusters(siblings) {
      let cluster = clusterAny.compactMap { $0 as? Event }
      let (packed, colCount) = packColumns(cluster)
      let colWidth = regionWidth / CGFloat(max(colCount, 1))
      for node in cluster {
        let (ci, span) = packed[node.id] ?? (0, 1)
        let rx = regionX + CGFloat(ci) * colWidth
        let rw = colWidth * CGFloat(span)
        let kids = childrenOf[node.id] ?? []
        let isBackground = !kids.isEmpty
          && node.endTime.timeIntervalSince(node.startTime) >= backgroundMinDuration
        frames[node.id] = LayoutFrame(
          x: rx, y: yPosition(for: node.startTime),
          width: rw - 2, height: heightFor(node),
          zIndex: Double(depth), isBackground: isBackground
        )
        if !kids.isEmpty {
          layoutSiblings(kids, childrenOf: childrenOf,
                         regionX: rx + inset, regionWidth: rw - inset,
                         depth: depth + 1, into: &frames)
        }
      }
    }
  }

  // MARK: - Layers (background + foreground) layout

  // Two-layer Google/Apple-style layout: pure-envelope hosts become faded
  // full-width background bands behind everything (z=0); every other event is
  // laid out flat across the full width on top (z=1). Each background
  // contributes a title-strip blocker to the foreground column layout so
  // overlapping events (e.g. a same-start sibling) can't cover the host's
  // title. Multi-level nesting (background-within-background) is out of scope.
  private func layoutLayers(events: [Event], availableWidth: CGFloat) -> [String: LayoutFrame] {
    var frames: [String: LayoutFrame] = [:]

    // 1. Backgrounds: an event that hosts ≥1 title-cleared event AND is a *pure
    //    envelope* — every event overlapping it is fully contained within it, so
    //    nothing pokes out as a side-by-side peer. This (not duration) is what
    //    separates an all-day OOO backdrop from an ordinary long meeting that
    //    merely overlaps its neighbours: the latter has a peer sticking out and
    //    belongs in side-by-side columns instead.
    let backgrounds = events.filter { bg in
      let hostsAChild = events.contains { $0.id != bg.id && hosts(bg, $0) }
      let isPureEnvelope = events.allSatisfy { other in
        other.id == bg.id || !overlaps(bg, other) || contains(bg, other)
      }
      return hostsAChild && isPureEnvelope
    }
    let backgroundIDs = Set(backgrounds.map(\.id))

    // 2. Draw each background full-width, faded, behind (z=0).
    for bg in backgrounds {
      frames[bg.id] = LayoutFrame(
        x: 0, y: yPosition(for: bg.startTime),
        width: availableWidth - 2, height: heightFor(bg),
        zIndex: 0, isBackground: true
      )
    }

    // 3. Foreground = non-background events + one title-strip blocker per bg.
    var foreground: [any Interval] = events.filter { !backgroundIDs.contains($0.id) }
    for bg in backgrounds {
      foreground.append(Blocker(
        intervalID: "blocker-\(bg.id)",
        intervalStart: bg.startTime,
        intervalEnd: bg.startTime.addingTimeInterval(titleClearance)
      ))
    }

    // 4. Flat packColumns + expand-to-fill across the full width, on top (z=1);
    //    blockers reserve column space but are never drawn. Events that sit on
    //    top of a background are nudged right by `foregroundInset` (right edge
    //    preserved) so the background's left color strip stays visible and the
    //    foreground/background strips don't overlap.
    let foregroundInset: CGFloat = 8
    for cluster in overlapClusters(foreground) {
      let (packed, colCount) = packColumns(cluster)
      let colWidth = availableWidth / CGFloat(max(colCount, 1))
      for item in cluster where !(item is Blocker) {
        let (c, span) = packed[item.intervalID] ?? (0, 1)
        var x = CGFloat(c) * colWidth
        var width = colWidth * CGFloat(span) - 2
        if let ev = item as? Event, backgrounds.contains(where: { overlaps($0, ev) }) {
          x += foregroundInset
          width -= foregroundInset
        }
        frames[item.intervalID] = LayoutFrame(
          x: x,
          y: yPosition(for: item.intervalStart),
          width: width,
          height: heightFor(start: item.intervalStart, end: item.intervalEnd),
          zIndex: 1
        )
      }
    }

    return frames
  }

  // X starts within B's span, below B's title — so X nests on top of B (even
  // if X ends after B). Starts too close to B's start → not hosted → column.
  private func hosts(_ b: Event, _ x: Event) -> Bool {
    b.startTime.addingTimeInterval(titleClearance) <= x.startTime && x.startTime < b.endTime
  }

  // Time-overlap and full-containment predicates (used by Layers classification).
  private func overlaps(_ a: Event, _ b: Event) -> Bool {
    a.startTime < b.endTime && b.startTime < a.endTime
  }

  private func contains(_ outer: Event, _ inner: Event) -> Bool {
    outer.startTime <= inner.startTime && inner.endTime <= outer.endTime
  }

  private func tightestHost(of x: Event, among candidates: [Event]) -> Event? {
    var best: Event?
    for c in candidates where c.id != x.id && hosts(c, x) {
      if let b = best {
        // Tightest = latest start, then earliest end.
        if c.startTime > b.startTime || (c.startTime == b.startTime && c.endTime < b.endTime) {
          best = c
        }
      } else {
        best = c
      }
    }
    return best
  }

  // Greedy leftmost-free-column packing + expand-to-fill: returns each item's
  // column index and how many columns it spans (widening into consecutive
  // right-hand columns that are free for its whole span), plus the total count.
  private func packColumns(_ items: [any Interval]) -> (layout: [String: (col: Int, span: Int)], count: Int) {
    let sorted = items.sorted(by: intervalOrder)
    var columns: [[any Interval]] = []
    var colOf: [String: Int] = [:]
    for e in sorted {
      var placed = false
      for i in columns.indices {
        if let last = columns[i].last, visualEnd(last) <= e.intervalStart {
          columns[i].append(e); colOf[e.intervalID] = i; placed = true; break
        }
      }
      if !placed { columns.append([e]); colOf[e.intervalID] = columns.count - 1 }
    }

    var layout: [String: (col: Int, span: Int)] = [:]
    for e in sorted {
      let c = colOf[e.intervalID] ?? 0
      var span = 1
      var k = c + 1
      while k < columns.count {
        let occupied = columns[k].contains { other in
          other.intervalStart < visualEnd(e) && e.intervalStart < visualEnd(other)
        }
        if occupied { break }
        span += 1
        k += 1
      }
      layout[e.intervalID] = (c, span)
    }
    return (layout, columns.count)
  }

  // Connected clusters of time-overlapping items (shared by all layouts).
  private func overlapClusters(_ items: [any Interval]) -> [[any Interval]] {
    let sorted = items.sorted(by: intervalOrder)
    var clusters: [[any Interval]] = []
    var current: [any Interval] = []
    var clusterEnd: Date = .distantPast
    for e in sorted {
      if current.isEmpty || e.intervalStart < clusterEnd {
        current.append(e)
        clusterEnd = max(clusterEnd, visualEnd(e))
      } else {
        clusters.append(current)
        current = [e]
        clusterEnd = visualEnd(e)
      }
    }
    if !current.isEmpty { clusters.append(current) }
    return clusters
  }

  // Shared ordering: start ascending → blockers first on a tie (so they claim
  // the leftmost column) → older first among things that start together (an
  // event continuing from yesterday began before one that starts at midnight)
  // → then duration descending.
  private func intervalOrder(_ a: any Interval, _ b: any Interval) -> Bool {
    if a.intervalStart != b.intervalStart { return a.intervalStart < b.intervalStart }
    if a.sortsFirstOnTie != b.sortsFirstOnTie { return a.sortsFirstOnTie }
    if a.orderingStart != b.orderingStart { return a.orderingStart < b.orderingStart }
    return a.intervalEnd.timeIntervalSince(a.intervalStart)
      > b.intervalEnd.timeIntervalSince(b.intervalStart)
  }

  private func visualEnd(_ e: any Interval) -> Date {
    max(e.intervalEnd, e.intervalStart.addingTimeInterval(minVisualDuration))
  }

  private func heightFor(_ e: Event) -> CGFloat {
    heightFor(start: e.startTime, end: e.endTime)
  }

  private func heightFor(start: Date, end: Date) -> CGFloat {
    let visualDuration = max(
      clampedToDay(end).timeIntervalSince(clampedToDay(start)),
      minVisualDuration
    )
    return (CGFloat(visualDuration / 3600.0) * hourSpacing) - eventVerticalPadding
  }

  // Events trimmed to this day. Anything wholly outside it is dropped (an
  // event ending exactly at midnight belongs to the previous day, not this one).
  private var dayEvents: [Event] {
    viewModel.events
      .filter { $0.endTime > dayStart && $0.startTime < dayEnd }
      .map { $0.clampedToDay(from: dayStart, to: dayEnd) }
  }

  // The grid only covers this one day, so an event spilling in from the day
  // before (or out into the next) is drawn against the day's own edges. Its
  // card still reports its real start and end.
  private var dayStart: Date { Calendar.current.startOfDay(for: date) }

  private var dayEnd: Date {
    Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
      ?? dayStart.addingTimeInterval(24 * 3600)
  }

  private func clampedToDay(_ date: Date) -> Date {
    min(max(date, dayStart), dayEnd)
  }

  private func yPosition(for date: Date) -> CGFloat {
    let dividerHeight = ViewConstants.timelineDividerHeight
    let clamped = clampedToDay(date)
    // Midnight-to-midnight, so the last instant belongs to the closing divider
    // rather than wrapping back to hour 0.
    guard clamped < dayEnd else {
      return (24 * (hourSpacing + dividerHeight)) + dividerHeight
    }
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: clamped)
    let minute = calendar.component(.minute, from: clamped)
    return (CGFloat(hour) * (hourSpacing + dividerHeight)) + dividerHeight + (CGFloat(minute) / 60.0 * hourSpacing)
  }
}

// MARK: - Subviews

struct DayEventCard: View {
  let event: Event
  var isBackground: Bool = false
  @Environment(AppViewModel.self) private var appVM
  @Environment(SettingsViewModel.self) private var settings
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
        } else if isBackground {
          // Faded band that sits behind the events overlaid on top of it.
          RoundedRectangle(cornerRadius: 4)
            .fill(event.calendarColor.opacity(isHovering ? 0.16 : 0.1))
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
                Button(action: { joinCall(url) }) {
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

  private func joinCall(_ url: URL) {
    openURL(url)
    if settings.dismissAfterJoin {
      appVM.goHome()
      appVM.dismissPopover()
    }
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

  // All-day events are rendered by the pinned `AllDayBand` above the day
  // view, shared with the events list — the timeline only draws timed events.
  var body: some View {
    pagedTimeline
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
      .onChange(of: appVM.daySyncTick) {
        // Day rolled over while the popover was hidden. The scrollPosition
        // binding may already equal the target while the visible page is
        // stale (the midnight scroll ran offscreen), so don't trust it —
        // rebuild the date window and reposition on the fresh content.
        let target = appVM.selectedDate
        dates = generateDays(around: target)
        scrollPosition = target
        proxy.scrollTo("hour-\(scrollHour(for: target))", anchor: .top)
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
