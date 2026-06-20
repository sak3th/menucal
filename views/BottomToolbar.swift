//
//  BottomToolbar.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import SwiftUI

struct BottomToolbar: View {
  @Environment(AppViewModel.self) private var appVM

  var body: some View {
    HStack(alignment: .bottom) {
      if appVM.activeOverlay != .calendarList && appVM.activeOverlay != .settings {
        GlassEffectContainer {
          Button(action: {appVM.onTodayClicked()}) {
            Text("Today")
              .font(.body)
              .padding(.vertical, 8)
              .padding(.horizontal, 12)
          }
          .interactiveButtonBackground()
          .glassEffect(.regular.interactive(), in: Capsule())
          .glassEffectTransition(.matchedGeometry)
        }

        Spacer()
      }

      GlassEffectContainer {
        if appVM.activeOverlay == .calendarList {
          CalendarListView()
            .frame(maxWidth: .infinity)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16.0))
            .glassEffectTransition(.matchedGeometry)
        } else if appVM.activeOverlay == .settings {
          SettingsView(maxContentHeight: appVM.appHeight * 0.62)
            .frame(maxWidth: .infinity)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16.0))
            .glassEffectTransition(.matchedGeometry)
        } else {
          HStack(spacing: 4) {
            Button(action: { withAnimation(.spring) { appVM.activeOverlay = .calendarList } }) {
              Image(systemName: "calendar")
                .toolbarIcon()
                .padding(6)
            }
            .interactiveButtonBackground()

            Button(action: { withAnimation(.spring) { appVM.activeOverlay = .settings } }) {
              Image(systemName: "gearshape")
                .toolbarIcon()
                .padding(6)
            }
            .interactiveButtonBackground()
          }
          .padding(4)
          .glassEffect(in: Capsule())
          .glassEffectTransition(.matchedGeometry)
        }
      }
    }
    .padding(.horizontal, ViewConstants.padding)
  }
}

struct CalendarListView: View {
  @Environment(EventsViewModel.self) private var eventsVM
  @Environment(AppViewModel.self) private var appVM

  var body: some View {
    let grouped = Dictionary(grouping: eventsVM.calendars, by: { $0.sourceTitle })
    let sortedKeys = grouped.keys.sorted()

    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        ForEach(sortedKeys, id: \.self) { source in
          SettingsSection(source) {
            ForEach(grouped[source] ?? []) { calendar in
              CalendarToggleRow(
                calendar: calendar,
                isOn: !eventsVM.hiddenCalendarIDs.contains(calendar.id)
              ) {
                eventsVM.toggleCalendarVisibility(id: calendar.id)
              }
            }
          }
        }
      }
      .padding(14)
    }
    .frame(maxHeight: appVM.appHeight * 0.7)
    .fixedSize(horizontal: false, vertical: true)
    .task {
      await eventsVM.fetchCalendars()
    }
  }
}


struct CalendarToggleRow: View {
  let calendar: CalendarInfo
  let isOn: Bool
  let toggle: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: toggle) {
      HStack(spacing: 10) {
        RoundedCheckbox(isOn: isOn, color: calendar.color)
        Text(calendar.title)
          .font(.system(size: 13, weight: .regular))
          .foregroundStyle(.primary)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .contentShape(Rectangle())
      .background(hovering ? Color.primary.opacity(0.05) : Color.clear)
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

struct RoundedCheckbox: View {
  let isOn: Bool
  let color: Color

  var body: some View {
    RoundedRectangle(cornerRadius: 5, style: .continuous)
      .fill(isOn ? color : Color.clear)
      .overlay {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
          .strokeBorder(isOn ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1.5)
      }
      .overlay {
        if isOn {
          Image(systemName: "checkmark")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(color.contrastingForegroundColor)
        }
      }
      .frame(width: 15, height: 15)
  }
}

#Preview {
  BottomToolbar()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
}

