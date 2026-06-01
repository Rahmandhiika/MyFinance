import Foundation
import Security
import Observation

// MARK: - Keychain low-level helper

enum KeychainService {

    private static let service = Bundle.main.bundleIdentifier ?? "rahmandhika.MyFinance"

    /// Simpan string ke Keychain. Update jika sudah ada, insert jika belum.
    static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  account
        ]
        // Coba update dulu
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            // Belum ada → insert baru
            var addQuery = query
            addQuery[kSecValueData] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Baca string dari Keychain. Nil jika tidak ada.
    static func load(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  account,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Hapus item dari Keychain.
    static func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - APIKeyStore (@Observable singleton)

/// Singleton yang menyimpan Anthropic API key ke Keychain.
/// Semua view yang perlu apiKey cukup referensikan `APIKeyStore.shared.apiKey`.
/// SwiftUI melacak perubahan otomatis karena @Observable.
@Observable final class APIKeyStore {
    static let shared = APIKeyStore()

    static let keychainAccount = "anthropicAPIKey"

    var apiKey: String {
        didSet {
            if apiKey.isEmpty {
                KeychainService.delete(account: Self.keychainAccount)
            } else {
                KeychainService.save(apiKey, account: Self.keychainAccount)
            }
        }
    }

    private init() {
        apiKey = KeychainService.load(account: Self.keychainAccount) ?? ""
    }
}
