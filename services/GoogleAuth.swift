//
//  GoogleAuth.swift
//  MenuCal
//

import AppKit
import CryptoKit
import Foundation
import Network

// OAuth for the Google Calendar API, using the installed-app loopback flow
// (RFC 8252): PKCE plus a short-lived listener on 127.0.0.1. Google requires
// the system browser — embedded web views are rejected with
// `disallowed_useragent` — so the popover will dismiss during the flow. That's
// why this state is observable and the UI lives in a window that outlives it.
@Observable
@MainActor
final class GoogleAuth {
  static let shared = GoogleAuth()

  // One flow at a time, so this is global rather than per-account; which
  // account it belongs to is `connecting`. There is no `.connected` case —
  // being connected is a property of an account, not of the flow.
  enum Phase: Equatable {
    case idle
    case awaitingCallback
    case exchanging
    case failed(String)
  }

  private(set) var phase: Phase = .idle
  // Offered for copying: the default browser may be signed into the wrong
  // Google profile, and pasting is the only way to pick the right one.
  private(set) var authURL: URL?
  /// The address the in-flight flow was started for, so its row can show the
  /// progress instead of the whole list doing so.
  private(set) var connecting: String?

  /// Addresses with a live grant. One refresh token each, keyed by address in
  /// the keychain — the address is also how Google addresses the calendar we
  /// write the RSVP to.
  private(set) var accounts: Set<String> = []

  var isConnected: Bool { !accounts.isEmpty }

  func isConnected(_ email: String) -> Bool { accounts.contains(email.lowercased()) }

  /// Whether an RSVP as this address can be written rather than handed off.
  func canRespond(as email: String?) -> Bool { tokenAccount(for: email) != nil }

  /// The connected account that answers for an event's self-address. Exact
  /// match only, and never for a nil address: Google addresses the calendar
  /// *by* that address, so a token belonging to another account can't write
  /// the event regardless. Guessing — with a lone connected account, say —
  /// only claims a write that then fails, which flashes a status the rollback
  /// immediately takes back and hands off to the browser anyway.
  private func tokenAccount(for email: String?) -> String? {
    guard let email = email?.lowercased(), accounts.contains(email) else { return nil }
    return email
  }

  private static let accountsKey = "googleAccounts"
  private static let scope = "https://www.googleapis.com/auth/calendar.events openid email"

  // Pre-multi-account storage: a single refresh token under a fixed slot,
  // with the address in UserDefaults. Migrated on first launch, then gone.
  private static let legacyAccount = "primary"
  private static let legacyEmailKey = "googleAccountEmail"

  private var listener: NWListener?
  private var verifier = ""
  private var expectedState = ""
  // Held separately from authURL: the token exchange needs the same redirect
  // back, and authURL is cleared as soon as the callback lands.
  private var redirectURI = ""
  private var accessTokens: [String: (token: String, expiry: Date)] = [:]

  private init() {
    if let saved = UserDefaults.standard.stringArray(forKey: Self.accountsKey) {
      // Only trust an address if the token backing it is still in the keychain.
      accounts = Set(saved.filter { Keychain.get(account: $0) != nil })
    }
    migrateLegacyAccount()
  }

  private func migrateLegacyAccount() {
    guard let token = Keychain.get(account: Self.legacyAccount) else { return }
    defer { Keychain.delete(account: Self.legacyAccount) }
    guard let email = UserDefaults.standard.string(forKey: Self.legacyEmailKey)?.lowercased(),
          email.contains("@") else { return }
    UserDefaults.standard.removeObject(forKey: Self.legacyEmailKey)
    Keychain.set(token, account: email)
    accounts.insert(email)
    persistAccounts()
  }

  private func persistAccounts() {
    UserDefaults.standard.set(accounts.sorted(), forKey: Self.accountsKey)
  }

  // MARK: - Credentials

  private var clientID: String {
    Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
  }

  private var clientSecret: String {
    Bundle.main.object(forInfoDictionaryKey: "GoogleClientSecret") as? String ?? ""
  }

  // MARK: - Flow

