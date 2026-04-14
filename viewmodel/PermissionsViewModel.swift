//
//  PermissionsViewMode.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import Foundation
import EventKit


@MainActor
@Observable
class PermissionsViewModel: Identifiable {
  var hasCalendarPermission: Bool = false
  var hasReminderPermission: Bool = false

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
    let calendarStatus = EKEventStore.authorizationStatus(for: .event)
    let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)

    hasCalendarPermission = (calendarStatus == .fullAccess || calendarStatus == .writeOnly)
    hasReminderPermission = (reminderStatus == .fullAccess || reminderStatus == .writeOnly)

    print(
      "Calendar permission status: \(calendarStatus.rawValue) (authorized: \(hasCalendarPermission))"
    )
    print(
      "Reminder permission status: \(reminderStatus.rawValue) (authorized: \(hasReminderPermission))"
    )
  }

  func requestPermissions() async {
    let store = EKEventStore()
    if !hasCalendarPermission {
      hasCalendarPermission = (try? await store.requestFullAccessToEvents()) ?? false
    }
    if !hasReminderPermission {
      hasReminderPermission = (try? await store.requestFullAccessToReminders()) ?? false
    }
    checkPermissions()
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

