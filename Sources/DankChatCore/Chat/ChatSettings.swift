import Combine
import Foundation

public final class ChatSettings: ObservableObject {
    @Published public var showTimestamps: Bool
    @Published public var showUsernames: Bool
    @Published public var scrollbackLimit: Int

    public init(showTimestamps: Bool = true, showUsernames: Bool = true, scrollbackLimit: Int = 500) {
        self.showTimestamps = showTimestamps
        self.showUsernames = showUsernames
        self.scrollbackLimit = scrollbackLimit
    }
}
