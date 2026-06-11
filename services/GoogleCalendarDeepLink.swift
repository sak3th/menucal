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

  static func openApp() {
    if let appURL = webAppURL {
      NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    } else {
      NSWorkspace.shared.open(URL(string: "https://calendar.google.com/calendar/r")!)
    }
  }

  static func open(_ url: URL) {
    if let appURL = webAppURL {
      NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    } else {
      NSWorkspace.shared.open(url)
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
