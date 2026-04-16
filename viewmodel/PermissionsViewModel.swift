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

  var canRequestCalendar: Bool { calendarStatus == .notDetermined }
  var canRequestReminder: Bool { reminderStatus == .notDetermined }
  var hasUngrantedRequestable: Bool { (!hasCalendarPermission && canRequestCalendar) || (!hasReminderPermission && canRequestReminder) }
  var allDenied: Bool { !hasPermissions() && !hasUngrantedRequestable }

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

  func hasPermissions() -> Bool {
    hasCalendarPermission && hasReminderPermission
  }

  func checkPermissions() {
    calendarStatus = EKEventStore.authorizationStatus(for: .event)
    reminderStatus = EKEventStore.authorizationStatus(for: .reminder)

    hasCalendarPermission = (calendarStatus == .fullAccess || calendarStatus == .writeOnly)
    hasReminderPermission = (reminderStatus == .fullAccess || reminderStatus == .writeOnly)
  }

  func requestPermissions() async {
    isRequestingPermissions = true
    let store = EKEventStore()

    if !hasCalendarPermission && canRequestCalendar {
      hasCalendarPermission = (try? await store.requestFullAccessToEvents()) ?? false
    }
    if !hasReminderPermission && canRequestReminder {
      hasReminderPermission = (try? await store.requestFullAccessToReminders()) ?? false
    }

    // Poll a few times to catch delayed system propagation
    for _ in 0..<5 {
      checkPermissions()
      if hasPermissions() { break }
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
