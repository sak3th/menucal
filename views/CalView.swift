//
//  AppView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 16/12/25.
//

import SwiftUI

struct CalView: View {
  @Environment(AppViewModel.self) private var appVM
  @FocusState private var isFocused: Bool

  var body: some View {
    ZStack(alignment: .topLeading) {
      Rectangle().fill(.background)
      VStack(alignment: .center, spacing: 0) {
        HStack {
          if appVM.selectedCalendarView == .month {
            PagedMonthView()
          } else {
            PagedWeekView()
          }
        }
        .frame(width: ViewConstants.monthViewWidth)

        // The all-day strip is pinned above whichever day view is active, so
        // both views treat all-day events identically and it survives the
        // toggle between them.
        VStack(spacing: 0) {
          AllDayBand()

          Group {
            if appVM.selectedEventsView == .timeline {
              PagedDayTimelineView().transition(.blurReplace)
            } else {
              EventsView().transition(.blurReplace)
            }
          }
          .animation(.smooth(duration: 0.3), value: appVM.selectedEventsView)
        }
        .frame(minHeight: appVM.appHeight * 0.3)
        .padding(.horizontal, ViewConstants.padding)
      }
      .padding(.top, ViewConstants.padding)
      .frame(width: ViewConstants.appWidth)

      // Dismiss overlay — catches taps outside menus
      if appVM.activeOverlay != .none {
        Color.clear
          .contentShape(Rectangle())
          .frame(width: ViewConstants.appWidth, height: appVM.appHeight)
          .onTapGesture {
            withAnimation(.toolbarOverlay) { appVM.dismissOverlays() }
          }
          .zIndex(2)
      }

      BottomToolbar()
        .padding(.bottom, 6)
        .frame(width: ViewConstants.appWidth, height: appVM.appHeight, alignment: .bottom)
        .zIndex(3)

      TopBar()
        .padding(.horizontal, 4)
        .offset(x: -4, y: 8)
        .zIndex(3)

      if let event = appVM.selectedEvent {
        ZStack(alignment: .topTrailing) {
          ScrollView {
            EventDetailView(event: event)
              .padding()
          }
          .scrollIndicators(.hidden)
          .background(.background)
          .onTapGesture {
            appVM.selectedEvent = nil
          }
        }
        .frame(width: ViewConstants.appWidth, height: appVM.appHeight)
        .transition(.opacity)
        .zIndex(100)
      }
    }
    .frame(width: ViewConstants.appWidth, height: appVM.appHeight)
    .frame(maxHeight: appVM.appHeight)
    .focusable()
    .focused($isFocused)
    // Focus is only here to receive key presses; the whole popover drawing an
    // accent ring around itself is not the point.
    .focusEffectDisabled()
    .onAppear {
      isFocused = true
    }
    .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
      if press.modifiers.contains(.option) {
        if press.key == .leftArrow {
          appVM.goToPrevMonth()
        } else if press.key == .rightArrow {
          appVM.goToNextMonth()
        }
      } else {
        if press.key == .leftArrow {
          appVM.goToPrevDate()
        } else if press.key == .rightArrow {
          appVM.goToNextDate()
        }
      }
      return .handled
    }
    .onKeyPress(keys: [",", "."]) { press in
      if press.characters == "," {
        appVM.goToPrevWeek()
      } else if press.characters == "." {
        appVM.goToNextWeek()
      }
      return .handled
    }
    .onKeyPress(keys: [.escape]) { _ in
      if appVM.activeOverlay != .none {
        withAnimation(.toolbarOverlay) { appVM.dismissOverlays() }
        return .handled
      }
      if appVM.selectedEvent != nil {
        appVM.selectedEvent = nil
        return .handled
      }
      return .ignored
    }
    .onKeyPress(keys: ["t"]) { _ in
      appVM.onTodayClicked()
      return .handled
    }
    .onKeyPress(keys: ["m"]) { _ in
      appVM.toggleCalendarView()
      return .handled
    }
    .onKeyPress(keys: ["e"]) { _ in
      appVM.toggleEventsView()
      return .handled
    }
  }
}

struct TopBar: View {
  @State private var showingEventsViewMenu: Bool = true
  var body: some View {
    HStack {
      Spacer()
      TopToolbar()
    }
  }
}


#Preview {
  CalView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
}

