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
    }

    /// SwiftPM's Bundle.module only exists inside SwiftPM targets; the Xcode app
    /// target keeps its resources in the main bundle.
    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
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

        guard let url = resourceBundle.url(forResource: "Config", withExtension: "plist")
                ?? resourceBundle.url(forResource: "Config", withExtension: "plist", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return defaults
        }

        let storedClientId = UserDefaults.standard.string(forKey: "twitch.clientId")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let plistClientId = plist["ClientId"] as? String ?? defaults.oauthConfiguration.clientId
        let clientId = (storedClientId?.isEmpty == false ? storedClientId : nil) ?? plistClientId
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
