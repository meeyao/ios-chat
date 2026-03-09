import Foundation
import Combine
import SwiftUI

public struct Command: Identifiable, Equatable, Sendable {
    public let id: String
    public let trigger: String
    public let action: String
}



@MainActor
public final class CommandStore: ObservableObject {
    @Published public private(set) var commands: [Command] = []
    public init() {}
    
    public func addCommand(_ command: Command) {
        commands.append(command)
    }
    
    public func removeCommand(id: String) {
        commands.removeAll { $0.id == id }
    }
}

public final class CommandResolver: Sendable {
    public struct Context: Sendable {
        public let channel: String
        public let user: String
        public init(channel: String, user: String) {
            self.channel = channel
            self.user = user
        }
    }
    
    public init() {}
    
    public func resolve(text: String, commands: [Command], context: Context) -> String {
        // Stub basic resolution
        var resolved = text
        for command in commands {
            if resolved.starts(with: command.trigger) {
                resolved = resolved.replacingOccurrences(of: command.trigger, with: command.action)
                break
            }
        }
        return resolved
    }
}




