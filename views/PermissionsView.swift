import AppKit
import SwiftUI

struct PermissionsView: View {
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(spacing: 12) {
      Text("MenuCal needs access to your calendar.")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      // Granting happens in the setup window: the request can send the user to
      // System Settings, and this popover closes the moment another app
      // becomes active, which would strand them mid-flow.
      Button("Continue Setup") {
        openWindow(id: OnboardingStep.windowID)
        NSApp.activate(ignoringOtherApps: true)
      }
      .glassEffect()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
  }
}

#Preview {
  AppView()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .environment(EventsViewModel())
    .frame(width: ViewConstants.appWidth, height: 700)
}
