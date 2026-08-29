//
//  ViewConstants.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 16/12/25.
//

import AppKit
import Foundation

struct ViewConstants {
  static let height: CGFloat = 280.0
  static let width: CGFloat = 280.0
  static let padding: CGFloat = 8.0
  //static let appWidth = width + (padding * 0) + 64.0

  // Total popover height scales with the screen the menu bar is on, so the
  // app doesn't dominate small displays nor stay cramped on large ones. The
  // month grid stays a fixed size; the extra/less room goes to the day view.
  //
  // Computed once and cached: it must return the SAME value for every read
  // (window frame and inner content frame), otherwise a mismatch leaves the
  // content centered in a taller window with empty material bands. Adapts to
  // the current display on next launch.
  static let appHeightFraction: CGFloat = 0.85
  static let minAppHeight: CGFloat = 600
  static let maxAppHeight: CGFloat = 1300

  static let appHeight: CGFloat = {
    // The menu bar lives on the primary screen (frame origin .zero), which is
    // where the popover appears.
    let menuBarScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
    let visibleHeight = menuBarScreen?.visibleFrame.height ?? 900
    return min(max(visibleHeight * appHeightFraction, minAppHeight), maxAppHeight)
  }()

  static let weekNumCellWidth = 22.0
  static let dayCellWidth = 32.0
  static let dayCellHeight = 36.0
  static let dayEventCapsuleMaxWidth = 16.0
  static let monthCellPadding = 4.0
  static let gridVerticalSpacing: CGFloat = 4.0
  static let weekdayRowHeight: CGFloat = 12.0

  static func monthGridHeight(weekCount: Int) -> CGFloat {
    weekdayRowHeight + CGFloat(weekCount) * dayCellHeight + CGFloat(weekCount) * gridVerticalSpacing
  }

  static var monthViewWidth: CGFloat {
    return weekNumCellWidth + monthCellPadding + (dayCellWidth * 7) + (monthCellPadding * 7)
  }

  static var appWidth: CGFloat {
    padding * 2 + monthViewWidth
  }

  static let weekViewHeight: CGFloat = weekdayRowHeight + dayCellHeight + gridVerticalSpacing

  static let timelineDividerHeight = 1.0

  // All-day events are unbounded in count, so the pinned all-day strip shows at
  // most this many rows and scrolls within itself past that — the rest of the
  // window always belongs to the timeline / events list. Rows are a fixed
  // height so the strip always ends flush with a row boundary; a fractional cut
  // would leave the next row's divider peeking above the strip's own.
  static let allDayRowHeight: CGFloat = 32
  static let allDayMaxVisibleRows = 4

  // Timeline mode shows all-day events as chips instead of list rows, indented
  // past the hour-label gutter so they line up with the event cards below.
  static let timelineTimeColumnWidth: CGFloat = 42
  static let allDayChipHeight: CGFloat = 20
  static let allDayChipSpacing: CGFloat = 3
}

