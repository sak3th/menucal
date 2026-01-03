//
//  ResponseButton.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 29/12/25.
//

import SwiftUI
import AppKit

struct ResponseButton: View {
  let title: String
  let color: Color
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background {
          if isSelected {
            Capsule()
              .fill(color)
          }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { inside in
      if inside { NSCursor.pointingHand.push() }
      else { NSCursor.pop() }
    }
  }
}

#Preview {
  HStack {
    ResponseButton(title: "Accept", color: .green, isSelected: true) { print("Accepted") }
    ResponseButton(title: "Maybe", color: .orange, isSelected: false) { print("Maybe") }
    ResponseButton(title: "Decline", color: .red, isSelected: false) { print("Declined") }
  }
  .frame(height: 36)
  .padding()
}
