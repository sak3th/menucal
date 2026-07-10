//
//  SettingsViewModel.swift
//  MenuCal
//

import Foundation
import SwiftUI
import ServiceManagement

enum AddEventAction: String, CaseIterable {
  case appleCalendar
  case googleWeb
  case webApp

  var label: String {
    switch self {
    case .appleCalendar: return "Apple Calendar"
    case .googleWeb: return "Google Calendar"
    case .webApp: return "Web App"
    }
  }
}

enum TimelineLayout: String, CaseIterable {
  case nested
  case columns

  var label: String {
    switch self {
    case .nested: return "Nested"
    case .columns: return "Columns"
    }
  }
}

enum WindowSize: String, CaseIterable {
  case small
  case medium
  case large

  var label: String {
    switch self {
    case .small: return "Small"
    case .medium: return "Medium"
    case .large: return "Large"
    }
  }

  var fraction: CGFloat {
    switch self {
    case .small: return 0.6
    case .medium: return 0.75
    case .large: return 0.9
    }
  }
}

@Observable
class SettingsViewModel {
  // Shared instance so the service layer (deep links) can read preferences.
  static let shared = SettingsViewModel()

  var addEventAction: AddEventAction {
    didSet { UserDefaults.standard.set(addEventAction.rawValue, forKey: "addEventAction") }
  }

  var webAppPath: String {
    didSet { UserDefaults.standard.set(webAppPath, forKey: "webAppPath") }
  }

  var dismissAfterJoin: Bool {
    didSet { UserDefaults.standard.set(dismissAfterJoin, forKey: "dismissAfterJoin") }
  }

  var windowSize: WindowSize {
    didSet { UserDefaults.standard.set(windowSize.rawValue, forKey: "windowSize") }
  }

  var timelineLayout: TimelineLayout {
    didSet { UserDefaults.standard.set(timelineLayout.rawValue, forKey: "timelineLayout") }
  }

  var resetToTodayOnReopen: Bool {
    didSet { UserDefaults.standard.set(resetToTodayOnReopen, forKey: "resetToTodayOnReopen") }
  }

  // Backed by the system (login items), not UserDefaults.
  var launchAtLogin: Bool {
    didSet {
      guard launchAtLogin != oldValue else { return }
      do {
        if launchAtLogin {
          try SMAppService.mainApp.register()
        } else {
          try SMAppService.mainApp.unregister()
        }
      } catch {
        NSLog("Launch-at-login toggle failed: \(error)")
        // Revert to the real system state on failure.
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
      }
    }
  }

  var fraction: CGFloat { windowSize.fraction }

  init() {
    let defaults = UserDefaults.standard
    addEventAction = AddEventAction(rawValue: defaults.string(forKey: "addEventAction") ?? "") ?? .webApp
    webAppPath = defaults.string(forKey: "webAppPath") ?? ""
    dismissAfterJoin = defaults.object(forKey: "dismissAfterJoin") as? Bool ?? true
    windowSize = WindowSize(rawValue: defaults.string(forKey: "windowSize") ?? "") ?? .medium
    timelineLayout = TimelineLayout(rawValue: defaults.string(forKey: "timelineLayout") ?? "") ?? .nested
    resetToTodayOnReopen = defaults.object(forKey: "resetToTodayOnReopen") as? Bool ?? false
    launchAtLogin = (SMAppService.mainApp.status == .enabled)
  }
}
