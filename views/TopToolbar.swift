//
//  TopToolbar.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import SwiftUI
import AppKit


struct TopToolbar: View {
  @Environment(AppViewModel.self) private var appVM

  var body: some View {
    GlassEffectContainer {
      switch appVM.activeOverlay {
      case .eventsMenu:
        EventsMenu(onCollapse: { withAnimation(.toolbarOverlay) { appVM.activeOverlay = .none } })
          .glassEffect(in: RoundedRectangle(cornerRadius: 16.0))
          .glassEffectTransition(.matchedGeometry)
      case .calendarViewMenu:
        CalendarViewMenu(onCollapse: { withAnimation(.toolbarOverlay) { appVM.activeOverlay = .none } })
          .glassEffect(in: RoundedRectangle(cornerRadius: 16.0))
          .glassEffectTransition(.matchedGeometry)
      default:
        Toolbar(
          onExpandEventsMenu: { withAnimation(.toolbarOverlay) { appVM.activeOverlay = .eventsMenu } },
          onExpandCalendarViewMenu: { withAnimation(.toolbarOverlay) { appVM.activeOverlay = .calendarViewMenu } }
        )
        .toolbarPill()
      }
    }
  }
}

struct EventsMenu: View {
  @Environment(AppViewModel.self) private var appVM

  var onCollapse: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Group {
        Button(action: { selectEventsView(.timeline) }) {
          HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark")
              .font(.system(size: 8))
              .opacity(appVM.selectedEventsView == .timeline ? 1 : 0)
            Image(systemName: "calendar.day.timeline.left").font(.system(size: 12))
            Text("Timeline")
            Spacer()
          }
          .padding(4)
          .frame(maxWidth: ViewConstants.appWidth/2.2)
        }
        .interactiveButtonBackground()

        Button(action: { selectEventsView(.list) }) {
          HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark")
              .font(.system(size: 8))
              .opacity(appVM.selectedEventsView == .list ? 1 : 0)
            Image(systemName: "list.dash").font(.system(size: 12))
            Text("Events")
            Spacer()
          }
          .padding(4)
          .frame(maxWidth: ViewConstants.appWidth/2.2)
        }
        .interactiveButtonBackground()
      }
      .padding(4)

    }
    .padding(2)
  }

  private func selectEventsView(_ selection: CalViewMode) {
    appVM.selectedEventsView = selection
    onCollapse()
  }
}


struct CalendarViewMenu: View {
  @Environment(AppViewModel.self) private var appVM

  var onCollapse: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Group {
        Button(action: { selectCalendarView(.month) }) {
          HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark")
              .font(.system(size: 8))
              .opacity(appVM.selectedCalendarView == .month ? 1 : 0)
            Image(systemName: "31.square").font(.system(size: 12))
            Text("Month")
            Spacer()
          }
          .padding(4)
          .frame(maxWidth: ViewConstants.appWidth/2.2)
        }
        .interactiveButtonBackground()

        Button(action: { selectCalendarView(.week) }) {
          HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark")
              .font(.system(size: 8))
              .opacity(appVM.selectedCalendarView == .week ? 1 : 0)
            Image(systemName: "7.square").font(.system(size: 12))
            Text("Week")
            Spacer()
          }
          .padding(4)
          .frame(maxWidth: ViewConstants.appWidth/2.2)
        }
        .interactiveButtonBackground()
      }
      .padding(4)
    }
    .padding(2)
  }

  private func selectCalendarView(_ selection: CalendarViewMode) {
    appVM.selectedCalendarView = selection
    onCollapse()
  }
}

struct Toolbar: View {
  @Environment(AppViewModel.self) private var appVM
  @Environment(SettingsViewModel.self) private var settings

  var onExpandEventsMenu: () -> Void
  var onExpandCalendarViewMenu: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      Group {
        Button(action: onExpandEventsMenu) {
          Image(systemName: appVM.getEventsViewSymbol())
            .contentTransition(.symbolEffect(.replace))
            .toolbarIcon()
            .animation(.smooth(duration: 0.3), value: appVM.selectedEventsView)
        }
        .interactiveButtonBackground()

        Button(action: onExpandCalendarViewMenu) {
          Image(systemName: appVM.getCalendarViewSymbol())
            .contentTransition(.symbolEffect(.replace))
            .toolbarIcon()
            .animation(.smooth(duration: 0.3), value: appVM.selectedCalendarView)
        }
        .interactiveButtonBackground()

        Button(action: {
          AddEventLauncher.perform(settings.addEventAction)
        }) {
          Image(systemName: "plus")
            .toolbarIcon()
        }
        .interactiveButtonBackground()
      }
    }
  }
}


#Preview {
  TopToolbar()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .frame(width: ViewConstants.appWidth)
    .padding()
}
