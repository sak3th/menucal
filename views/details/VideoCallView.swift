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
            }) {
              Text("Join")
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .interactiveButtonBackground()
            .glassEffect(.clear.interactive(), in: Capsule())
            
            ShareLink(item: videoLink) {
              Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14))
                .padding(6)
            }
            .buttonStyle(.plain)
            .interactiveButtonBackground()
            .glassEffect(.clear.interactive(), in: Circle())
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
