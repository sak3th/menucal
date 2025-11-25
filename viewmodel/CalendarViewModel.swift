import Combine
import EventKit
import Foundation

@MainActor
class CalendarViewModel: ObservableObject {
  // Calendar and reminder permission state
  @Published var hasCalendarPermission: Bool = false
  @Published var hasReminderPermission: Bool = false
  @Published var errorMessage: String? = nil

  // Published properties for event and reminder data
  @Published var events: [Event] = []
  @Published var reminders: [Reminder] = []

  // The currently selected date for day view, default today
  @Published var selectedDate: Date = Date()

  // Track previous date for animation direction
  @Published var previousDate: Date? = nil

  private let eventStore = EKEventStore()
  private let calendarService: CalendarService = AppleCalendarService()
  private let reminderService: ReminderService = AppleReminderService()

  // ... your init and other methods ...

  /// Requests permissions for both calendars and reminders, logging the results.
  func requestPermissions() async {
    // Request Calendar permission
    let calendarStatus = EKEventStore.authorizationStatus(for: .event)
    if calendarStatus != .authorized {
      do {
        let granted = try await eventStore.requestAccess(to: .event)
        print("Calendar permission granted: \(granted)")
        if !granted {
          errorMessage = "User denied calendar permission."
        }
      } catch {
        errorMessage = "Error requesting calendar permission: \(error.localizedDescription)"
      }
    } else {
      print("Calendar permission already authorized.")
    }

    // Request Reminders permission
    let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
    if reminderStatus != .authorized {
      do {
        let granted = try await eventStore.requestAccess(to: .reminder)
        print("Reminder permission granted: \(granted)")
        if !granted {
          errorMessage = "User denied reminder permission."
        }
      } catch {
        errorMessage = "Error requesting reminder permission: \(error.localizedDescription)"
      }
    } else {
      print("Reminder permission already authorized.")
    }

    // Update state
    checkPermissions()
    if hasCalendarPermission && hasReminderPermission {
      await fetchData()
    }
  }

  /// Checks current permissions for calendars and reminders.
  func checkPermissions() {
    let calendarStatus = EKEventStore.authorizationStatus(for: .event)
    let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)

    hasCalendarPermission = (calendarStatus == .authorized)
    hasReminderPermission = (reminderStatus == .authorized)

    print(
      "Calendar permission status: \(calendarStatus.rawValue) (authorized: \(hasCalendarPermission))"
    )
    print(
      "Reminder permission status: \(reminderStatus.rawValue) (authorized: \(hasReminderPermission))"
    )
  }

  /// Fetches events (for the selected date) and reminders (all incomplete), updating published properties.
  func fetchData() async {
    // Fetch events for the selected date
    do {
      let events = try await calendarService.fetchEvents(for: selectedDate)
      self.events = events
    } catch {
      self.errorMessage = "Failed to fetch events: \(error.localizedDescription)"
      self.events = []
    }

    // Fetch reminders
    do {
      let reminders = try await reminderService.fetchReminders()
      self.reminders = reminders
    } catch {
      self.errorMessage = "Failed to fetch reminders: \(error.localizedDescription)"
      self.reminders = []
    }
  }

  /// Changes the selected date and fetches data for it.
  func changeSelectedDate(to newDate: Date) {
    previousDate = selectedDate
    selectedDate = newDate
    Task {
      await fetchData()
    }
  }

  // ... rest of your code ...
}
