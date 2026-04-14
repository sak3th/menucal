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
          PagedMonthView()
            .frame(width: ViewConstants.monthViewWidth)
        }

        Group {
          if appVM.selectedEventsView == .timeline {
            PagedDayTimelineView()
          } else {
            EventsView()
          }
        }
        .frame(minHeight: ViewConstants.appHeight * 0.3)
        .padding(.horizontal, ViewConstants.padding)
        .scrollEdgeEffectStyle(.hard, for: .bottom)
      }
      .padding(.top, ViewConstants.padding)
      .frame(width: ViewConstants.appWidth)

      // Dismiss overlay — catches taps outside menus
      if appVM.activeOverlay != .none {
        Color.clear
          .contentShape(Rectangle())
          .frame(width: ViewConstants.appWidth, height: ViewConstants.appHeight)
          .onTapGesture {
            withAnimation(.spring) { appVM.dismissOverlays() }
          }
          .zIndex(2)
      }

      BottomToolbar()
        .padding(.bottom, 6)
        .frame(width: ViewConstants.appWidth, height: ViewConstants.appHeight, alignment: .bottom)
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
        .frame(width: ViewConstants.appWidth, height: ViewConstants.appHeight)
        .transition(.opacity)
        .zIndex(100)
      }
    }
    .frame(width: ViewConstants.appWidth, height: ViewConstants.appHeight)
    .frame(maxHeight: ViewConstants.appHeight)
    .focusable()
    .focused($isFocused)
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
        appVM.goToPrevMonth()
      } else if press.characters == "." {
        appVM.goToNextMonth()
      }
      return .handled
    }
    .onKeyPress(keys: [.escape]) { _ in
      if appVM.activeOverlay != .none {
        withAnimation(.spring) { appVM.dismissOverlays() }
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

