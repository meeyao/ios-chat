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

// MARK: - Room State Controls

/// Displays the current channel room state and provides controls for moderators to toggle settings.
///
/// Reads the current state from `ChannelState.roomState` (populated via IRC ROOMSTATE).
/// When a moderator toggles a setting, it calls `HelixChatSettingsService.updateChatSettings`
/// and then refreshes via `getChatSettings` to confirm the server state.
///
/// Controls are disabled when the `moderator:manage:chat_settings` scope is unavailable.
struct RoomStateControlsView: View {
    let channelId: String
    let broadcasterId: String
    let moderatorId: String
    let roomState: RoomState
    let hasManageScope: Bool

    @EnvironmentObject private var moderationContext: ModerationContext
    @State private var isUpdating = false
    @State private var errorMessage: String?

    // Local editing state for sliders/steppers
    @State private var slowModeSeconds: Double = 0
    @State private var followersOnlyMinutes: Double = 0

    var body: some View {
        GroupBox("Room State") {
            VStack(alignment: .leading, spacing: 12) {
                if !hasManageScope {
                    Label("Manage scope not available", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Current state summary
                if let summary = roomState.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                } else {
                    Text("No active room modes")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 4)
                }

                // Slow mode
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Slow Mode", isOn: slowModeBinding)
                        .disabled(!hasManageScope || isUpdating)

                    if roomState.slowModeSeconds != nil || slowModeSeconds > 0 {
                        HStack {
                            Text("Delay:")
                            Stepper(
                                "\(Int(slowModeSeconds))s",
                                value: $slowModeSeconds,
                                in: 1...120,
                                step: 1,
                                onEditingChanged: { editing in
                                    if !editing {
                                        updateSlowMode(seconds: Int(slowModeSeconds))
                                    }
                                }
                            )
                        }
                        .font(.subheadline)
                        .disabled(!hasManageScope || isUpdating)
                    }
                }

                // Followers-only mode
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Followers-Only", isOn: followersOnlyBinding)
                        .disabled(!hasManageScope || isUpdating)

                    if roomState.followersOnlyMinutes != nil || followersOnlyMinutes > 0 {
                        HStack {
                            Text("Min follow:")
                            Stepper(
                                "\(Int(followersOnlyMinutes))m",
                                value: $followersOnlyMinutes,
                                in: 0...43200,
                                step: 10,
                                onEditingChanged: { editing in
                                    if !editing {
                                        updateFollowersOnly(minutes: Int(followersOnlyMinutes))
                                    }
                                }
                            )
                        }
                        .font(.subheadline)
                        .disabled(!hasManageScope || isUpdating)
                    }
                }

                Toggle("Subscribers-Only", isOn: subsOnlyBinding)
                    .disabled(!hasManageScope || isUpdating)

                Toggle("Emote-Only", isOn: emoteOnlyBinding)
                    .disabled(!hasManageScope || isUpdating)

                Toggle("Unique Chat", isOn: uniqueChatBinding)
                    .disabled(!hasManageScope || isUpdating)

                if isUpdating {
                    ProgressView()
                        .controlSize(.small)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            syncLocalState()
        }
        .onChange(of: roomState) { _, newState in
            syncLocalStateFrom(newState)
        }
    }

    // MARK: - Local State Sync

    private func syncLocalState() {
        syncLocalStateFrom(roomState)
    }

    private func syncLocalStateFrom(_ state: RoomState) {
        slowModeSeconds = Double(state.slowModeSeconds ?? 0)
        followersOnlyMinutes = Double(state.followersOnlyMinutes ?? 0)
    }

    // MARK: - Toggle Bindings

    private var slowModeBinding: Binding<Bool> {
        Binding(
            get: { roomState.slowModeSeconds != nil },
            set: { newValue in
                let seconds = newValue ? max(Int(slowModeSeconds), 1) : 0
                updateSetting(patch: HelixChatSettingsPatch(
                    slowMode: newValue,
                    slowModeWaitTime: newValue ? seconds : nil
                ))
            }
        )
    }

    private var followersOnlyBinding: Binding<Bool> {
        Binding(
            get: { roomState.followersOnlyMinutes != nil },
            set: { newValue in
                updateSetting(patch: HelixChatSettingsPatch(
                    followerMode: newValue,
                    followerModeDuration: newValue ? Int(followersOnlyMinutes) : nil
                ))
            }
        )
    }

    private var subsOnlyBinding: Binding<Bool> {
        Binding(
            get: { roomState.isSubsOnly },
            set: { newValue in
                updateSetting(patch: HelixChatSettingsPatch(subscriberMode: newValue))
            }
        )
    }

    private var emoteOnlyBinding: Binding<Bool> {
        Binding(
            get: { roomState.isEmoteOnly },
            set: { newValue in
                updateSetting(patch: HelixChatSettingsPatch(emoteMode: newValue))
            }
        )
    }

    private var uniqueChatBinding: Binding<Bool> {
        Binding(
            get: { roomState.isUniqueChat },
            set: { newValue in
                updateSetting(patch: HelixChatSettingsPatch(uniqueChatMode: newValue))
            }
        )
    }

    // MARK: - Helix Update Helpers

    private func updateSlowMode(seconds: Int) {
        let isOn = roomState.slowModeSeconds != nil
        guard isOn else { return }
        updateSetting(patch: HelixChatSettingsPatch(
            slowMode: true,
            slowModeWaitTime: seconds
        ))
    }

    private func updateFollowersOnly(minutes: Int) {
        let isOn = roomState.followersOnlyMinutes != nil
        guard isOn else { return }
        updateSetting(patch: HelixChatSettingsPatch(
            followerMode: true,
            followerModeDuration: minutes
        ))
    }

    private func updateSetting(patch: HelixChatSettingsPatch) {
        guard hasManageScope, !isUpdating else { return }
        isUpdating = true
        errorMessage = nil

        Task {
            defer { isUpdating = false }
            do {
                let service = moderationContext.chatSettingsService
                let updated = try await service.updateChatSettings(
                    broadcasterId: broadcasterId,
                    moderatorId: moderatorId,
                    patch: patch
                )
                // Sync channel store room state from Helix response
                let newRoomState = updated.toRoomState()
                moderationContext.channelStore.updateRoomState(
                    channelId: channelId,
                    roomState: newRoomState
                )
            } catch let error as HelixError {
                switch error {
                case .httpError(let statusCode, _):
                    errorMessage = "Failed (\(statusCode))"
                case .missingAccessToken:
                    errorMessage = "Not authenticated"
                default:
                    errorMessage = "Update failed"
                }
            } catch {
                errorMessage = "Update failed"
            }
        }
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
