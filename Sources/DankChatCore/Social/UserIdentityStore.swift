import Combine
import Foundation

/// Observable store that caches the signed-in user's Helix identity.
///
/// Feature services (mentions, whispers, moderation) read `user` to obtain the
/// authenticated user's ID, login, and display name without redundant API calls.
@available(macOS 12.0, iOS 15.0, *)
@MainActor
public final class UserIdentityStore: ObservableObject {
    /// The current user's Helix identity, or `nil` if not yet resolved or signed out.
    @Published public private(set) var user: HelixUser?

    /// Whether a refresh is currently in progress.
    @Published public private(set) var isLoading: Bool = false

    private let usersService: HelixUsersService

    /// Creates a new identity store.
    ///
    /// - Parameter usersService: The Helix users service used to fetch the current user.
    public init(usersService: HelixUsersService) {
        self.usersService = usersService
    }

    /// Fetches the current user's identity from Helix and caches the result.
    ///
    /// No-ops if a refresh is already in progress. Clears the stored user on failure.
    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            user = try await usersService.getCurrentUser()
        } catch {
            user = nil
        }
    }

    /// Clears the cached user identity. Call on sign-out.
    public func clear() {
        user = nil
    }
}
