import Combine
import Foundation

/// Observable store that loads and caches a selected user's profile, followage,
/// and block state. Used by the user popup to display profile details and
/// provide block/unblock actions.
///
/// All published properties are updated on the main actor.
@available(macOS 12.0, iOS 15.0, *)
@MainActor
public final class UserProfileStore: ObservableObject {
    // MARK: - Published State

    /// The loaded user profile, or `nil` while loading or if not found.
    @Published public private(set) var profile: HelixUserProfile?

    /// The follow record if the selected user follows the current channel, or `nil`.
    @Published public private(set) var followRecord: HelixFollowRecord?

    /// Whether followage information could not be loaded due to missing scope.
    @Published public private(set) var followageScopeMissing: Bool = false

    /// Whether the selected user is currently blocked by the authenticated user.
    @Published public private(set) var isBlocked: Bool = false

    /// Whether the block scope is available (user:manage:blocked_users).
    @Published public private(set) var blockScopeMissing: Bool = false

    /// Whether any loading operation is in progress.
    @Published public private(set) var isLoading: Bool = false

    /// The most recent error encountered, or `nil`.
    @Published public private(set) var error: String?

    // MARK: - Dependencies

    private let profileService: HelixUserProfileService
    private let followageService: HelixFollowageService
    private let blockService: HelixBlockService

    /// Creates a new user profile store.
    ///
    /// - Parameters:
    ///   - profileService: Service for fetching user profiles.
    ///   - followageService: Service for checking followage.
    ///   - blockService: Service for block/unblock actions.
    public init(
        profileService: HelixUserProfileService,
        followageService: HelixFollowageService,
        blockService: HelixBlockService
    ) {
        self.profileService = profileService
        self.followageService = followageService
        self.blockService = blockService
    }

    // MARK: - Loading

    /// Loads profile, followage, and block state for a user.
    ///
    /// - Parameters:
    ///   - userId: The target user's Twitch ID. If `nil`, falls back to login lookup.
    ///   - login: The target user's login name. Used if userId is `nil`.
    ///   - channelId: The broadcaster ID for followage lookup.
    ///   - currentUserId: The authenticated user's ID for block list lookup.
    public func load(
        userId: String?,
        login: String,
        channelId: String?,
        currentUserId: String?
    ) async {
        reset()
        isLoading = true
        defer { isLoading = false }

        // 1. Load profile
        do {
            if let userId, !userId.isEmpty {
                profile = try await profileService.getProfile(userId: userId)
            } else {
                profile = try await profileService.getProfile(login: login)
            }
        } catch {
            self.error = "Failed to load profile: \(error.localizedDescription)"
            return
        }

        guard let resolvedId = profile?.id else { return }

        // 2. Load followage (optional, scope-gated)
        if let channelId, !channelId.isEmpty {
            await loadFollowage(userId: resolvedId, channelId: channelId)
        }

        // 3. Check block state
        if let currentUserId, !currentUserId.isEmpty {
            await loadBlockState(targetUserId: resolvedId, currentUserId: currentUserId)
        }
    }

    // MARK: - Block Actions

    /// Blocks the currently loaded user.
    ///
    /// Updates `isBlocked` on success. Sets `error` on failure.
    public func blockUser() async {
        guard let targetId = profile?.id else { return }
        do {
            try await blockService.blockUser(targetUserId: targetId)
            isBlocked = true
            error = nil
        } catch let blockError as HelixError {
            if case .httpError(let statusCode, _) = blockError, statusCode == 401 || statusCode == 403 {
                blockScopeMissing = true
                error = "Missing permission to block users."
            } else {
                error = "Failed to block user: \(blockError.localizedDescription)"
            }
        } catch {
            self.error = "Failed to block user: \(error.localizedDescription)"
        }
    }

    /// Unblocks the currently loaded user.
    ///
    /// Updates `isBlocked` on success. Sets `error` on failure.
    public func unblockUser() async {
        guard let targetId = profile?.id else { return }
        do {
            try await blockService.unblockUser(targetUserId: targetId)
            isBlocked = false
            error = nil
        } catch let blockError as HelixError {
            if case .httpError(let statusCode, _) = blockError, statusCode == 401 || statusCode == 403 {
                blockScopeMissing = true
                error = "Missing permission to unblock users."
            } else {
                error = "Failed to unblock user: \(blockError.localizedDescription)"
            }
        } catch {
            self.error = "Failed to unblock user: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    private func reset() {
        profile = nil
        followRecord = nil
        followageScopeMissing = false
        isBlocked = false
        blockScopeMissing = false
        isLoading = false
        error = nil
    }

    private func loadFollowage(userId: String, channelId: String) async {
        do {
            followRecord = try await followageService.getFollowage(userId: userId, broadcasterId: channelId)
            followageScopeMissing = false
        } catch let helixError as HelixError {
            if case .httpError(let statusCode, _) = helixError, statusCode == 401 || statusCode == 403 {
                followageScopeMissing = true
            }
            // Non-critical -- followage is informational only.
        } catch {
            // Network or other transient error; leave followage as nil.
        }
    }

    private func loadBlockState(targetUserId: String, currentUserId: String) async {
        do {
            let blockedUsers = try await blockService.getBlockedUsers(broadcasterId: currentUserId)
            isBlocked = blockedUsers.contains { $0.userId == targetUserId }
            blockScopeMissing = false
        } catch let helixError as HelixError {
            if case .httpError(let statusCode, _) = helixError, statusCode == 401 || statusCode == 403 {
                blockScopeMissing = true
            }
            // Non-critical -- block state is informational.
        } catch {
            // Network or other transient error.
        }
    }
}
