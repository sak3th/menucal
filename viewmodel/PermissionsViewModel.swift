//
//  PermissionsViewMode.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import Foundation
import EventKit
import AppKit


@MainActor
@Observable
class PermissionsViewModel: Identifiable {
  var hasCalendarPermission: Bool = false
  var hasReminderPermission: Bool = false
  var isRequestingPermissions: Bool = false

  private var calendarStatus: EKAuthorizationStatus = .notDetermined
  private var reminderStatus: EKAuthorizationStatus = .notDetermined
  // Grants observed directly from a request. EKEventStore.authorizationStatus
  // can still report .notDetermined for a while after the user says yes, so
  // the request's own answer has to outrank it — otherwise the poll below
  // overwrites a real grant with a stale reading and the UI asks again.
  private var confirmedCalendarGrant = false
  private var confirmedReminderGrant = false

  var canRequestCalendar: Bool { calendarStatus == .notDetermined }
  var canRequestReminder: Bool { reminderStatus == .notDetermined }
  var hasUngrantedRequestable: Bool { (!hasCalendarPermission && canRequestCalendar) || (!hasReminderPermission && canRequestReminder) }

  init() {
    checkPermissions()
    NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.checkPermissions()
      }
    }
  }

  /// Calendar only. Reminders is still requested — nothing reads it yet, but
  /// the service layer is there — and must not gate the app: denying a
  /// permission the UI never consumes would lock the user out of a calendar
  /// that works perfectly well without it.
  func hasPermissions() -> Bool {
    hasCalendarPermission
  }


  func checkPermissions() {
    calendarStatus = EKEventStore.authorizationStatus(for: .event)
    reminderStatus = EKEventStore.authorizationStatus(for: .reminder)

    // A confirmed grant only survives a *stale* reading. An explicit .denied or
    // .restricted still wins, so revoking access in System Settings is noticed.
    hasCalendarPermission = (calendarStatus == .fullAccess || calendarStatus == .writeOnly)
      || (confirmedCalendarGrant && calendarStatus == .notDetermined)
    hasReminderPermission = (reminderStatus == .fullAccess || reminderStatus == .writeOnly)
      || (confirmedReminderGrant && reminderStatus == .notDetermined)
  }

  func requestPermissions() async {
    isRequestingPermissions = true
    let store = EKEventStore()

    if !hasCalendarPermission && canRequestCalendar {
      let granted = (try? await store.requestFullAccessToEvents()) ?? false
      confirmedCalendarGrant = confirmedCalendarGrant || granted
      hasCalendarPermission = granted
    }
    if !hasReminderPermission && canRequestReminder {
      let granted = (try? await store.requestFullAccessToReminders()) ?? false
      confirmedReminderGrant = confirmedReminderGrant || granted
      hasReminderPermission = granted
    }

    // Poll for the system to catch up. Breaking on calendar alone: it is the
    // only permission that gates the app, and waiting on a declined Reminders
    // would hold the spinner for the full 2.5s every time.
    for _ in 0..<5 {
      checkPermissions()
      if hasCalendarPermission { break }
      try? await Task.sleep(for: .milliseconds(500))
    }

    isRequestingPermissions = false
  }

  func openSystemSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars") {
      NSWorkspace.shared.open(url)
    }
  }
}

@MainActor
class PermsAllowedViewModel : PermissionsViewModel {
  override init() {
    super.init()
    self.hasCalendarPermission = true
    self.hasReminderPermission = true
  }
}

@MainActor
class NoPermissionsViewModel : PermissionsViewModel {
  override init() {
    super.init()
    self.hasCalendarPermission = false
    self.hasReminderPermission = false
  }
}
