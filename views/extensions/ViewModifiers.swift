//
//  ViewModifiers.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 20/12/25.
//

import SwiftUI


struct SingleLineCenteredText: ViewModifier {
  func body(content: Content) -> some View {
    content
      .lineLimit(1)
      .truncationMode(.tail)
      .frame(maxHeight: .infinity)
      .frame(alignment: .center)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct InteractiveButtonBackgroundModifier: ViewModifier {
  @State private var isHovered: Bool = false
  
  let hoverBackgroundColor: Color
  
  func body(content: Content) -> some View {
    content
      .buttonStyle(InteractiveButtonStyle(
        isHovered: isHovered,
        hoverBackgroundColor: hoverBackgroundColor
      ))
      .onHover { hovered in
        self.isHovered = hovered
      }
  }
}

struct InteractiveButtonStyle: ButtonStyle {
  let isHovered: Bool
  let hoverBackgroundColor: Color
  
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        isHovered || configuration.isPressed ? hoverBackgroundColor : Color.clear
      )
      .clipShape(.capsule(style: .circular))
      .brightness(configuration.isPressed ? 0.15 : 0.0)
      .animation(.easeOut(duration: 0.15), value: isHovered)
      .animation(.easeOut(duration: 0.05), value: configuration.isPressed)
  }
}


struct NativeInteractiveButtonBackgroundModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .buttonStyle(.accessoryBar)
      .buttonBorderShape(.capsule)
  }
}

// MARK: - Extension for easier use

extension View {
  func interactiveButtonBackground(hoverColor color: Color = Color.gray.opacity(0.3)) -> some View {
    self.modifier(InteractiveButtonBackgroundModifier(hoverBackgroundColor: color))
    //self.modifier(NativeInteractiveButtonBackgroundModifier())
  }

  func singleLineCenteredText() -> some View {
    self.modifier(SingleLineCenteredText())
  }
}



extension Date {
  /// Returns a localized time string with customized font sizes for the time and AM/PM symbol.
  func formattedTime(timeSize: CGFloat, amPmSize: CGFloat) -> AttributedString {
    let timeString = self.formatted(date: .omitted, time: .shortened)
    var attributedString = AttributedString(timeString)

    attributedString.font = .system(size: timeSize)

    let formatter = DateFormatter()
    formatter.locale = .current
    let symbols = [formatter.amSymbol, formatter.pmSymbol].compactMap { $0 }

    for symbol in symbols {
      if let range = attributedString.range(of: symbol) {
        attributedString[range].font = .system(size: amPmSize)
        //attributedString[range].foregroundColor = .secondary // Fades the AM/PM slightly
      }
    }
    
    return attributedString
  }
}



