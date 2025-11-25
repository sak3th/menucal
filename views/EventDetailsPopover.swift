import SwiftUI

struct EventDetailsPopover: View {
  let event: Event
  @Environment(\.dismiss) private var dismiss
  @State private var isHoveringVideoCall = false
  @State private var isHoveringShare = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Row 1: Calendar info with colored circle
      HStack(spacing: 6) {
        Circle()
          .fill(event.calendarColor)
          .frame(width: 8, height: 8)

        Text(event.calendarTitle)
          .font(.subheadline)
          .foregroundColor(.secondary)

        Text(event.calendarSource)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.bottom, 4)

      // Row 2: Event title
      Text(event.title)
        .font(.body)
        .fontWeight(.medium)
        .fixedSize(horizontal: false, vertical: true)

      Spacer().frame(height: 16)

      // Row 3: Date and time
      HStack {
        Text(formatDateOnly(event.startTime))
          .font(.default)

        Spacer()

        if !event.isAllDay {
          Text("\(formatTime(event.startTime)) – \(formatTime(event.endTime))")
            .font(.subheadline)
            .foregroundColor(.secondary)
        } else {
          Text("All day")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }

      // Row 4: Recurrence info
      if event.isRecurring, let rule = event.recurrenceRule {
        Text(rule.description)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .padding(.top, 2)
      }

      // Row 5: Video call info
      if let videoLink = event.videoCallLink {
        Spacer().frame(height: 16)

        HStack(spacing: 6) {
          HStack(spacing: 6) {
            Text(videoCallServiceName(from: videoLink))
              .font(.body)
              .fontWeight(.medium)

            //            Image(systemName: videoIconName(from: videoLink))
            //                .font(.body)
            //                .foregroundColor(.blue)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(isHoveringVideoCall ? Color.primary.opacity(0.2) : Color.clear)
          )
          .offset(x: -8, y: -4)
          //.contentShape(Rectangle())
          .onTapGesture {
            openURL(videoLink)
          }
          .onHover { hovering in
            isHoveringVideoCall = hovering
          }

          Spacer()

          // Share button with manual share sheet trigger
          Button(action: {
            shareURL(videoLink)
          }) {
            Image(systemName: "square.and.arrow.up")
              .font(.body)
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
          .focusable(false)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            Capsule()
              .fill(isHoveringShare ? Color.primary.opacity(0.2) : .clear)
          )
          .help("Share link")
          .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
              isHoveringShare = hovering
            }
          }
          .offset(y: -6)
        }
        .frame(alignment: .center)
      }

      // Row 6: Location info
      //      if let location = event.location, !location.isEmpty {
      //        Spacer().frame(height: 16)
      //
      //        HStack {
      //          Text(location)
      //            .font(.subheadline)
      //            .foregroundColor(.secondary)
      //            .fixedSize(horizontal: false, vertical: true)
      //
      //          Spacer()
      //        }
      //      }

      // Row 7: Attendees
      if !event.attendees.isEmpty {
        Spacer().frame(height: 8)

        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 4) {
            Text("Attendees")
              .font(.subheadline)

            Text("(\(event.attendees.count))")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }

          VStack(alignment: .leading, spacing: 6) {
            ForEach(groupedAndSortedAttendees()) { attendee in
              HStack(spacing: 4) {
                Image(systemName: attendee.participationStatus.icon)
                  .font(.caption)
                  .foregroundColor(attendee.participationStatus.color)
                  .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                  HStack(spacing: 2) {
                    Text(attendee.displayName)
                      .font(.caption)

                    if attendee.isCurrentUser {
                      Text("(you)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                  }

                  //                    if let email = attendee.email, attendee.name != nil {
                  //                      Text(email)
                  //                        .font(.caption)
                  //                        .foregroundColor(.secondary)
                  //                    }
                }

                //                VStack(alignment: .leading, spacing: 2) {
                //                  HStack(spacing: 4) {
                //                    Text(attendee.displayName)
                //                      .font(.caption)
                //
                //                    if attendee.isCurrentUser {
                //                      Text("(you)")
                //                        .font(.caption)
                //                        .foregroundColor(.secondary)
                //                    }
                //                  }
                //
                //                  if let email = attendee.email, attendee.name != nil {
                //                    Text(email)
                //                      .font(.caption)
                //                      .foregroundColor(.secondary)
                //                  }
                //                }

                Spacer()
              }
            }
          }
          .padding(.leading, 0)
        }
      }

      // Row 8: Acceptance status
      if !event.attendees.isEmpty {
        Spacer().frame(height: 16)

        HStack(spacing: 6) {
          Image(systemName: event.participationStatus.icon)
            .font(.caption)
            .foregroundColor(event.participationStatus.color)

          Text(event.participationStatus.rawValue)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }

      // Notes section (if present)
      if let notes = event.notes, !notes.isEmpty {
        Spacer().frame(height: 16)

        Text(notes)
          .font(.caption)
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding()
    .frame(width: 280)
    //.background(Color(NSColor.controlBackgroundColor))
  }

  // MARK: - Helper Methods

  private func groupedAndSortedAttendees() -> [Participant] {
    let order: [ParticipationStatus] = [.accepted, .declined, .tentative, .pending, .unknown]

    return event.attendees.sorted { attendee1, attendee2 in
      let index1 = order.firstIndex(of: attendee1.participationStatus) ?? order.count
      let index2 = order.firstIndex(of: attendee2.participationStatus) ?? order.count

      if index1 != index2 {
        return index1 < index2
      }

      // Within the same status group, sort alphabetically by name
      return attendee1.displayName.localizedCaseInsensitiveCompare(attendee2.displayName)
        == .orderedAscending
    }
  }

  private func formatDateOnly(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMM d"
    return formatter.string(from: date)
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter.string(from: date)
  }

  private func videoCallServiceName(from url: URL) -> String {
    let host = url.host?.lowercased() ?? ""
    if host.contains("zoom.us") { return "Zoom" }
    if host.contains("meet.google.com") { return "Google Meet" }
    if host.contains("teams.microsoft.com") { return "Teams" }
    if host.contains("webex.com") { return "Webex" }
    if host.contains("gotomeeting.com") { return "GoToMeeting" }
    if host.contains("bluejeans.com") { return "BlueJeans" }
    if host.contains("whereby.com") { return "Whereby" }
    return "Video Call"
  }

  private func videoIconName(from url: URL) -> String {
    let host = url.host?.lowercased() ?? ""
    if host.contains("zoom.us") { return "video.fill" }
    if host.contains("meet.google.com") { return "video.fill" }
    if host.contains("teams.microsoft.com") { return "video.fill" }
    return "video.fill"
  }

  private func openURL(_ url: URL) {
    NSWorkspace.shared.open(url)
  }

  private func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }

  private func shareURL(_ url: URL) {
    let picker = NSSharingServicePicker(items: [url])
    if let view = NSApp.keyWindow?.contentView {
      picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
    }
  }
}

