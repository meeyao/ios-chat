import SwiftUI
import DankChatCore

struct ChatSettingsView: View {
    @ObservedObject var settings: ChatSettings
    @EnvironmentObject private var badgeStore: BadgeStore
    @ObservedObject private var badgeVisibility = BadgeVisibilitySettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Chat Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show Timestamps", isOn: $settings.showTimestamps)
                    Toggle("Show Usernames", isOn: $settings.showUsernames)
                    Toggle("Animate Emotes", isOn: $settings.allowAnimatedEmotes)

                    Stepper(value: $settings.scrollbackLimit, in: 100...2000, step: 50) {
                        HStack {
                            Text("Scrollback Limit")
                            Spacer()
                            Text("\(settings.scrollbackLimit)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Badge Visibility") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show Badges", isOn: $badgeVisibility.isGlobalEnabled)

                    ForEach(ProviderID.allCases, id: \.self) { provider in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("\(provider.displayName) Badges", isOn: providerVisibilityBinding(provider))

                            if let categories = badgeCategories[provider], !categories.isEmpty {
                                ForEach(categories, id: \.self) { category in
                                    Toggle(categoryDisplayName(category), isOn: categoryVisibilityBinding(provider, category))
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var badgeCategories: [ProviderID: [String]] {
        badgeStore.availableBadgeCategories()
    }

    private func providerVisibilityBinding(_ provider: ProviderID) -> Binding<Bool> {
        Binding(
            get: { badgeVisibility.providerVisibility[provider] ?? true },
            set: { badgeVisibility.setProviderVisibility(provider, isVisible: $0) }
        )
    }

    private func categoryVisibilityBinding(_ provider: ProviderID, _ category: String) -> Binding<Bool> {
        Binding(
            get: { badgeVisibility.categoryVisibility[provider]?[category] ?? true },
            set: { badgeVisibility.setCategoryVisibility(provider: provider, badgeId: category, isVisible: $0) }
        )
    }

    private func categoryDisplayName(_ category: String) -> String {
        category.replacingOccurrences(of: "_", with: " ")
    }
}

#Preview {
    let settings = ChatSettings()
    let configuration = OAuthConfiguration(clientId: "", redirectURI: "", scopes: [])
    let twitchBadgeProvider = TwitchBadgeProvider(configuration: configuration, tokenProvider: { nil })
    let badgeStore = BadgeStore(twitchProvider: twitchBadgeProvider)
    return ChatSettingsView(settings: settings)
        .environmentObject(badgeStore)
        .padding()
}
