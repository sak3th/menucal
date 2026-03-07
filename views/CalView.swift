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
      ZStack(alignment: .bottomLeading) {
        VStack(alignment: .center, spacing: 0) {
          HStack {
            //Spacer()
            PagedMonthView()
              .frame(width: ViewConstants.monthViewWidth)
            //Spacer()
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
        
        BottomToolbar()
          .offset(y: -6)
      }
      TopBar()
        .padding(.horizontal, 4)
        .offset(x: -4, y: 8)

      if let event = appVM.selectedEvent {
        ZStack(alignment: .topTrailing) {
          ScrollView {
            EventDetailView(event: event)
              .padding()
          }
          .scrollIndicators(.hidden)
          .background(.thinMaterial)
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
      if press.key == .leftArrow {
        appVM.goToPrevDate()
      } else if press.key == .rightArrow {
        appVM.goToNextDate()
      }
      return .handled
    }
    .onKeyPress(keys: [",", ".", .upArrow, .downArrow]) { press in
      if press.characters == "," || press.key == .upArrow {
        appVM.goToPrevMonth()
      } else if press.characters == "." || press.key == .downArrow {
        appVM.goToNextMonth()
      }
      return .handled
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

