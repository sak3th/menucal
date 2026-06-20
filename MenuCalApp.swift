//
//  MenuCalApp.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 24/11/25.
//

import SwiftUI
import AppKit

@main
struct MenuCalApp: App {
  @State private var permViewModel = PermissionsViewModel()
  @State private var appViewModel = AppViewModel()
  @State private var eventsViewModel = EventsViewModel()
  @State private var settingsViewModel = SettingsViewModel.shared

  var body: some Scene {
      MenuBarExtra {
        AppView()
          .environment(permViewModel)
          .environment(appViewModel)
          .environment(eventsViewModel)
          .environment(settingsViewModel)
          .frame(width: ViewConstants.appWidth, height: appViewModel.appHeight)
          .onAppear {
            appViewModel.onAppStart()
            // Apply the persisted window size on first launch (the first
            // didBecomeKey may fire before this observer is registered).
            appViewModel.updateAppHeight(for: NSScreen.main, fraction: settingsViewModel.fraction)
            permViewModel.checkPermissions()
            if permViewModel.hasPermissions() {
              Task {
                await eventsViewModel.refreshAll()
              }
            }
            NotificationCenter.default.addObserver(
              forName: NSWindow.didBecomeKeyNotification,
              object: nil,
              queue: .main
            ) { note in
              // Resize to whichever display the popover opened on.
              appViewModel.updateAppHeight(for: (note.object as? NSWindow)?.screen, fraction: settingsViewModel.fraction)
              appViewModel.handleWindowBecameKey(resetToToday: settingsViewModel.resetToTodayOnReopen)
              if permViewModel.hasPermissions() {
                Task { await eventsViewModel.refreshAll() }
              }
            }
            NotificationCenter.default.addObserver(
              forName: NSApplication.didChangeScreenParametersNotification,
              object: nil,
              queue: .main
            ) { _ in
              appViewModel.updateAppHeight(for: NSApp.keyWindow?.screen, fraction: settingsViewModel.fraction)
            }
          }
          .onChange(of: permViewModel.hasCalendarPermission) {
            if permViewModel.hasPermissions() {
              Task { await eventsViewModel.refreshAll() }
            }
          }
          .onChange(of: permViewModel.hasReminderPermission) {
            if permViewModel.hasPermissions() {
              Task { await eventsViewModel.refreshAll() }
            }
          }
          .background(.regularMaterial)
      } label: {
        Image(systemName: "calendar")
          .font(.system(size: 24))
      }
      .menuBarExtraStyle(.window)
  }
}


#Preview {
  AppView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth, height: 700)
}

