//
//  AddEventLauncher.swift
//  MenuCal
//

import AppKit
import Foundation

// Routes the "+" button to the user's preferred calendar target.
enum AddEventLauncher {
  static func perform(_ action: AddEventAction) {
    switch action {
    case .appleCalendar:
      NSWorkspace.shared.launchApplication(
        withBundleIdentifier: "com.apple.iCal",
        options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil
      )

    case .googleWeb:
      GoogleCalendarDeepLink.openInBrowser(GoogleCalendarDeepLink.homeURL)

    case .webApp:
      GoogleCalendarDeepLink.openInWebApp(GoogleCalendarDeepLink.homeURL)
    }
  }
}