// MARK: - Preview

#Preview {
  EventDetailsPopover(
    event: Event(
      id: "1",
      title: "Team Standup Meeting",
      startTime: Date(),
      endTime: Date().addingTimeInterval(3600),
      isAllDay: false,
      calendarColor: .blue,
      location: "Conference Room A, Building 2",
      notes:
        "Please review the sprint board before the meeting.\n\nAgenda:\n1. Yesterday's progress\n2. Today's plans\n3. Blockers",
      url: URL(string: "https://zoom.us/j/123456789"),
      isRecurring: true,
      recurrenceRule: RecurrenceRule(
        frequency: .daily,
        interval: 1,
        endDate: nil,
        occurrenceCount: nil
      ),
      organizer: Participant(
        id: "org1",
        name: "John Doe",
        email: "john@example.com",
        isCurrentUser: false,
        participationStatus: .accepted
      ),
      attendees: [
        Participant(
          id: "att1",
          name: "Jane Smith",
          email: "jane@example.com",
          isCurrentUser: true,
          participationStatus: .accepted
        ),
        Participant(
          id: "att2",
          name: "Bob Wilson",
          email: "bob@example.com",
          isCurrentUser: false,
          participationStatus: .accepted
        ),
        Participant(
          id: "att3",
          name: "Alice Cooper",
          email: "alice@example.com",
          isCurrentUser: false,
          participationStatus: .tentative
        ),
        Participant(
          id: "att4",
          name: "David Lee",
          email: "david@example.com",
          isCurrentUser: false,
          participationStatus: .declined
        ),
      ],
      participationStatus: .accepted,
      calendarTitle: "Work Calendar",
      calendarSource: "iCloud"
    )
  )
  .frame(width: 400, height: 600)
}