  func start(for email: String?, openBrowser: Bool) async {
    cancel()
    guard !clientID.isEmpty else {
      phase = .failed("Missing GoogleClientID — check Secrets.xcconfig is wired into the target.")
      return
    }

    connecting = email?.lowercased()
    verifier = Self.randomURLSafe(64)
    expectedState = Self.randomURLSafe(16)
    let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded

    let port: UInt16
    do {
      port = try await startListener()
    } catch {
      connecting = nil
      phase = .failed("Couldn't open a local port: \(error.localizedDescription)")
      return
    }

    redirectURI = "http://127.0.0.1:\(port)"

    var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    comps.queryItems = [
      .init(name: "client_id", value: clientID),
      .init(name: "redirect_uri", value: redirectURI),
      .init(name: "response_type", value: "code"),
      .init(name: "scope", value: Self.scope),
      .init(name: "code_challenge", value: challenge),
      .init(name: "code_challenge_method", value: "S256"),
      .init(name: "state", value: expectedState),
      // Both are required to actually receive a refresh token.
      .init(name: "access_type", value: "offline"),
      // Pre-select the account this row is for. Without an address to hint
      // with, fall back to the picker and let Google ask which one it is.
      .init(name: "prompt", value: email == nil ? "consent select_account" : "consent"),
    ]
    if let hint = email {
      comps.queryItems?.append(.init(name: "login_hint", value: hint))
    }

    authURL = comps.url
    phase = .awaitingCallback
    if openBrowser, let url = authURL {
      // Force the real default browser: openEvent() honours the "add event"
      // preference and could route into the Google Calendar web app, which
      // can't complete an OAuth redirect.
      GoogleCalendarDeepLink.openInBrowser(url)
    }
  }

  func cancel() {
    listener?.cancel()
    listener = nil
    authURL = nil
    connecting = nil
    phase = .idle
  }

  func disconnect(email: String) {
    Keychain.delete(account: email)
    accounts.remove(email)
    accessTokens[email] = nil
    persistAccounts()
  }

  // MARK: - Token access, for the API layer

  func validAccessToken(for email: String?) async throws -> String {
    guard let account = tokenAccount(for: email) else { throw GoogleAuthError.notConnected }
    if let cached = accessTokens[account], cached.expiry > Date().addingTimeInterval(60) {
      return cached.token
    }
    guard let refresh = Keychain.get(account: account) else {
      throw GoogleAuthError.notConnected
    }
    let body: [String: Any]
    do {
      body = try await postForm([
        "client_id": clientID,
        "client_secret": clientSecret,
        "refresh_token": refresh,
        "grant_type": "refresh_token",
      ])
    } catch GoogleAuthError.server(let detail) {
      // Google rejected the refresh token itself (revoked at
      // myaccount.google.com, or expired). Transport failures throw URLError
      // and are left alone — only a 4xx from Google means the grant is gone,
      // and holding on to it would leave Settings claiming a live connection
      // while every RSVP quietly fell back to a browser.
      disconnect(email: account)
      // This runs from an RSVP, not from the setup window, so `phase` may
      // belong to a sign-in that is on screen right now. Reporting over it
      // would replace "Waiting for Google…" with an error while that flow's
      // listener is still live and its callback still coming.
      if phase == .idle {
        phase = .failed("Google sign-in for \(account) expired. Reconnect to respond in place.")
      }
      throw GoogleAuthError.server(detail)
    }
    guard let token = body["access_token"] as? String else {
      throw GoogleAuthError.server("Refresh returned no access_token")
    }
    accessTokens[account] = (token, Date().addingTimeInterval(body["expires_in"] as? Double ?? 3500))
    return token
  }

  // MARK: - Loopback listener

  private func startListener() async throws -> UInt16 {
    let params = NWParameters.tcp
    params.allowLocalEndpointReuse = true
    params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)

    let l = try NWListener(using: params)
    listener = l

