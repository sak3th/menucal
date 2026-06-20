import AppKit
import Foundation

// Builds Google Calendar event links and opens them in a locally installed
// Google Calendar web app (Safari "Add to Dock" or Chrome PWA) when present,
// falling back to the default browser.
enum GoogleCalendarDeepLink {

  static func eventURL(for event: Event) -> URL? {
    guard let eventId = event.googleEventId, let email = event.currentUserEmail else {
      return nil
    }
    // eid = websafe base64 of "<eventId> <calendarEmail>", padding stripped
    let eid = Data("\(eventId) \(email)".utf8).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    return URL(string: "https://calendar.google.com/calendar/event?eid=\(eid)")
  }

  // Day view, for events whose exact id can't be derived (foreign iCalUID)
  static func dayURL(for date: Date) -> URL? {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
    guard let y = c.year, let m = c.month, let d = c.day else { return nil }
    return URL(string: "https://calendar.google.com/calendar/r/day/\(y)/\(m)/\(d)")
  }

  static let homeURL = URL(string: "https://calendar.google.com/calendar/r")!

  // Opens a Google Calendar URL honoring the user's preferred target:
  // the browser for `.googleWeb`, the local web app for `.webApp`.
  static func openEvent(_ url: URL) {
    switch SettingsViewModel.shared.addEventAction {
    case .googleWeb:
      openInBrowser(url)
    case .webApp, .appleCalendar:
      openInWebApp(url)
    }
  }

  // For the "+" button's Google/Web App targets (opens the calendar home).
  static func openHome() {
    openEvent(homeURL)
  }

  // Force the default *browser*, not a web app that may claim the domain.
  static func openInBrowser(_ url: URL) {
    let probe = URL(string: "https://www.apple.com")!
    if let browser = NSWorkspace.shared.urlForApplication(toOpen: probe) {
      NSWorkspace.shared.open([url], withApplicationAt: browser, configuration: NSWorkspace.OpenConfiguration())
    } else {
      NSWorkspace.shared.open(url)
    }
  }

  static func openInWebApp(_ url: URL) {
    let customPath = SettingsViewModel.shared.webAppPath.trimmingCharacters(in: .whitespaces)
    let appURL: URL? = customPath.isEmpty ? webAppURL : URL(fileURLWithPath: customPath)
    if let appURL {
      NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    } else {
      openInBrowser(url)
    }
  }

  // A web app for calendar.google.com in ~/Applications, located by its
  // Info.plist contents rather than its (user-chosen) name.
  private static let webAppURL: URL? = {
    let fm = FileManager.default
    let userApps = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    let searchDirs = [userApps, userApps.appendingPathComponent("Chrome Apps.localized")]

    for dir in searchDirs {
      guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
        continue
      }
      for appURL in contents where appURL.pathExtension == "app" {
        if isGoogleCalendarApp(appURL) {
          return appURL
        }
      }
    }
    return nil
  }()

  private static func isGoogleCalendarApp(_ appURL: URL) -> Bool {
    let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
    guard let data = try? Data(contentsOf: plistURL),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
      return false
    }
    return containsGoogleCalendarHost(plist)
  }

  private static func containsGoogleCalendarHost(_ value: Any) -> Bool {
    switch value {
    case let string as String:
      return string.contains("calendar.google.com")
    case let dict as [String: Any]:
      return dict.values.contains(where: containsGoogleCalendarHost)
    case let array as [Any]:
      return array.contains(where: containsGoogleCalendarHost)
    default:
      return false
    }
  }
}
