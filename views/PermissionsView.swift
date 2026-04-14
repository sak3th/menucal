import SwiftUI

struct PermissionsView: View {
    @Environment(PermissionsViewModel.self) private var permissionsVM

    var body: some View {
      ContentUnavailableView {
        Label("Need permissions", systemImage: "calendar.badge.lock")
      } description: {
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
      } actions: {
        Button("Grant Access") {
          Task { await permissionsVM.requestPermissions() }
        }
        .glassEffect()
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