    let port: UInt16 = try await withCheckedThrowingContinuation { cont in
      var resumed = false
      l.stateUpdateHandler = { state in
        guard !resumed else { return }
        switch state {
        case .ready:
          resumed = true
          cont.resume(returning: l.port?.rawValue ?? 0)
        case .failed(let error):
          resumed = true
          cont.resume(throwing: error)
        default:
          break
        }
      }
      l.newConnectionHandler = { [weak self] conn in
        conn.start(queue: .main)
        Task { @MainActor in self?.receive(on: conn) }
      }
      l.start(queue: .main)
    }
    guard port != 0 else { throw GoogleAuthError.server("No port assigned") }
    return port
  }

  private func receive(on conn: NWConnection) {
    conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
      guard let data, let text = String(data: data, encoding: .utf8),
            let requestLine = text.split(separator: "\r\n").first,
            let target = requestLine.split(separator: " ").dropFirst().first,
            let comps = URLComponents(string: "http://127.0.0.1\(target)") else {
        conn.cancel()
        return
      }
      let items = comps.queryItems ?? []
      let value = { (name: String) in items.first { $0.name == name }?.value }

      // Browsers also request /favicon.ico — ignore anything that isn't the
      // redirect, or the flow would abort on a stray request.
      guard value("code") != nil || value("error") != nil else {
        Self.respond(conn, status: "204 No Content", html: nil)
        Task { @MainActor in self.receive(on: conn) }
        return
      }

      Self.respond(conn, status: "200 OK", html: """
        <html><body style="font:16px -apple-system;padding:40px">
        Connected. You can close this tab and return to MenuCal.
        </body></html>
        """)

      Task { @MainActor in
        self.listener?.cancel()
        self.listener = nil
        self.authURL = nil
        if let error = value("error") {
          self.connecting = nil
          self.phase = .failed(error == "access_denied" ? "Access was denied." : error)
          return
        }
        guard value("state") == self.expectedState else {
          self.connecting = nil
          self.phase = .failed("State mismatch — the flow may have been tampered with.")
          return
        }
        guard let code = value("code") else { return }
        await self.exchange(code: code)
      }
    }
  }

  // nonisolated: called from the connection's receive handler, off the main actor.
  nonisolated private static func respond(_ conn: NWConnection, status: String, html: String?) {
    let body = Data((html ?? "").utf8)
    var head = "HTTP/1.1 \(status)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n"
    if html != nil { head += "Content-Type: text/html; charset=utf-8\r\n" }
    head += "\r\n"
    conn.send(content: Data(head.utf8) + body,
              completion: .contentProcessed { _ in
                if html != nil { conn.cancel() }
              })
  }

  // MARK: - Token exchange

  private func exchange(code: String) async {
    phase = .exchanging
    // Released only once the exchange has settled. Dropping it here would put
    // an off switch back on screen for the length of the round-trip, then flip
    // it on — the snap-back the spinner exists to prevent.
    defer { connecting = nil }
    do {
      let body = try await postForm([
        "client_id": clientID,
        "client_secret": clientSecret,
        "code": code,
        "code_verifier": verifier,
        "grant_type": "authorization_code",
        "redirect_uri": redirectURI,
      ])
      guard let refresh = body["refresh_token"] as? String else {
        // Without access_type=offline + prompt=consent Google omits this, and
        // the connection would silently die in an hour.
        phase = .failed("Google didn't return a refresh token. Disconnect the app at myaccount.google.com/permissions and retry.")
        return
      }
      // File it under the address Google actually signed in, not the one we
      // hinted: the browser may have been on a different profile, and keying
      // it on the hint would leave a token that answers for the wrong calendar.
      guard let email = (body["id_token"] as? String).flatMap(Self.email(fromIDToken:))?.lowercased() else {
        phase = .failed("Google didn't say which account signed in. Try again.")
        return
      }
      Keychain.set(refresh, account: email)
      // Only cache a token we actually got. Caching "" with an hour's expiry
      // would send `Bearer ` on every call for that hour, and the refresh path
      // that would have fixed it never runs because the entry looks valid.
      if let access = body["access_token"] as? String {
        accessTokens[email] = (access, Date().addingTimeInterval(body["expires_in"] as? Double ?? 3500))
      }
      accounts.insert(email)
      persistAccounts()
      phase = .idle
      NSApp.activate(ignoringOtherApps: true)
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }

  private func postForm(_ params: [String: String]) async throws -> [String: Any] {
    var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
    req.httpMethod = "POST"
    req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    req.httpBody = Data(params.map { "\($0.key)=\(Self.formEncode($0.value))" }
      .joined(separator: "&").utf8)

    let (data, response) = try await URLSession.shared.data(for: req)
    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
      let detail = json["error_description"] as? String ?? json["error"] as? String ?? "HTTP \(http.statusCode)"
      throw GoogleAuthError.server(detail)
    }
    return json
  }

  // MARK: - Helpers

  private static func formEncode(_ s: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
  }

  private static func randomURLSafe(_ bytes: Int) -> String {
    var data = Data(count: bytes)
    _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!) }
    return data.base64URLEncoded
  }

  private static func email(fromIDToken token: String) -> String? {
    let parts = token.split(separator: ".")
    guard parts.count >= 2 else { return nil }
    var b64 = String(parts[1])
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    while b64.count % 4 != 0 { b64 += "=" }
    guard let data = Data(base64Encoded: b64),
          let claims = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
      return nil
    }
    return claims["email"] as? String
  }
}

enum GoogleAuthError: LocalizedError {
  case notConnected
  case server(String)

  var errorDescription: String? {
    switch self {
    case .notConnected: return "No Google account is connected."
    case .server(let detail): return detail
    }
  }
}

private extension Data {
  var base64URLEncoded: String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
