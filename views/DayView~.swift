import Foundation
import SwiftUI

// MARK: - Revamped DayView
//
// Requirements implemented:
// 1. Hour timestamp: hour number prominent, AM/PM subdued.
// 2. Event start/end align tightly with hour dividers (end treated as exclusive).
// 3. Recurring indicator (⟳) when an event reflects recurrence metadata.
// 4. Different background style (diagonal stripe pattern) for not-accepted / tentative events.
// 5. Optional location line if vertical space allows.
// 6. Configurable hour height via AppStorage.
//
// Notes:
// - The existing Event model does not yet expose recurrence, status, or location.
//   We use reflection helpers so this view will gracefully adopt those when you extend Event:
//       var isRecurring: Bool
//       var status: String  (or EKEventStatus raw value)
//       var isAccepted: Bool
//       var location: String?
// - Extend Event later and these indicators will start working automatically.
// - Alignment: Uses device scale to snap offsets/heights to physical pixels.
// - End time exclusive: an event ending exactly at 9:00 appears above the 9:00 divider line.

struct DayView: View {
  @ObservedObject var viewModel: CalendarViewModel
  @State private var isAnimatingSlide: Bool = false

  // Configurable hour height (user preference).
  @AppStorage("hourHeight") private var storedHourHeight: Double = 76
  private var hourHeight: CGFloat { CGFloat(storedHourHeight) }

  // Debug overlay toggle (optional preference).
  @AppStorage("showEventDebug") private var showEventDebug: Bool = false

  // Use environment display scale for pixel snapping (works across platforms).
  @Environment(\.displayScale) private var displayScale: CGFloat

  private let totalHours = 24
  private let hourLabelWidth: CGFloat = 36
  private let timelineHorizontalPadding: CGFloat = 4
  private let columnSpacing: CGFloat = 4
  private let dividerThickness: CGFloat = 1
  private let timestampDividerSpacing: CGFloat = 2  // space between hour label and divider line
  @State private var currentTimePillHeight: CGFloat = 0
  // Removed autoScrolledDate gating to allow re-scroll whenever data changes.

