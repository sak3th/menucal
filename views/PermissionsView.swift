import SwiftUI

struct PermissionsView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .foregroundColor(.accentColor)

            Text("Permission Needed")
                .font(.title2)
                .fontWeight(.semibold)

            Text("MenuCal needs access to your Calendars and Reminders. Please grant permission to continue.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button {
                requesting = true
                Task {
                    await viewModel.requestPermissions()
                    requesting = false
                }
            } label: {
                if requesting {
                    ProgressView().padding(.horizontal)
                } else {
                    Text("Request Permissions")
                        .font(.headline)
                        .padding(.horizontal)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
