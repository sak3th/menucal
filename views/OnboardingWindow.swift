//
//  OnboardingWindow.swift
//  MenuCal
//

import SwiftUI

// A real window, not a popover section. Both setup steps hand off to another
// app — System Settings for permissions, the browser for Google — and
// MenuBarExtra(.window) dismisses the moment that happens, taking any progress
// or error message with it.
enum OnboardingStep: String {
  case permissions
  case google
  case done

  static let windowID = "onboarding"
}

struct OnboardingWindow: View {
  @Environment(PermissionsViewModel.self) private var permVM
  @Environment(EventsViewModel.self) private var eventsVM
  @Environment(GoogleAuth.self) private var auth

  // Derived, not navigated: granting access advances the window on its own.
  // The Google step comes after permissions for a reason — until EventKit is
  // readable we can't see which accounts are on the Mac, and the offer would
  // be a blind one. Someone whose calendars are all iCloud skips it entirely.
  private var step: OnboardingStep {
    // Hold on the permissions step until the account list has actually been
    // read. "No Google accounts" and "haven't looked yet" are the same value,
    // and advancing on the second flashes the wrong ending before correcting
    // itself a frame later.
    guard permVM.hasPermissions(), eventsVM.hasFetchedCalendars else { return .permissions }
    if auth.isConnected || !eventsVM.googleAccounts.isEmpty { return .google }
    return .done
  }

  var body: some View {
    VStack(spacing: 0) {
      switch step {
      case .permissions: PermissionsStep()
      case .google: GoogleConnectStep()
      case .done: DoneStep()
      }
    }
    .frame(width: 440)
    .fixedSize(horizontal: false, vertical: true)
    .animation(.smooth(duration: 0.3), value: step)
    // Nothing else fetches the account list while setup is on screen: the
    // handlers that refetch after a grant hang off AppView, which is the
    // popover's content and doesn't exist until the icon is clicked.
    .task { await eventsVM.fetchCalendars() }
    .onChange(of: permVM.hasCalendarPermission) { _, granted in
      if granted { Task { await eventsVM.fetchCalendars() } }
    }
    .onDisappear {
      // Closing the window with the red button skips the Cancel path, which
      // would leave the loopback listener bound and let a stale browser tab
      // still complete a flow the user walked away from.
      if case .awaitingCallback = auth.phase { auth.cancel() }
    }
  }
}

// MARK: - Shared chrome

// One header shape for every step, so advancing reads as the same window
// changing its mind rather than three unrelated screens.
private struct StepHeader: View {
  let symbol: String
  let title: String
  let detail: String

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: symbol)
        .font(.system(size: 34, weight: .light))
        .foregroundStyle(.tint)
        .padding(.top, 30)

      Text(title)
        .font(.system(size: 17, weight: .semibold))

      Text(detail)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 36)
    }
  }
}

// A status row, deliberately not a checkbox: the trailing value states what is
// true, so it can't be mistaken for something waiting to be ticked.
private struct StatusRow: View {
  let label: String
  let value: String
  let tint: Color

  var body: some View {
    HStack {
      Text(label).font(.system(size: 13))
      Spacer(minLength: 8)
      Text(value)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(tint)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
  }
}

// MARK: - Step 1 · Permissions

private struct PermissionsStep: View {
  @Environment(PermissionsViewModel.self) private var permVM

  var body: some View {
    VStack(spacing: 18) {
      StepHeader(
        symbol: "calendar",
        title: "Access your calendar",
        detail: "MenuCal shows the events already on this Mac. "
              + "Nothing is uploaded, and nothing is shared."
      )

      SettingsSection("Permissions") {
        StatusRow(label: "Calendar", value: calendarValue, tint: calendarTint)
        Divider().padding(.leading, 12)
        StatusRow(label: "Reminders", value: reminderValue, tint: reminderTint)
      }
      .padding(.horizontal, 24)

      actions
        .padding(.bottom, 26)
    }
  }

  // Required vs Optional up front, then what actually happened. Reminders is
  // marked optional because nothing in the app reads it yet — denying it must
  // not look like a failure.
  private var calendarValue: String {
    if permVM.hasCalendarPermission { return "Granted" }
    return permVM.canRequestCalendar ? "Required" : "Denied"
  }

  private var calendarTint: Color {
    if permVM.hasCalendarPermission { return .green }
    return permVM.canRequestCalendar ? .secondary : .red
  }

