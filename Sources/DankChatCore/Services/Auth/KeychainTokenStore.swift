import Foundation
import Security

public final class KeychainTokenStore: OAuthTokenStore {
    public enum KeychainError: Error {
        case unhandled(OSStatus)
        case encodingFailed
        case decodingFailed
    }

    private let service: String
    private let account: String
    private let accessGroup: String?

    public init(service: String = "DankChatAuth", account: String = "twitch", accessGroup: String? = nil) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
    }

    public func readToken() throws -> OAuthToken? {
        var query = baseQuery
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
        guard let data = result as? Data else {
            throw KeychainError.decodingFailed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let token = try? decoder.decode(OAuthToken.self, from: data) else {
            throw KeychainError.decodingFailed
        }
        return token
    }

    public func writeToken(_ token: OAuthToken) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(token) else {
            throw KeychainError.encodingFailed
        }

        var attributes = baseQuery
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandled(updateStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    public func clearToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }

    private var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
