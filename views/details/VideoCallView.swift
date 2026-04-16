//
//  VideoCallView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 02/01/26.
//

import SwiftUI
import AppKit

struct VideoCallView: View {
  let event: Event
  @Environment(AppViewModel.self) private var appVM
  @State private var isJoinHovered = false
  @State private var isShareHovered = false

  var body: some View {
    if let videoLink = event.videoCallLink {
      VStack {
        Spacer().frame(height: 16)
        DetailSection {
          
          
          HStack(alignment: .center, spacing: 8) {
            Text(event.meetingProvider)
              .fontWeight(.light)
              .singleLineCenteredText()
            
            Spacer()
            
            Button(action: {
              NSWorkspace.shared.open(videoLink)
              appVM.selectedEvent = nil
            }) {
              Text("Join")
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .background(isJoinHovered ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15))
            .clipShape(Capsule())
            .onHover { inside in
              withAnimation(.easeOut(duration: 0.15)) { isJoinHovered = inside }
              if inside { NSCursor.pointingHand.push() }
              else { NSCursor.pop() }
            }

            ShareLink(item: videoLink) {
              Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14))
                .padding(6)
            }
            .buttonStyle(.plain)
            .background(isShareHovered ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15))
            .clipShape(Circle())
            .onHover { inside in
              withAnimation(.easeOut(duration: 0.15)) { isShareHovered = inside }
            }
          }
          .frame(height: 28)
        }
      }
    }
  }
}

#Preview {
  VideoCallView(event: SampleEvent.event)
    .padding()
}
