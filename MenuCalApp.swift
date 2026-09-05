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
  @State private var googleAuth = GoogleAuth.shared
  @State private var didRegisterObservers = false

  var body: some Scene {
      MenuBarExtra {
        AppView()
          .environment(permViewModel)
          .environment(appViewModel)
          .environment(eventsViewModel)
          .environment(settingsViewModel)
          .environment(googleAuth)
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
            // Register global observers once — .onAppear can run per popover
            // open, and re-registering would stack duplicate handlers.
            if !didRegisterObservers {
              didRegisterObservers = true
              NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
              ) { note in
                // Only react to the popover window (~appWidth, untitled), not
                // menus, panels, the file picker, or the onboarding window —
                // any of which would otherwise reset the user's selected date.
                guard let window = note.object as? NSWindow,
                      window.title.isEmpty,
                      abs(window.frame.width - ViewConstants.appWidth) < 80 else { return }
                appViewModel.updateAppHeight(for: window.screen, fraction: settingsViewModel.fraction)
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
        MenuBarLabel(
          permVM: permViewModel,
          eventsVM: eventsViewModel,
          settings: settingsViewModel,
          auth: googleAuth
        )
      }
      .menuBarExtraStyle(.window)

      // A titled window, so the popover's didBecomeKey filter above ignores it.
      Window("MenuCal Setup", id: OnboardingStep.windowID) {
        OnboardingWindow()
          .environment(permViewModel)
          .environment(eventsViewModel)
          .environment(googleAuth)
          .environment(settingsViewModel)
      }
      .windowResizability(.contentSize)
      .defaultPosition(.center)
  }
}


// The label renders when the status item is installed, so this is the earliest
// view that exists at launch. The popover's content doesn't exist until the
// icon is clicked, which is why the gate can't live there — a first-run user
// would see an icon and no setup until they thought to click it.
private struct MenuBarLabel: View {
  let permVM: PermissionsViewModel
  let eventsVM: EventsViewModel
  let settings: SettingsViewModel
  let auth: GoogleAuth

  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Image(systemName: "calendar")
      .font(.system(size: 24))
      .onAppear {
        permVM.checkPermissions()
        guard permVM.hasPermissions() else {
          present()
          return
        }
        // Calendars decide whether the Google step applies at all, and nothing
        // has fetched them yet this early.
        Task {
          await eventsVM.fetchCalendars()
          if !settings.didSeeGoogleOnboarding, eventsVM.hasGoogleCalendars, !auth.isConnected {
            present()
          }
        }
      }
  }

  private func present() {
    openWindow(id: OnboardingStep.windowID)
    NSApp.activate(ignoringOtherApps: true)
  }
}

#Preview {
  AppView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth, height: 700)
}

