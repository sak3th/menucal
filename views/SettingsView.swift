//
//  SettingsView.swift
//  MenuCal
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
  @Environment(SettingsViewModel.self) private var settings
  @Environment(AppViewModel.self) private var appVM
  var maxContentHeight: CGFloat

  @State private var contentHeight: CGFloat = 0

  var body: some View {
    @Bindable var settings = settings

    ScrollView {
      VStack(alignment: .leading, spacing: 18) {

          // MARK: Add Event Button
          SettingsSection("Add Event Opens") {
            ForEach(AddEventAction.allCases, id: \.self) { action in
              SettingsChoiceRow(
                label: action.label,
                isSelected: settings.addEventAction == action
              ) {
                settings.addEventAction = action
              }
            }

            if settings.addEventAction == .webApp {
              VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                  TextField("/Applications/GCal.app", text: $settings.webAppPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                  Button("Choose…") { chooseWebApp() }
                    .font(.system(size: 12))
                    .buttonStyle(.borderless)
                }
                Text("Leave blank to auto-detect a Google Calendar web app.")
                  .font(.system(size: 10))
                  .foregroundStyle(.tertiary)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
            }
          }

          // MARK: Window Size
          SettingsSection("Window Size") {
            ForEach(WindowSize.allCases, id: \.self) { size in
              SettingsChoiceRow(
                label: size.label,
                isSelected: settings.windowSize == size
              ) {
                settings.windowSize = size
                appVM.updateAppHeight(for: NSApp.keyWindow?.screen, fraction: settings.fraction)
              }
            }
          }

          // MARK: Behavior
          SettingsSection("Behavior") {
            SettingsToggleRow("Dismiss after joining a call", isOn: $settings.dismissAfterJoin)
            SettingsToggleRow("Reset to Today on reopen", isOn: $settings.resetToTodayOnReopen)
            SettingsToggleRow("Launch at login", isOn: $settings.launchAtLogin)
          }

          // MARK: Keyboard Shortcuts
          SettingsSection("Keyboard Shortcuts") {
            VStack(alignment: .leading, spacing: 10) {
              ForEach(Self.shortcuts, id: \.desc) { shortcut in
                HStack(spacing: 10) {
                  HStack(spacing: 4) {
                    ForEach(shortcut.keys, id: \.self) { key in
                      KeyCap(label: key)
                    }
                  }
                  .frame(width: 96, alignment: .leading)
                  Text(shortcut.desc)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                  Spacer(minLength: 0)
                }
              }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
          }
        }
        .padding(14)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
      }
      .frame(height: min(contentHeight == 0 ? maxContentHeight : contentHeight, maxContentHeight))
      .scrollIndicators(.hidden)
  }

  private func chooseWebApp() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.application]
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default
      .homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    if panel.runModal() == .OK, let url = panel.url {
      settings.webAppPath = url.path
    }
  }

  private static let shortcuts: [(keys: [String], desc: String)] = [
    (["←", "→"], "Previous / next day"),
    (["⌥", "←", "→"], "Previous / next month"),
    ([",", "."], "Previous / next week"),
    (["T"], "Jump to today"),
    (["M"], "Toggle Month / Week"),
    (["E"], "Toggle Timeline / List"),
    (["esc"], "Close detail or menu"),
  ]
}

private struct KeyCap: View {
  let label: String

  var body: some View {
    Text(label)
      .font(.system(size: 11, weight: .medium, design: .rounded))
      .foregroundStyle(.primary)
      .frame(minWidth: 14)
      .padding(.horizontal, 6)
      .padding(.vertical, 4)
      .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
      )
  }
}

// MARK: - Building blocks

struct SettingsSection<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.leading, 4)

      VStack(spacing: 0) {
        content
      }
      .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
  }
}

private struct SettingsChoiceRow: View {
  let label: String
  let isSelected: Bool
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack {
        Text(label)
          .font(.system(size: 13, weight: .regular))
          .foregroundStyle(.primary)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tint)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .contentShape(Rectangle())
      .background(hovering ? Color.primary.opacity(0.05) : Color.clear)
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private struct SettingsToggleRow: View {
  let label: String
  @Binding var isOn: Bool

  init(_ label: String, isOn: Binding<Bool>) {
    self.label = label
    self._isOn = isOn
  }

  var body: some View {
    HStack {
      Text(label).font(.system(size: 13, weight: .regular))
      Spacer(minLength: 8)
      Toggle("", isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.mini)
    }
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    .onTapGesture { isOn.toggle() }
  }
}
