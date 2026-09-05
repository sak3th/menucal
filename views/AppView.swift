//
//  AppView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import AppKit
import SwiftUI

struct AppView: View {
  @Environment(PermissionsViewModel.self) private var permVM
  @Environment(EventsViewModel.self) private var eventsVM
  @Environment(SettingsViewModel.self) private var settings
  @Environment(GoogleAuth.self) private var auth
  @Environment(\.openWindow) private var openWindow

  // Setup that still needs the user: permissions first, then the one-time
  // Google offer — and only for people who actually have a Google account.
  private var needsOnboarding: Bool {
    if !permVM.hasPermissions() { return true }
    return !settings.didSeeGoogleOnboarding
        && eventsVM.hasGoogleCalendars
        && !auth.isConnected
  }

  var body: some View {
    VStack(alignment: .center) {
      if !permVM.hasPermissions() {
        PermissionsView()
      } else {
        CalView()
      }
    }
    // A fallback for a setup window closed before finishing. The first-run
    // presentation happens at launch, from the menu bar label.
    .onAppear { presentOnboardingIfNeeded() }
    .onChange(of: eventsVM.hasGoogleCalendars) { presentOnboardingIfNeeded() }
  }

  // Both conditions clear themselves once handled — granting access, and
  // connecting or skipping — so this can't turn into a nag on every open.
  private func presentOnboardingIfNeeded() {
    guard needsOnboarding else { return }
    openWindow(id: OnboardingStep.windowID)
    NSApp.activate(ignoringOtherApps: true)
  }
}

#Preview {
  AppView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
}

