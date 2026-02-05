import Foundation

enum IRCMessageParser {
    static func parse(line: String) -> IRCMessage? {
        if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }

        var remainder = line.trimmingCharacters(in: .newlines)
        var tags: [String: String?] = [:]
        var prefix: String?

        if remainder.hasPrefix("@") {
            guard let spaceIndex = remainder.firstIndex(of: " ") else {
                return nil
            }
            let tagSectionStart = remainder.index(after: remainder.startIndex)
            let tagSection = remainder[tagSectionStart..<spaceIndex]
            tags = parseTags(String(tagSection))
            remainder = String(remainder[remainder.index(after: spaceIndex)...])
        }

        remainder = remainder.trimmingCharacters(in: .whitespaces)
        if remainder.hasPrefix(":") {
            guard let spaceIndex = remainder.firstIndex(of: " ") else {
                return nil
            }
            let prefixStart = remainder.index(after: remainder.startIndex)
            prefix = String(remainder[prefixStart..<spaceIndex])
            remainder = String(remainder[remainder.index(after: spaceIndex)...])
        }

        remainder = remainder.trimmingCharacters(in: .whitespaces)
        let (beforeTrailing, trailingParam) = splitTrailingParam(remainder)
        let parts = beforeTrailing.split(separator: " ").map(String.init)
        guard let command = parts.first else {
            return nil
        }

        var params = Array(parts.dropFirst())
        if let trailingParam {
            params.append(trailingParam)
        }

        return IRCMessage(tags: tags, prefix: prefix, command: command, params: params)
    }

    private static func splitTrailingParam(_ input: String) -> (String, String?) {
        if let range = input.range(of: " :") {
            let head = String(input[..<range.lowerBound])
            let trailing = String(input[range.upperBound...])
            return (head, trailing)
        }
        return (input, nil)
    }

    private static func parseTags(_ input: String) -> [String: String?] {
        var result: [String: String?] = [:]
        guard !input.isEmpty else {
            return result
        }

        for tagEntry in input.split(separator: ";") {
            if let equalsIndex = tagEntry.firstIndex(of: "=") {
                let key = String(tagEntry[..<equalsIndex])
                let valueStart = tagEntry.index(after: equalsIndex)
                let rawValue = tagEntry[valueStart...]
                result[key] = unescapeTagValue(rawValue)
            } else {
                result[String(tagEntry)] = nil
            }
        }

        return result
    }

    private static func unescapeTagValue(_ input: Substring) -> String {
        var output = ""
        var index = input.startIndex

        while index < input.endIndex {
            let char = input[index]
            if char == "\\" {
                let nextIndex = input.index(after: index)
                if nextIndex == input.endIndex {
                    output.append("\\")
                    break
                }
                let nextChar = input[nextIndex]
                switch nextChar {
                case ":":
                    output.append(";")
                case "s":
                    output.append(" ")
                case "r":
                    output.append("\r")
                case "n":
                    output.append("\n")
                case "\\":
                    output.append("\\")
                default:
                    output.append(nextChar)
                }
                index = input.index(after: nextIndex)
            } else {
                output.append(char)
                index = input.index(after: index)
            }
        }

        return output
    }
}
