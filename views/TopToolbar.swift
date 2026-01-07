//
//  TopToolbar.swift
//  MenuCal
//
//  Created by Saketh Vejendla on 19/12/25.
//

import SwiftUI
import AppKit


struct TopToolbar: View {
  @State private var mode: ToolbarMode = .toolbar

  enum ToolbarMode: Hashable {
    case events, search, toolbar
  }

  var body: some View {
    GlassEffectContainer {
      switch mode {
      case .events:
        EventsMenu(onCollapse: { withAnimation(.spring) { mode = .toolbar } })
          .glassEffect(in: RoundedRectangle(cornerRadius: 16.0))
          .glassEffectTransition(.matchedGeometry)
      case .search:
        Search(onClose: { withAnimation(.spring) { mode = .toolbar } })
          .padding(2)
          .glassEffect(in: Capsule())
          .glassEffectTransition(.matchedGeometry)
      case .toolbar:
        Toolbar(
          onExpand: { withAnimation(.spring) { mode = .events } },
          onSearch: { withAnimation(.spring) { mode = .search } }
        )
        .padding(2)
        .glassEffect(in: Capsule())
        .glassEffectTransition(.matchedGeometry)
      }
    }
  }
}

struct EventsMenu: View {
  @Environment(AppViewModel.self) private var appVM

  var onCollapse: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Group {
        Button(action: { selectEventsView(.timeline) }) {
          HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark")
              .font(.system(size: 8))
              .opacity(appVM.selectedEventsView == .timeline ? 1 : 0)
            Image(systemName: "calendar.day.timeline.left").font(.system(size: 12))
            Text("Timeline")
            Spacer()
          }
          .padding(4)
          .frame(maxWidth: ViewConstants.appWidth/2.2)
        }
        .interactiveButtonBackground()

        Button(action: { selectEventsView(.list) }) {
          HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark")
              .font(.system(size: 8))
              .opacity(appVM.selectedEventsView == .list ? 1 : 0)
            Image(systemName: "list.dash").font(.system(size: 12))
            Text("Events")
            Spacer()
          }
          .padding(4)
          .frame(maxWidth: ViewConstants.appWidth/2.2)
        }
        .interactiveButtonBackground()
      }
      .padding(4)

    }
    .padding(2)
  }

  private func selectEventsView(_ selection: CalViewMode) {
    appVM.selectedEventsView = selection
    onCollapse()
  }
}


struct Search: View {
  var onClose: () -> Void

  @State private var searchText: String = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .font(.system(size: 14))

      TextField("Search", text: $searchText)
        .textFieldStyle(.plain)
        .focused($isFocused)
        .frame(height: 20)
        .padding(0)
        .lineLimit(1)
        .lineSpacing(0)
        .offset(y: 0)

      Button(action: onClose) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
          .font(.system(size: 14))
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 8)
    .onAppear {
      isFocused = true
    }
  }
}

struct Toolbar: View {
  @Environment(AppViewModel.self) private var appVM

  var onExpand: () -> Void
  var onSearch: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      Group {
        Button(action: onExpand) {
          Image(systemName: appVM.getEventsViewSymbol())
            .font(.system(size: 14))
            .padding(6)
        }
        .interactiveButtonBackground()

        Button(action: onSearch) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 14))
            .padding(6)
        }
        .interactiveButtonBackground()

        Button(action: {
          NSWorkspace.shared.launchApplication(withBundleIdentifier: "com.apple.iCal", options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)
        }) {
          Image(systemName: "plus")
            .font(.system(size: 14))
            .padding(6)
        }
        .interactiveButtonBackground()
      }
    }
  }
}


func getEventsViewSymbol(_ eventsView: CalViewMode) -> String {
  return switch eventsView {
  case .list:
    "list.dash"
  case .timeline:
    "calendar.day.timeline.left"
  }
}

#Preview {
  TopToolbar()
    .environment(PermsAllowedViewModel() as PermissionsViewModel)
    .environment(AppViewModel())
    .frame(width: ViewConstants.appWidth)
    .padding()
}
