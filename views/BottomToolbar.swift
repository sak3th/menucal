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
      if appVM.activeOverlay != .calendarList {
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
          VStack(spacing: 0) {
            CalendarListView()
            Divider().padding(.horizontal, 8)
            Button(action: { withAnimation(.spring) { appVM.activeOverlay = .none } }) {
              Text("Done")
                .font(.system(size: 13))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
            }
            .interactiveButtonBackground()
            .padding(4)
          }
          .frame(maxWidth: .infinity)
          .glassEffect(in: RoundedRectangle(cornerRadius: 16.0))
          .glassEffectTransition(.matchedGeometry)
        } else {
          HStack(spacing: 4) {
            Button(action: { withAnimation(.spring) { appVM.activeOverlay = .calendarList } }) {
              Image(systemName: "calendar")
                .font(.system(size: 14))
                .padding(6)
            }
            .interactiveButtonBackground()

            Button(action: {}) {
              Image(systemName: "tray")
                .font(.system(size: 14))
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

  var body: some View {
    let grouped = Dictionary(grouping: eventsVM.calendars, by: { $0.sourceTitle })
    let sortedKeys = grouped.keys.sorted()

    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(sortedKeys, id: \.self) { source in
          Text(source)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)

          ForEach(grouped[source] ?? []) { calendar in
            Button(action: { eventsVM.toggleCalendarVisibility(id: calendar.id) }) {
              HStack {
                Image(systemName: !eventsVM.hiddenCalendarIDs.contains(calendar.id) ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(calendar.color)
                  .font(.title3)
                Text(calendar.title)
                  .font(.system(size: 13, weight: .regular))
                  .foregroundStyle(.primary)
                Spacer()
              }
              .contentShape(Rectangle())
              .padding(.horizontal, 12)
              .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.vertical, 4)
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxHeight: ViewConstants.appHeight * 0.7)
    .task {
      await eventsVM.fetchCalendars()
    }
  }
}


#Preview {
  BottomToolbar()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
}

