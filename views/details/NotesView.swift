//
//  NotesView.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 02/01/26.
//

import SwiftUI
import AppKit

struct NotesView: View {
  let event: Event

  var body: some View {
    if let notes = event.notes, !notes.isEmpty {
      VStack {
        Spacer().frame(height: 16)

        DetailSection {
          ScrollView {
            Text(convertHTML(notes))
              .font(.system(size: 13))
              .foregroundStyle(.primary)
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxHeight: ViewConstants.appWidth)
        }
      }
    }
  }

  // MARK: - Helpers

  private func convertHTML(_ html: String) -> AttributedString {
    let cleanedHTML = cleanProviderNotes(html)
    guard let data = cleanedHTML.data(using: .utf8) else { return AttributedString(cleanedHTML) }
    do {
      let nsAttrString = try NSAttributedString(
        data: data,
        options: [
          .documentType: NSAttributedString.DocumentType.html,
          .characterEncoding: String.Encoding.utf8.rawValue
        ],
        documentAttributes: nil
      )

      let text = NSMutableAttributedString(attributedString: nsAttrString)
      let fullRange = NSRange(location: 0, length: text.length)

      // Enforce System Font while preserving traits
      text.enumerateAttribute(.font, in: fullRange) { value, range, _ in
        var newFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)

        if let currentFont = value as? NSFont {
          let traits = currentFont.fontDescriptor.symbolicTraits
          var newTraits: NSFontDescriptor.SymbolicTraits = []

          if traits.contains(.bold) { newTraits.insert(.bold) }
          if traits.contains(.italic) { newTraits.insert(.italic) }

          if !newTraits.isEmpty {
            let descriptor = newFont.fontDescriptor.withSymbolicTraits(newTraits)
            if let f = NSFont(descriptor: descriptor, size: 0) { // 0 maintains default size
              newFont = f
            }
          }
        }
        text.addAttribute(.font, value: newFont, range: range)
      }

      // Ensure text color is adaptive (Label Color)
      text.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

      return AttributedString(text)
    } catch {
      return AttributedString(cleanedHTML)
    }
  }

  private func cleanProviderNotes(_ text: String) -> String {
    var cleaned = text

    // Pattern to match common calendar delimiter lines like "-::~:~::~:~:..."
    // Matches any sequence of 3 or more characters containing only -, :, ~, _, =
    let separatorPattern = "(?m)^[-:~_= ]{3,}$"

    // Remove specific Google/Exchange artifacts if they appear inline
    let specificArtifacts = ["~:~", "(:~)", "<br>~:~<br>"]

    if let regex = try? NSRegularExpression(pattern: separatorPattern, options: []) {
      cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
    }

    for artifact in specificArtifacts {
      cleaned = cleaned.replacingOccurrences(of: artifact, with: "")
    }

    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

#Preview {
  NotesView(event: SampleEvent.event)
    .padding()
}
