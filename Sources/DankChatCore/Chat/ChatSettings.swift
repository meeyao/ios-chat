import Combine
import Foundation

public final class ChatSettings: ObservableObject {
    @Published public var showTimestamps: Bool
    @Published public var showUsernames: Bool
    @Published public var scrollbackLimit: Int
    @Published public var allowAnimatedEmotes: Bool

    public init(
        showTimestamps: Bool = true,
        showUsernames: Bool = true,
        scrollbackLimit: Int = 500,
        allowAnimatedEmotes: Bool = true
    ) {
        self.showTimestamps = showTimestamps
        self.showUsernames = showUsernames
        self.scrollbackLimit = scrollbackLimit
        self.allowAnimatedEmotes = allowAnimatedEmotes
    }
}
