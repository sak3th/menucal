//
//  AllDayBandView.swift
//  MenuCal
//

import SwiftUI

/// Pinned all-day strip shown above the day content in both the events list
/// and the timeline.
///
/// All-day events are unbounded in count — a shared work calendar can easily
/// contribute a dozen "X – On Leave" entries on one day, which would otherwise
/// push the day content off the bottom of the popover. The strip therefore
/// never grows past `ViewConstants.allDayMaxVisibleRows` rows; beyond that it
/// scrolls within itself and the day view keeps the rest.
struct AllDayBand: View {
  @Environment(AppViewModel.self) private var appVM
  @Environment(EventsViewModel.self) private var eventsVM
  @State private var viewModel = DayEventsViewModel()

  /// Whole rows only, so the strip always ends on a row boundary.
  private var stripHeight: CGFloat {
    let rows = min(viewModel.allDayEvents.count, ViewConstants.allDayMaxVisibleRows)
    return CGFloat(rows) * ViewConstants.allDayRowHeight
  }

  var body: some View {
    VStack(spacing: 0) {
      if !viewModel.allDayEvents.isEmpty {
        // The timeline draws its day as cards on a grid, so all-day events read
        // better there as chips indented to the same gutter. The events list is
        // a list, so they stay rows.
        if appVM.selectedEventsView == .timeline {
          AllDayChipStrip(events: viewModel.allDayEvents)
        } else {
          ScrollView {
            VStack(spacing: 0) {
              AllDayEventsList(events: viewModel.allDayEvents)
            }
          }
          .scrollIndicators(.automatic)
          .scrollBounceBehavior(.basedOnSize)
          .frame(height: stripHeight)
        }
      }

      // Always drawn, all-day events or not: it's the day view's top edge, and
      // the timeline's midnight line sits exactly here rather than drawing a
      // second one a few points below.
      Divider()
    }
    .task(id: appVM.selectedDate) {
      await fetch()
    }
    .onChange(of: eventsVM.hiddenCalendarIDs) {
      Task { await fetch() }
    }
    .onChange(of: eventsVM.refreshTick) {
      Task { await fetch() }
    }
  }

  private func fetch() async {
    await viewModel.fetchEvents(
      for: appVM.selectedDate,
      hiddenCalendarIDs: eventsVM.hiddenCalendarIDs
    )
  }
}

/// Timeline flavour of the strip: each all-day event is a capsule chip — the
/// calendar's colour as a tinted fill and as the badge behind its icon — sitting
/// in the same column as the event cards below it.
struct AllDayChipStrip: View {
  let events: [Event]

  private var visibleRows: Int {
    min(events.count, ViewConstants.allDayMaxVisibleRows)
  }

  /// Whole chips only, so the strip never ends mid-chip.
  private var stripHeight: CGFloat {
    CGFloat(visibleRows) * ViewConstants.allDayChipHeight
      + CGFloat(max(visibleRows - 1, 0)) * ViewConstants.allDayChipSpacing
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      Text("all-day")
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .opacity(0.6)
        .frame(
          width: ViewConstants.timelineTimeColumnWidth,
          height: ViewConstants.allDayChipHeight,
          alignment: .leading
        )

      ScrollView {
        VStack(spacing: ViewConstants.allDayChipSpacing) {
          ForEach(events) { event in
            AllDayChip(event: event)
          }
        }
      }
      .scrollIndicators(.automatic)
      .scrollBounceBehavior(.basedOnSize)
      .frame(height: stripHeight)
      // Matches the 2pt the timeline trims off its cards' right edge.
      .padding(.trailing, 2)
    }
    .padding(.vertical, 5)
  }
}

struct AllDayChip: View {
  let event: Event

  @Environment(AppViewModel.self) private var appVM
  @State private var isHovering = false

  private var isDeclined: Bool { event.participationStatus == .declined }

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "calendar")
        .font(.system(size: 8))
        .foregroundStyle(event.calendarColor.contrastingForegroundColor)
        .padding(3)
        .background(Circle().fill(event.calendarColor))

      Text(event.title)
        .font(.system(size: 11, weight: .medium))
        .lineLimit(1)
        .truncationMode(.tail)
        .strikethrough(isDeclined)
        .foregroundStyle(isDeclined ? .secondary : .primary)

      Spacer(minLength: 0)
    }
    .padding(.leading, 3)
    .padding(.trailing, 9)
    .frame(height: ViewConstants.allDayChipHeight)
    .background {
      // Unaccepted invites read as outlined rather than filled — the same
      // "not yours yet" distinction the grid makes with stripes, in the
      // lighter form a 20pt chip can carry.
      if event.isUnaccepted {
        Capsule()
          .fill(event.calendarColor.opacity(isHovering ? 0.12 : 0.06))
          .overlay(Capsule().strokeBorder(event.calendarColor.opacity(0.45), lineWidth: 1))
      } else {
        Capsule().fill(event.calendarColor.opacity(isHovering ? 0.3 : 0.2))
      }
    }
    .contentShape(Capsule())
    .onHover { isHovering = $0 }
    .onTapGesture { appVM.selectedEvent = event }
  }
}
