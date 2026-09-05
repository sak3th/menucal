//
//  GoogleAccountsView.swift
//  MenuCal
//

import SwiftUI

// One row per Google account, rather than a single unattributed "Connect
// Google" button. A grant covers one address, so asking once can only ever
// fix one account — and asking before we know what is on the Mac asks people
// with no Google account at all.
struct GoogleAccountRows: View {
  let accounts: [CalendarAccount]
  /// Starting the flow: Settings can't do it itself — the popover dismisses
  /// the moment the browser takes focus — so it hands the address to the
  /// setup window, which outlives the switch.
  let connect: (String) -> Void

  @Environment(GoogleAuth.self) private var auth

  var body: some View {
    let rows = accounts.map(\.email) + orphaned
    ForEach(Array(rows.enumerated()), id: \.element) { index, email in
      if index > 0 { Divider().padding(.leading, 12) }
      row(for: email)
    }
  }

  // An account can be removed from Internet Accounts while its grant is still
  // in the keychain. Without a row for it there would be no way to disconnect
  // it, and Google would keep a live token for a calendar MenuCal no longer
  // reads.
  private var orphaned: [String] {
    let known = Set(accounts.map(\.email))
    return auth.accounts.filter { !known.contains($0) }.sorted()
  }

  private func row(for email: String) -> some View {
    HStack(spacing: 8) {
      Text(email)
        .font(.system(size: 13))
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 8)
      // A spinner in the switch's place while the browser round-trip runs.
      // The grant doesn't land until Google calls back, so the switch would
      // otherwise sit visibly off after being turned on, then snap across —
      // a toggle that won't stay where you put it.
      if auth.connecting == email {
        ProgressView().controlSize(.small)
      } else {
        Toggle("", isOn: binding(for: email))
          .labelsHidden()
          .toggleStyle(.switch)
          .controlSize(.mini)
          // A second flow would cancel the first one's listener out from under it.
          .disabled(auth.connecting != nil)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    // Deliberately no row-wide tap target, unlike the preference toggles this
    // sits beside: those flip a local setting, this one launches a browser or
    // revokes a grant, and both deserve a deliberate hit on the control.
  }

  private func binding(for email: String) -> Binding<Bool> {
    Binding(
      get: { auth.isConnected(email) },
      set: { isOn in
        if isOn { connect(email) } else { auth.disconnect(email: email) }
      }
    )
  }
}
