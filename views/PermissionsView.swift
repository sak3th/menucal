import SwiftUI

struct PermissionsView: View {
    @Environment(PermissionsViewModel.self) private var permissionsVM

    var body: some View {
      ContentUnavailableView {
        Label("Calendar & Reminder Access", systemImage: "calendar.badge.lock")
      } description: {
        VStack(spacing: 12) {
          Text("MenuCal needs access to your calendars and reminders to display your events.")
            .multilineTextAlignment(.center)

          VStack(alignment: .leading, spacing: 4) {
            Label(
              "Calendar",
              systemImage: permissionsVM.hasCalendarPermission ? "checkmark.circle.fill" : "circle"
            )
            Label(
              "Reminders",
              systemImage: permissionsVM.hasReminderPermission ? "checkmark.circle.fill" : "circle"
            )
          }
          .font(.callout)
        }
      } actions: {
        if permissionsVM.isRequestingPermissions {
          ProgressView()
            .controlSize(.small)
        } else if permissionsVM.hasUngrantedRequestable {
          Button("Grant Access") {
            Task { await permissionsVM.requestPermissions() }
          }
          .glassEffect()
        }

        if permissionsVM.allDenied {
          VStack(spacing: 8) {
            Text("Permissions were denied. Please enable them in System Settings.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
            Button("Open System Settings") {
              permissionsVM.openSystemSettings()
            }
            .glassEffect()
          }
        }
      }
      .padding(.vertical, 32)
    }
}

#Preview {
  AppView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth, height: 700)
}
