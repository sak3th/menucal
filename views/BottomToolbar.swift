//
//  BottomToolbar.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import SwiftUI

struct BottomToolbar: View {
  @Environment(AppViewModel.self) private var appVM
  @State private var showingCalendarList = false
  
  var body: some View {
    HStack(alignment: .center) {
      GlassEffectContainer {
        Button(action: {appVM.onTodayClicked()}) {
          Text("Today")
            .font(.body)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .interactiveButtonBackground()
        .glassEffect(in: Capsule())
        .glassEffectTransition(.matchedGeometry)
      }
      
      
      
      Spacer()
      
      GlassEffectContainer {
        HStack(spacing: 4) {
          Button(action: { showingCalendarList = true }) {
            Image(systemName: "calendar")
              .font(.system(size: 14))
              .padding(4)
          }
          .interactiveButtonBackground()
          .popover(isPresented: $showingCalendarList) {
            CalendarListView()
          }
          
          Button(action: {}) {
            Image(systemName: "tray")
              .font(.system(size: 14))
              .padding(4)
          }
          .interactiveButtonBackground()
        }
        .padding(2)
        .glassEffect(in: Capsule())
        .glassEffectTransition(.matchedGeometry)
      }
    }
    .padding(.horizontal, ViewConstants.padding)
  }
}

struct CalendarListView: View {
  @Environment(EventsViewModel.self) private var eventsVM
  
  var body: some View {
    List {
      let grouped = Dictionary(grouping: eventsVM.calendars, by: { $0.sourceTitle })
      let sortedKeys = grouped.keys.sorted()
      
      ForEach(sortedKeys, id: \.self) { source in
        Section(source) {
          ForEach(grouped[source] ?? []) { calendar in
            Button(action: { eventsVM.toggleCalendarVisibility(id: calendar.id) }) {
              HStack {
                Image(systemName: !eventsVM.hiddenCalendarIDs.contains(calendar.id) ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(calendar.color)
                  .font(.title3)
                Text(calendar.title)
                  .foregroundStyle(.primary)
                Spacer()
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
          }
        }
      }
    }
    .listStyle(.sidebar)
    .frame(minWidth: 300, minHeight: 400)
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

