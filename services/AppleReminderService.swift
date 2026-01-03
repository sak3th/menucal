import Foundation
import EventKit

// Concrete implementation of the ReminderService protocol for Apple's EventKit.
class AppleReminderService: ReminderService {
    private let eventStore = EKEventStore()

    /// Requests access to the user's reminders.
    /// Throws an error if access is denied or restricted.
    private func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        switch status {
        case .notDetermined:
            // The system will prompt the user for access.
            #if compiler(>=5.9)
                if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
                    let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                        eventStore.requestFullAccessToReminders { granted, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: granted)
                            }
                        }
                    }
                    if !granted {
                        throw ReminderAccessError.denied
                    }
                } else {
                    let granted = try await eventStore.requestAccess(to: .reminder)
                    if !granted {
                        throw ReminderAccessError.denied
                    }
                }
            #else
                let granted = try await eventStore.requestAccess(to: .reminder)
                if !granted {
                    throw ReminderAccessError.denied
                }
            #endif
        case .restricted:
            throw ReminderAccessError.restricted
        case .denied:
            throw ReminderAccessError.denied
        case .authorized:
            // Access already granted.
            break
        case .fullAccess:
          // Access already granted.
          break
        case .writeOnly:
          // Access already granted.
          break
        @unknown default:
            throw ReminderAccessError.unknown
        }
    }

    func fetchReminders() async throws -> [Reminder] {
        try await requestAccess()

        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)

        // EventKit's reminder fetch is completion-handler based, so we wrap it in an async call.
        let ekReminders = try await eventStore.fetchReminders(matching: predicate)

        return ekReminders.map { ekReminder in
            Reminder(
                id: ekReminder.calendarItemIdentifier,
                title: ekReminder.title,
                isCompleted: ekReminder.isCompleted,
                dueDate: ekReminder.dueDateComponents?.date
            )
        }
    }
}

// Custom error for handling reminder access issues.
enum ReminderAccessError: Error {
    case denied
    case restricted
    case unknown
}

// Async wrapper for the EventKit completion handler.
extension EKEventStore {
    func fetchReminders(matching predicate: NSPredicate) async throws -> [EKReminder] {
        try await withCheckedThrowingContinuation { continuation in
            fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "EKEventStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders."]))
                }
            }
        }
    }
}
