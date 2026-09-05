//
//  GoogleAccountsView.swift
//  MenuCal
//

import SwiftUI

// One row per Google account EventKit knows about, rather than a single
// unattributed "Connect Google" button. A grant covers one address, so
// asking once can only ever fix one account — and asking before we know what
// is on the Mac asks people with no Google account at all.
struct GoogleAccountRows: View {
  let accounts: [CalendarAccount]
  /// Starting the flow: Settings can't do it itself — the popover dismisses
  /// the moment the browser takes focus — so it hands the account to the
  /// setup window, which outlives the switch.
  let connect: (CalendarAccount) -> Void

  @Environment(GoogleAuth.self) private var auth

  var body: some View {
    let rows = accounts + orphaned
    ForEach(Array(rows.enumerated()), id: \.element.id) { index, account in
      if index > 0 { Divider().padding(.leading, 12) }
      row(for: account)
    }
  }

  // An account can be removed from Internet Accounts while its grant is still
  // in the keychain. Without a row for it there would be no way to disconnect
  // it, and Google would keep a live token for a calendar MenuCal no longer
  // reads.
  private var orphaned: [CalendarAccount] {
    let known = Set(accounts.compactMap { auth.resolvedEmail(for: $0) })
    return auth.accounts.keys.sorted()
      .filter { !known.contains($0) }
      .map { CalendarAccount(id: $0, title: $0, email: $0) }
  }

  @ViewBuilder
  private func row(for account: CalendarAccount) -> some View {
    // Once connected, prefer the address Google confirmed: an account whose
    // calendars were all renamed has no address until then.
    let connected = auth.resolvedEmail(for: account)

    HStack(spacing: 8) {
      Text(connected ?? account.email ?? account.title)
        .font(.system(size: 13))
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 8)
      trailing(for: account, connected: connected)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private func trailing(for account: CalendarAccount, connected: String?) -> some View {
    if auth.connecting?.id == account.id {
      ProgressView().controlSize(.small)
    } else if let email = connected {
      HStack(spacing: 8) {
        Text("Connected")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.green)
        Button("Disconnect") { auth.disconnect(email: email) }
          .font(.system(size: 12))
          .buttonStyle(.borderless)
      }
    } else {
      Button("Connect") { connect(account) }
        .font(.system(size: 12))
        .buttonStyle(.borderless)
        // A second flow would cancel the first one's listener out from under it.
        .disabled(auth.connecting != nil)
    }
  }
}