  private var reminderValue: String {
    if permVM.hasReminderPermission { return "Granted" }
    return permVM.canRequestReminder ? "Optional" : "Not granted"
  }

  private var reminderTint: Color {
    permVM.hasReminderPermission ? .green : .secondary
  }

  @ViewBuilder
  private var actions: some View {
    if permVM.isRequestingPermissions {
      ProgressView().controlSize(.small)
    } else if permVM.hasUngrantedRequestable {
      Button("Grant Access") {
        Task { await permVM.requestPermissions() }
      }
      .keyboardShortcut(.defaultAction)
    } else {
      VStack(spacing: 10) {
        Text("Calendar access was declined. Turn it on in System Settings and MenuCal will pick it up.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 36)
        // Launching another app is exactly what the popover can't survive —
        // the reason this step lives in a window at all.
        Button("Open System Settings") { permVM.openSystemSettings() }
          .keyboardShortcut(.defaultAction)
      }
    }
  }
}

// MARK: - Step 2 · Google

private struct GoogleConnectStep: View {
  @Environment(GoogleAuth.self) private var auth
  @Environment(EventsViewModel.self) private var eventsVM
  @Environment(SettingsViewModel.self) private var settings
  @Environment(\.dismiss) private var dismiss
  @State private var copied = false

  var body: some View {
    VStack(spacing: 18) {
      StepHeader(
        symbol: "checkmark.circle",
        title: "Respond to Google invites",
        detail: "Accept, Maybe and Decline go straight to Google. "
              + "Connect each account you want to answer invites for — "
              + "the rest keep opening Google Calendar in your browser."
      )

      SettingsSection("Google accounts on this Mac") {
        GoogleAccountRows(accounts: eventsVM.googleAccounts) { email in
          Task { await auth.start(for: email, openBrowser: true) }
        }
      }
      .padding(.horizontal, 24)

      status
        .padding(.horizontal, 24)

      actions
        .padding(.bottom, 26)
    }
  }

  @ViewBuilder
  private var status: some View {
    switch auth.phase {
    case .idle:
      EmptyView()
    case .awaitingCallback:
      Text(copied ? "Link copied — paste it into your browser" : "Waiting for Google…")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    case .exchanging:
      HStack(spacing: 8) {
        ProgressView().controlSize(.small)
        Text("Finishing up…").font(.system(size: 12)).foregroundStyle(.secondary)
      }
    case .failed(let message):
      Text(message)
        .font(.system(size: 12))
        .foregroundStyle(.red)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)
    }
  }

  @ViewBuilder
  private var actions: some View {
    if case .awaitingCallback = auth.phase {
      HStack(spacing: 10) {
        Button("Cancel") { auth.cancel() }
        // The default browser may be signed into the wrong Google profile;
        // pasting the link is the only way to choose.
        Button("Copy Link") { copyLink() }
        Button("Open in Browser") { reopenBrowser() }
          .keyboardShortcut(.defaultAction)
      }
    } else {
      // Never a dead end: connecting no accounts is a valid answer, and
      // Settings is the way back for anyone who changes their mind.
      Button(eventsVM.hasUnconnectedGoogleAccounts ? "Not now" : "Done") { finish() }
        .keyboardShortcut(.defaultAction)
    }
  }

  // Declining is permanent: a menu bar app that re-asks every launch is worse
  // than one you have to go find a setting for. Settings is the way back.
  private func finish() {
    auth.cancel()
    settings.didSeeGoogleOnboarding = true
    dismiss()
  }

  private func copyLink() {
    guard let url = auth.authURL else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(url.absoluteString, forType: .string)
    copied = true
  }

  private func reopenBrowser() {
    guard let url = auth.authURL else { return }
    GoogleCalendarDeepLink.openInBrowser(url)
  }
}

// MARK: - Step 3 · Done

// Reached by anyone with no Google account to connect. Without it the window
// would offer a Google sign-in to someone who only has iCloud calendars, and
// never admit that setup was finished.
private struct DoneStep: View {
  @Environment(SettingsViewModel.self) private var settings
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 18) {
      StepHeader(
        symbol: "menubar.arrow.up.rectangle",
        title: "You're all set",
        detail: "MenuCal lives in the menu bar. Click the calendar icon any time."
      )

      Button("Done") {
        settings.didSeeGoogleOnboarding = true
        dismiss()
      }
      .keyboardShortcut(.defaultAction)
      .padding(.bottom, 26)
    }
  }
}
