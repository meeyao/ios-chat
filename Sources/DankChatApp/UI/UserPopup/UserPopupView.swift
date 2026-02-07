import SwiftUI
import DankChatCore

/// A sheet that displays a user's profile, followage, and block controls.
///
/// Presented when tapping a username in chat. Loads data via `UserProfileStore`
/// and provides block/unblock actions gated by OAuth scopes.
struct UserPopupView: View {
    @ObservedObject var store: UserProfileStore

    /// The user ID to load (may be nil if only login is known).
    let userId: String?
    /// The user's login name.
    let login: String
    /// The user's display name for the header.
    let displayName: String
    /// The current channel ID for followage lookup.
    let channelId: String?
    /// The authenticated user's ID for block state.
    let currentUserId: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    Divider()
                    followageSection
                    Divider()
                    blockSection

                    if let error = store.error {
                        errorBanner(error)
                    }
                }
                .padding()
            }
            .navigationTitle("User Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await store.load(
                    userId: userId,
                    login: login,
                    channelId: channelId,
                    currentUserId: currentUserId
                )
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        if store.isLoading {
            HStack {
                Spacer()
                ProgressView("Loading profile...")
                Spacer()
            }
            .padding(.vertical, 24)
        } else if let profile = store.profile {
            profileHeader(profile)
        } else {
            // Fallback when profile couldn't be loaded
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.title2.weight(.bold))
                if displayName.lowercased() != login.lowercased() {
                    Text("@\(login)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func profileHeader(_ profile: HelixUserProfile) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let avatarURLString = profile.profileImageUrl,
               let avatarURL = URL(string: avatarURLString) {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 64, height: 64)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                    case .failure:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(.title2.weight(.bold))

                if profile.displayName.lowercased() != profile.login.lowercased() {
                    Text("@\(profile.login)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let broadcasterType = profile.broadcasterType, !broadcasterType.isEmpty {
                    Text(broadcasterType.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Capsule())
                }

                if let createdAt = profile.createdAt {
                    Text("Joined \(formattedDate(createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if let bio = profile.userDescription, !bio.isEmpty {
            Text(bio)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .frame(width: 64, height: 64)
            .foregroundStyle(.secondary)
    }

    // MARK: - Followage

    @ViewBuilder
    private var followageSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Followage")
                .font(.headline)

            if store.followageScopeMissing {
                Label("Followage unavailable (missing scope)", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let followRecord = store.followRecord {
                Label("Following since \(formattedDate(followRecord.followedAt))", systemImage: "heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(.pink)
            } else if channelId == nil || channelId?.isEmpty == true {
                Label("No channel context", systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if store.isLoading {
                ProgressView()
            } else {
                Label("Not following this channel", systemImage: "heart")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Block

    @ViewBuilder
    private var blockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.headline)

            if store.blockScopeMissing {
                Label("Block actions unavailable (missing scope)", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if store.isBlocked {
                Button(role: .destructive) {
                    Task { await store.unblockUser() }
                } label: {
                    Label("Unblock User", systemImage: "hand.raised.slash")
                }
                .buttonStyle(.bordered)
            } else {
                Button(role: .destructive) {
                    Task { await store.blockUser() }
                } label: {
                    Label("Block User", systemImage: "hand.raised.fill")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return Self.displayFormatter.string(from: date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return Self.displayFormatter.string(from: date)
        }
        return isoString
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