  private struct PillHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
      value = nextValue()
    }
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollViewReader { proxy in
        ZStack(alignment: .topLeading) {
          VStack(alignment: .leading, spacing: 0) {
            //header
            allDaySection
            timeline(proxy: proxy)
          }
        }
        .transaction { t in
          if isAnimatingSlide { t.animation = nil }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .id(viewModel.selectedDate)
        .transition(transitionForDateChange())
        .onChange(of: viewModel.selectedDate) { oldDate, newDate in
          performDateChange(from: oldDate, to: newDate, proxy: proxy)
        }
      }
    }
    .clipped()
    .animation(.easeInOut(duration: 0.4), value: viewModel.selectedDate)
  }

  // MARK: Transition Animation
  private func transitionForDateChange() -> AnyTransition {
    guard let previousDate = viewModel.previousDate else {
      return .identity
    }

    // Determine slide direction based on date comparison
    if viewModel.selectedDate > previousDate {
      // Moving forward in time: new moves in from right, old moves out to left
      return .asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
      )
    } else {
      // Moving backward in time: new moves in from left, old moves out to right
      return .asymmetric(
        insertion: .move(edge: .leading),
        removal: .move(edge: .trailing)
      )
    }
  }

  private func performDateChange(from oldDate: Date, to newDate: Date, proxy: ScrollViewProxy) {
    // Set flag to prevent scroll during slide
    isAnimatingSlide = true

    // After slide animation completes (0.4s), perform scroll animation
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      isAnimatingSlide = false
      scrollToInitialPosition(proxy)
    }
  }

  // MARK: Header
  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(viewModel.selectedDate, formatter: Self.dateFormatter)
        .font(.system(size: 16, weight: .semibold))
      Text("Week \(Calendar.current.component(.weekOfYear, from: viewModel.selectedDate))")
        .font(.subheadline)
        .foregroundColor(.secondary)
      Spacer()
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
  }

  private var allDaySection: some View {
    let allDayEvents = viewModel.events.filter { $0.isAllDay }
    if allDayEvents.isEmpty {
      return AnyView(EmptyView())
    }
    // Align with hour label column: label width + spacing replicates timeline structure.
    return AnyView(
      HStack(alignment: .top, spacing: 2) {
        // Left: "all-day" label vertically aligned like hour labels
        Text("all-day")
          .font(.system(size: 10, weight: .regular))
          .foregroundColor(.primary)
          .frame(width: hourLabelWidth, alignment: .trailing)

        // Right: events stacked
        VStack(alignment: .leading, spacing: 4) {
          ForEach(allDayEvents) { e in
            HStack(spacing: 4) {
              Capsule()
                .fill(e.calendarColor)
                .frame(width: 1.6, height: 12)
              Text(e.title)
                .font(.system(size: 10))
                .lineLimit(1)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 4)
      .padding(.bottom, 4)
    )
  }

  // MARK: Timeline
  private func timeline(proxy: ScrollViewProxy) -> some View {
    ScrollView {
      VStack(spacing: 0) {
        Spacer().frame(height: 32)
        GeometryReader { geo in
          let contentWidth = max(
            0,
            geo.size.width - hourLabelWidth - 2
              * (timestampDividerSpacing + timelineHorizontalPadding)
          )

          ZStack(alignment: .topLeading) {
            hourAnchorsOverlay()  // invisible anchors for reliable scroll targets
            hourLinesOverlay(width: geo.size.width)
            eventsLayer(contentWidth: contentWidth)
            hourLabelsOverlay()
            currentTimeIndicatorOverlay(width: geo.size.width)
          }
          .frame(height: hourHeight * CGFloat(totalHours))
        }
        .frame(height: hourHeight * CGFloat(totalHours))
        Spacer().frame(height: 32)
      }
    }
    .scrollIndicators(.hidden)
    .onAppear {
      print(
        "[DayView] onAppear selectedDate=\(viewModel.selectedDate) events=\(viewModel.events.count)"
      )
      scrollToInitialPosition(proxy)
    }

    .onChange(of: viewModel.events.count) { newCount in
      print(
        "[DayView] onChange(events.count) newCount=\(newCount) selectedDate=\(viewModel.selectedDate)"
      )
      // Only scroll if not currently animating the slide
      if !isAnimatingSlide {
        scrollToInitialPosition(proxy)
      }
    }
  }

  // Centralized scroll logic: animated, positions current time near 1/3 of viewport when today,
  // otherwise first event (or 8AM fallback). Ensures single execution per selected date.
  private func scrollToInitialPosition(_ proxy: ScrollViewProxy) {
    print(
      "[DayView] scrollToInitialPosition invoked selectedDate=\(viewModel.selectedDate) events=\(viewModel.events.count)"
    )

    // Always attempt scroll (autoScrolledDate gating removed).

    let selectedDate = viewModel.selectedDate
    let today = Date()
    let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: today)

    // If not today and events still empty we'll just use fallback hour.
    if !isToday && viewModel.events.isEmpty {
      print("[DayView] non-today date with 0 events -> will use fallback hour")
    }

    let estimatedVisibleHours = 10  // Heuristic; could compute via geometry.
    print("[DayView] isToday=\(isToday) estimatedVisibleHours=\(estimatedVisibleHours)")

    if isToday {
      var cal = Calendar(identifier: .gregorian)
      cal.timeZone = TimeZone.current
      let currentHour = cal.component(.hour, from: today)
      let offset = estimatedVisibleHours / 3
      var targetTopHour = currentHour - offset
      let maxTopHour = max(0, 24 - estimatedVisibleHours)
      targetTopHour = min(max(targetTopHour, 0), maxTopHour)
      print(
        "[DayView] today currentHour=\(currentHour) offset=\(offset) targetTopHour=\(targetTopHour) maxTopHour=\(maxTopHour)"
      )

      DispatchQueue.main.async {
        let anchor: UnitPoint = currentHour >= 20 ? .bottom : .top
        let targetIdHour = currentHour >= 20 ? currentHour : targetTopHour
        // Slower animation for today scroll
        withAnimation(.easeInOut(duration: 5.0)) {
          print(
            "[DayView] performing animated scroll (today) to hour-\(targetIdHour) anchor=\(anchor) duration=5.0s"
          )
          proxy.scrollTo("hour-\(targetIdHour)", anchor: anchor)
        }
      }
    } else {
      let timed = viewModel.events
        .filter { !$0.isAllDay }
        .sorted { $0.startTime < $1.startTime }

      let fallbackHour = 8
      let targetTopHour: Int
      if let first = timed.first {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let firstHour = cal.component(.hour, from: first.startTime)
        // Remove contextual offset: scroll directly to the first event's hour
        targetTopHour = firstHour
        print(
          "[DayView] non-today firstEventHour(local)=\(firstHour) targetTopHour(no offset) = \(targetTopHour)"
        )
      } else {
        targetTopHour = fallbackHour
        print("[DayView] non-today no events -> fallbackHour=\(fallbackHour)")
      }

      DispatchQueue.main.async {
        // Slower animation for non-today scroll
        withAnimation(.easeInOut(duration: 5.0)) {
          print(
            "[DayView] performing animated scroll (non-today) to hour-\(targetTopHour) duration=5.0s"
          )
          proxy.scrollTo("hour-\(targetTopHour)", anchor: .top)
        }
      }
    }
  }

  // MARK: Hour Lines (Canvas)
  private func hourLinesOverlay(width: CGFloat) -> some View {
    Canvas { context, size in
      let scale = displayScale
      for h in 0...totalHours {
        let y = pixelSnap(CGFloat(h) * hourHeight, scale: scale)
        var path = Path()
        path.move(
          to: CGPoint(x: hourLabelWidth + timestampDividerSpacing, y: y)
        )
        path.addLine(
          to: CGPoint(
            x: size.width - (timestampDividerSpacing + timelineHorizontalPadding),
            y: y
          )
        )
        context.stroke(
          path,
          with: .color(Color.gray.opacity(0.18)),
          style: StrokeStyle(lineWidth: dividerThickness, lineCap: .square)
        )
      }
    }
    .allowsHitTesting(false)
  }

  // Invisible anchors at unsnapped (hour * hourHeight) positions; offset applied here is respected by ScrollViewReader.
  // Each anchor has its own id so scrollTo("hour-X") targets the correct vertical coordinate irrespective of label offsets.
  private func hourAnchorsOverlay() -> some View {
    // Use full-height blocks per hour for stable scroll anchor positioning.
    VStack(spacing: 0) {
      ForEach(0..<totalHours, id: \.self) { hour in
        Color.clear
          .frame(height: hourHeight)
          .id("hour-\(hour)")
      }
    }
    .allowsHitTesting(false)
  }

  // MARK: Hour Labels Overlay
  private func hourLabelsOverlay() -> some View {
    ZStack(alignment: .topLeading) {
      ForEach(0..<totalHours, id: \.self) { hour in
        let lineY = pixelSnap(CGFloat(hour) * hourHeight, scale: displayScale)
        let textHalfHeight: CGFloat = 7
        hourLabel(hour)
          .frame(width: hourLabelWidth, alignment: .trailing)
          .offset(x: 0, y: lineY - textHalfHeight)
        // (id removed; dedicated invisible anchors used instead for accurate scroll positioning)
      }
    }
    .allowsHitTesting(false)
  }

  // MARK: Current Time Indicator
  private func currentTimeIndicatorOverlay(width: CGFloat) -> some View {
    TimelineView(.everyMinute) { timeline in
      let now = timeline.date
      let isToday = Calendar.current.isDate(now, inSameDayAs: viewModel.selectedDate)

      let rawY = yOffset(for: now)
      let y = pixelSnap(rawY, scale: displayScale)

      let label = Self.timeLabelFormatter.string(from: now)

      let pillFontSize: CGFloat = 10
      let pillVerticalPadding: CGFloat = 2
      let pillHorizontalPadding: CGFloat = 6

      let pillLeftX = 3.0
      let lineStartX = hourLabelWidth + timestampDividerSpacing + timelineHorizontalPadding

      ZStack(alignment: .leading) {
        Rectangle()
          .fill(Color.red)
          .frame(height: 1)
          .opacity(isToday ? 1 : 0)
          .offset(x: lineStartX, y: y - currentTimePillHeight / 2)

        Text(label)
          .font(.system(size: pillFontSize, weight: .medium))
          .foregroundColor(.white.opacity(0.85))
          .padding(.horizontal, pillHorizontalPadding)
          .padding(.vertical, pillVerticalPadding)
          .background(
            Capsule().fill(Color.red)
              .background(
                GeometryReader { proxy in
                  Color.clear
                    .preference(key: PillHeightPreferenceKey.self, value: proxy.size.height)
                }
              )
          )
          .opacity(isToday ? 1 : 0)
          .offset(x: pillLeftX, y: y - currentTimePillHeight / 2)
      }
      .onPreferenceChange(PillHeightPreferenceKey.self) { h in
        currentTimePillHeight = pixelSnap(h, scale: displayScale)
      }
      .allowsHitTesting(false)
    }
    .allowsHitTesting(false)
  }

  private func hourLabel(_ hour: Int) -> some View {
    let date = Calendar.current.date(
      bySettingHour: hour, minute: 0, second: 0, of: viewModel.selectedDate)!
    let formatter = DateFormatter()
    formatter.dateFormat = "h"
    let hourString = formatter.string(from: date)
    let ampmFormatter = DateFormatter()
    ampmFormatter.dateFormat = "a"
    let ampm = ampmFormatter.string(from: date)

    return HStack(spacing: 2) {
      Text(hourString)
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(.primary)
      Text(ampm)
        .font(.system(size: 9, weight: .regular))
        .foregroundColor(.secondary)
    }
    .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
  }

  private func eventsLayer(contentWidth: CGFloat) -> some View {
    let timedEvents = viewModel.events.filter { !$0.isAllDay }
    let processed = layoutEvents(timedEvents, availableWidth: contentWidth)
    return ZStack(alignment: .topLeading) {
      ForEach(processed) { pe in
        EventChip(
          pEvent: pe,
          showDebug: showEventDebug,
          hourHeight: hourHeight,
          dividerThickness: dividerThickness
        )
        .frame(width: pe.width, height: pe.height, alignment: .topLeading)
        .offset(
          x: pe.xOffset + hourLabelWidth + timestampDividerSpacing,
          y: pe.yOffset
        )
      }
    }
  }
}

private struct ProcessedEvent: Identifiable {
  let id: String
  let event: Event
  let yOffset: CGFloat
  let height: CGFloat
  let xOffset: CGFloat
  let width: CGFloat
}

extension DayView {
  private func layoutEvents(_ events: [Event], availableWidth: CGFloat) -> [ProcessedEvent] {
    let sorted = events.sorted { $0.startTime < $1.startTime }

    var groups: [[Event]] = []
    for e in sorted {
      var placed = false
      for i in 0..<groups.count {
        if e.startTime < groups[i].last!.endTime {
          groups[i].append(e)
          groups[i].sort { $0.endTime < $1.endTime }
          placed = true
          break
        }
      }
      if !placed {
        groups.append([e])
      }
    }

    var result: [ProcessedEvent] = []

    for group in groups {
      var columns: [Int: [Event]] = [:]
      for e in group {
        var c = 0
        while true {
          if columns[c, default: []].allSatisfy({ $0.endTime <= e.startTime }) {
            columns[c, default: []].append(e)
            break
          }
          c += 1
        }
      }

      let totalCols = max(1, columns.keys.count)
      let colWidth = (availableWidth - CGFloat(totalCols - 1) * columnSpacing) / CGFloat(totalCols)

      for (col, evts) in columns {
        for e in evts {
          let startY = yOffset(for: e.startTime)
          let endYExclusive = yOffset(for: e.endTime)

          // Snap start to pixel boundary for alignment with hour dividers
          let snappedStart = pixelSnap(startY, scale: displayScale)

          // Calculate height from snapped positions to maintain alignment
          let snappedEnd = pixelSnap(endYExclusive, scale: displayScale)
          let snappedHeight = snappedEnd - snappedStart

          result.append(
            ProcessedEvent(
              id: e.id,
              event: e,
              yOffset: snappedStart,
              height: snappedHeight,
              xOffset: CGFloat(col) * (colWidth + columnSpacing),
              width: colWidth
            )
          )
        }
      }
    }

    return result
  }

  private func yOffset(for date: Date) -> CGFloat {
    let calendar = Calendar.current
    let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
    let h = Double(comps.hour ?? 0)
    let m = Double(comps.minute ?? 0)
    let s = Double(comps.second ?? 0)
    let hoursSinceStart = h + (m / 60.0) + (s / 3600.0)
    let raw = CGFloat(hoursSinceStart) * hourHeight
    return raw
  }

  private func pixelSnap(_ value: CGFloat, scale: CGFloat? = nil) -> CGFloat {
    let scaleFactor = scale ?? displayScale
    return (value * scaleFactor).rounded(.towardZero) / scaleFactor
  }
}

private struct EventChip: View {
  let pEvent: ProcessedEvent
  let showDebug: Bool
  let hourHeight: CGFloat
  let dividerThickness: CGFloat

  @State private var isShowingDetails = false

  private let cornerRadius: CGFloat = 4
  private let colorBarWidth: CGFloat = 3
  private let horizontalPadding: CGFloat = 4
  private let verticalTopInset: CGFloat = 2.4
  private let eventNameFontSize: CGFloat = 12
  private let timeFontSize: CGFloat = 11
  private let locationFontSize: CGFloat = 11

  var body: some View {
    ZStack(alignment: .topLeading) {
      baseBackground
      content
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .overlay(alignment: .leading) {
      colorBar
    }
    .overlay(alignment: .topTrailing) {
      if pEvent.event.isRecurring {
        Image(systemName: "repeat")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.top, 2)
          .padding(.trailing, 2)
      }
    }
    .overlay(alignment: .topLeading) {
      if showDebug {
        Color.green.frame(height: 1)
      }
    }
    .overlay(alignment: .bottomLeading) {
      if showDebug {
        Color.red.frame(height: 1)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      isShowingDetails = true
    }
    .popover(isPresented: $isShowingDetails, arrowEdge: .trailing) {
      EventDetailsPopover(event: pEvent.event)
    }
  }

  private var baseBackground: some View {
    let accepted = pEvent.event.participationStatus == .accepted
    return Group {
      if accepted {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .fill(pEvent.event.calendarColor.opacity(0.18))
      } else {
        StripedBackground(
          color: pEvent.event.calendarColor.opacity(0.18),
          stripeColor: pEvent.event.calendarColor.opacity(0.19),
          cornerRadius: cornerRadius)
      }
    }
  }

  private var colorBar: some View {
    RoundedRectangle(cornerRadius: colorBarWidth / 2, style: .continuous)
      .fill(pEvent.event.calendarColor)
      .frame(width: colorBarWidth)
      .padding(.top, 4)
      .padding(.bottom, 4)
      .padding(.leading, horizontalPadding)
  }

  private var content: some View {
    let lineHeight: CGFloat = 13
    let available = pEvent.height - verticalTopInset
    let maxLines = Int(floor(available / lineHeight))

    return VStack(alignment: .leading, spacing: 0) {
      Text(pEvent.event.title)
        .font(.system(size: eventNameFontSize, weight: .regular))
        .lineLimit(1)

      if maxLines >= 2 {
        Text(timeRangeString(pEvent.event))
          .font(.system(size: timeFontSize, weight: .regular))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      if maxLines >= 3,
        let location = pEvent.event.location,
        !location.isEmpty
      {
        Text(location)
          .font(.system(size: locationFontSize))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.leading, horizontalPadding + colorBarWidth + 3)
    .padding(.top, verticalTopInset)
  }

  private func timeRangeString(_ event: Event) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm"
    let startStr = formatter.string(from: event.startTime)
    let endStr = formatter.string(from: event.endTime)

    let ampmFormatter = DateFormatter()
    ampmFormatter.dateFormat = "a"
    let startAMPM = ampmFormatter.string(from: event.startTime)
    let endAMPM = ampmFormatter.string(from: event.endTime)

    return "\(startStr)–\(endStr)\(startAMPM == endAMPM ? startAMPM : startAMPM + " " + endAMPM)"
  }
}

private struct StripedBackground: View {
  let color: Color
  let stripeColor: Color
  let cornerRadius: CGFloat

  var body: some View {
    GeometryReader { geo in
      let stripeWidth: CGFloat = 6
      let stripeSpacing: CGFloat = 6
      Canvas { context, size in
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
          Path(roundedRect: rect, cornerRadius: cornerRadius),
          with: .color(color)
        )
        var x: CGFloat = -size.height
        while x < size.width + size.height {
          var path = Path()
          path.move(to: CGPoint(x: x, y: 0))
          path.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
          path.addLine(to: CGPoint(x: x - size.height + stripeWidth, y: size.height))
          path.addLine(to: CGPoint(x: x - size.height, y: size.height))
          path.closeSubpath()
          context.fill(path, with: .color(stripeColor))
          x += stripeWidth + stripeSpacing
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
  }
}

// Custom slide modifier for horizontal transitions
struct SlideModifier: ViewModifier {
  let offset: CGFloat

  func body(content: Content) -> some View {
    content.offset(x: offset, y: 0)
  }
}

extension DayView {
  static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .full
    f.timeStyle = .none
    return f
  }()

  private static let timeLabelFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "H:mm"
    return f
  }()
}
