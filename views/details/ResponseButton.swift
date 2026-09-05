//
//  ResponseButton.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 29/12/25.
//

import SwiftUI
import AppKit

// One segment of the response control. The selected capsule is drawn with a
// shared matchedGeometryEffect id so it slides between segments instead of
// popping — the same morph the toolbars get from glassEffectTransition.
struct ResponseButton: View {
  let title: String
  let color: Color
  let isSelected: Bool
  let namespace: Namespace.ID
  let action: () -> Void

  @Environment(\.self) private var environment

  var body: some View {
    Button(action: action) {
      ZStack {
        if isSelected {
          Capsule()
            .fill(color)
            .matchedGeometryEffect(id: "responseSelection", in: namespace)
        }
        Text(title)
        // .body, matching the Today button — a semantic font rather than a
        // hardcoded size, so both track the system text size together.
        .font(.body)
        .foregroundStyle(isSelected ? color.contrastingLabel(in: environment) : Color.primary)
      }
      .frame(maxWidth: .infinity)
      .frame(height: ViewConstants.toolbarHeight - 8)
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .onHover { inside in
      if inside { NSCursor.pointingHand.push() }
      else { NSCursor.pop() }
    }
  }
}

private extension Color {
  /// Black or white, whichever reads better on this fill once it has resolved
  /// for the current appearance. Saturated system colours keep white — the
  /// same thing `.borderedProminent` does in both light and dark — while a
  /// genuinely light tint flips to black instead of quietly losing contrast.
  func contrastingLabel(in environment: EnvironmentValues) -> Color {
    let c = resolve(in: environment)
    let luminance = 0.2126 * Double(c.linearRed)
                  + 0.7152 * Double(c.linearGreen)
                  + 0.0722 * Double(c.linearBlue)
    return luminance > 0.6 ? .black : .white
  }
}

#Preview {
  @Previewable @Namespace var ns
  HStack(spacing: 0) {
    ResponseButton(title: "Accept", color: .green, isSelected: true, namespace: ns) {}
    ResponseButton(title: "Maybe", color: .orange, isSelected: false, namespace: ns) {}
    ResponseButton(title: "Decline", color: .red, isSelected: false, namespace: ns) {}
  }
  .padding(4)
  .glassEffect(in: Capsule())
  .frame(width: 320)
  .padding()
}
