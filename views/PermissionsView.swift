import SwiftUI

struct PermissionsView: View {

    var body: some View {
      ContentUnavailableView {
        Label("Need permissions", systemImage: "calendar.badge.lock")
      } description: {
        Text("Calendar and reminders will appear here.")
      } actions: {
        Button("Request") {

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
