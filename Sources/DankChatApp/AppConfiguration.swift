import Foundation
import DankChatCore

struct AppConfiguration: Sendable {
    let oauthConfiguration: OAuthConfiguration
    let defaultNick: String
    let defaultUser: String
    let defaultChannel: String
    let keychainService: String
    let keychainAccount: String

    var isConfigured: Bool {
        !oauthConfiguration.clientId.isEmpty
            && !oauthConfiguration.redirectURI.isEmpty
            && !defaultNick.isEmpty
            && !defaultUser.isEmpty
    }

    static func load() -> AppConfiguration {
        let defaults = AppConfiguration(
            oauthConfiguration: OAuthConfiguration(
                clientId: "",
                redirectURI: "",
                scopes: HelixScope.defaultScopes
            ),
            defaultNick: "",
            defaultUser: "",
            defaultChannel: "",
            keychainService: "DankChatAuth",
            keychainAccount: "twitch"
        )

        guard let url = Bundle.module.url(forResource: "Config", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return defaults
        }

        let clientId = plist["ClientId"] as? String ?? defaults.oauthConfiguration.clientId
        let redirectURI = plist["RedirectURI"] as? String ?? defaults.oauthConfiguration.redirectURI
        let scopes = plist["Scopes"] as? [String] ?? defaults.oauthConfiguration.scopes
        let defaultNick = plist["DefaultNick"] as? String ?? defaults.defaultNick
        let defaultUser = plist["DefaultUser"] as? String ?? defaults.defaultUser
        let defaultChannel = plist["DefaultChannel"] as? String ?? defaults.defaultChannel
        let keychainService = plist["KeychainService"] as? String ?? defaults.keychainService
        let keychainAccount = plist["KeychainAccount"] as? String ?? defaults.keychainAccount

        return AppConfiguration(
            oauthConfiguration: OAuthConfiguration(
                clientId: clientId,
                redirectURI: redirectURI,
                scopes: scopes
            ),
            defaultNick: defaultNick,
            defaultUser: defaultUser,
            defaultChannel: defaultChannel,
            keychainService: keychainService,
            keychainAccount: keychainAccount
        )
    }
}
