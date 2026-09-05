//
//  Keychain.swift
//  MenuCal
//

import Foundation
import Security

// Minimal generic-password store. Only the Google refresh token lives here —
// access tokens are short-lived and stay in memory.
enum Keychain {
  private static let service = "sak3th.MenuCal.google"

  static func set(_ value: String, account: String) {
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    // SecItemUpdate only works on an existing item, so delete-then-add keeps
    // this a single path for both first save and refresh-token rotation.
    SecItemDelete(query as CFDictionary)
    var add = query
    add[kSecValueData as String] = data
    let status = SecItemAdd(add as CFDictionary, nil)
    if status != errSecSuccess {
      NSLog("Keychain save failed for \(account): \(status)")
    }
  }

  static func get(account: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func delete(account: String) {
    SecItemDelete([
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ] as CFDictionary)
  }
}
