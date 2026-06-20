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
    let parts = splitNotes(event.notes ?? "")

    VStack(spacing: 0) {
      if !parts.description.isEmpty {
        Spacer().frame(height: 16)
        DetailSection {
          ScrollView {
            AttributedTextView(attributed: attributed(parts.description))
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxHeight: ViewConstants.appWidth)
        }
      }

      if let conference = parts.conference, !conference.isEmpty {
        Spacer().frame(height: 16)
        DetailSection {
          AttributedTextView(attributed: linkified(conference))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  // MARK: - Splitting

  // Separates the free-text description from the provider's auto-generated
  // conference block (the region fenced by "-::~:~::…::-" delimiter lines).
  private func splitNotes(_ raw: String) -> (description: String, conference: String?) {
    guard !raw.isEmpty else { return ("", nil) }
    var description = raw
    var conference: String? = nil

    let fencedBlock = "(?ms)^[-:~_= ]{10,}$.*?^[-:~_= ]{10,}$"
    if let regex = try? NSRegularExpression(pattern: fencedBlock),
       let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
       let range = Range(match.range, in: raw) {
      let block = cleanConferenceBlock(String(raw[range]))
      conference = block.isEmpty ? nil : block
      description.removeSubrange(range)
    }

    return (cleanDescription(description), conference)
  }

  private func cleanConferenceBlock(_ text: String) -> String {
    var s = stripSeparatorLines(text)
    s = s.replacingOccurrences(of: "Please do not edit this section.", with: "")
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func cleanDescription(_ text: String) -> String {
    var s = stripSeparatorLines(text)
    for artifact in ["~:~", "(:~)", "<br>~:~<br>"] {
      s = s.replacingOccurrences(of: artifact, with: "")
    }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func stripSeparatorLines(_ text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: "(?m)^[-:~_= ]{3,}$") else { return text }
    return regex.stringByReplacingMatches(
      in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
  }

  // MARK: - Rendering

  // Google sends plain-text descriptions (newlines as \n); Exchange/Outlook
  // send HTML. Parse HTML through the HTML engine, otherwise keep plain text
  // (line breaks intact) and auto-link URLs / phone numbers.
  private func attributed(_ cleaned: String) -> NSAttributedString {
    looksLikeHTML(cleaned) ? convertHTML(cleaned) : linkified(cleaned)
  }

  private func looksLikeHTML(_ s: String) -> Bool {
    let lower = s.lowercased()
    return lower.contains("<br") || lower.contains("<p>") || lower.contains("<p ")
      || lower.contains("<div") || lower.contains("<a ") || lower.contains("<ul")
      || lower.contains("<ol") || lower.contains("<span") || lower.contains("&nbsp;")
  }

  private func linkified(_ text: String) -> NSAttributedString {
    let ns = NSMutableAttributedString(string: text)
    let full = NSRange(location: 0, length: ns.length)
    ns.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: full)
    ns.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)

    let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber]
    if let detector = try? NSDataDetector(types: types.rawValue) {
      for match in detector.matches(in: text, range: full) {
        var url: URL?
        if match.resultType == .link {
          url = match.url
        } else if match.resultType == .phoneNumber, let phone = match.phoneNumber {
          url = URL(string: "tel:" + phone.filter { !$0.isWhitespace })
        }
        guard let url else { continue }
        ns.addAttribute(.link, value: url, range: match.range)
      }
    }
    return ns
  }

  private func convertHTML(_ html: String) -> NSAttributedString {
    guard let data = html.data(using: .utf8) else {
      return NSAttributedString(string: html)
    }
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

      // Enforce System Font while preserving traits.
      text.enumerateAttribute(.font, in: fullRange) { value, range, _ in
        var newFont = NSFont.systemFont(ofSize: 13)
        if let currentFont = value as? NSFont {
          let traits = currentFont.fontDescriptor.symbolicTraits
          var newTraits: NSFontDescriptor.SymbolicTraits = []
          if traits.contains(.bold) { newTraits.insert(.bold) }
          if traits.contains(.italic) { newTraits.insert(.italic) }
          if !newTraits.isEmpty {
            let descriptor = newFont.fontDescriptor.withSymbolicTraits(newTraits)
            if let f = NSFont(descriptor: descriptor, size: 0) { newFont = f }
          }
        }
        text.addAttribute(.font, value: newFont, range: range)
      }

      // Adaptive label color for non-link runs.
      text.enumerateAttribute(.link, in: fullRange) { value, range, _ in
        if value == nil {
          text.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
        }
      }
      return text
    } catch {
      return NSAttributedString(string: html)
    }
  }
}

// Read-only text that is both selectable and has clickable links, and
// preserves newlines — none of which SwiftUI's Text can do all at once.
struct AttributedTextView: NSViewRepresentable {
  let attributed: NSAttributedString

  func makeNSView(context: Context) -> NSTextView {
    let view = NSTextView()
    view.isEditable = false
    view.isSelectable = true
    view.drawsBackground = false
    view.textContainerInset = .zero
    view.textContainer?.lineFragmentPadding = 0
    view.textContainer?.widthTracksTextView = true
    view.isVerticallyResizable = true
    view.isHorizontallyResizable = false
    view.linkTextAttributes = [
      .foregroundColor: NSColor.linkColor,
      .underlineStyle: NSUnderlineStyle.single.rawValue,
      .cursor: NSCursor.pointingHand
    ]
    return view
  }

  func updateNSView(_ view: NSTextView, context: Context) {
    view.textStorage?.setAttributedString(attributed)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
    let width = proposal.width ?? 250
    guard let container = nsView.textContainer, let manager = nsView.layoutManager else {
      return nil
    }
    container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    manager.ensureLayout(for: container)
    let height = manager.usedRect(for: container).height
    return CGSize(width: width, height: ceil(height))
  }
}

#Preview {
  NotesView(event: SampleEvent.event)
    .padding()
}
