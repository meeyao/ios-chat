import Combine
import Foundation

// MARK: - Settings

public struct ImageUploaderConfig: Codable, Equatable, Sendable {
    public var uploadURL: String
    public var formField: String
    public var headers: String
    public var imageLinkPattern: String
    public var deletionLinkPattern: String

    public init(
        uploadURL: String = "https://kappa.lol/api/upload",
        formField: String = "file",
        headers: String = "",
        imageLinkPattern: String = "{link}",
        deletionLinkPattern: String = "{delete}"
    ) {
        self.uploadURL = uploadURL
        self.formField = formField
        self.headers = headers
        self.imageLinkPattern = imageLinkPattern
        self.deletionLinkPattern = deletionLinkPattern
    }

    public static let `default` = ImageUploaderConfig()

    public var parsedHeaders: [(name: String, value: String)] {
        headers
            .split(separator: ";")
            .compactMap { entry in
                let parts = entry.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return (parts[0].trimmingCharacters(in: .whitespaces), parts[1].trimmingCharacters(in: .whitespaces))
            }
    }
}

public enum TTSPlayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case queue
    case newest

    public var id: String { rawValue }
    public var displayName: String { self == .queue ? "Queue" : "Newest only" }
}

public enum TTSMessageFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case message
    case userAndMessage

    public var id: String { rawValue }
    public var displayName: String { self == .message ? "Message only" : "User and message" }
}

public struct ToolsSettings: Codable, Equatable, Sendable {
    public var uploaderConfig: ImageUploaderConfig
    public var ttsEnabled: Bool
    public var ttsPlayMode: TTSPlayMode
    public var ttsMessageFormat: TTSMessageFormat
    public var ttsForceEnglish: Bool
    public var ttsIgnoreURLs: Bool
    public var ttsIgnoreEmotes: Bool
    public var ttsUserIgnoreList: [String]

    public init(
        uploaderConfig: ImageUploaderConfig = .default,
        ttsEnabled: Bool = false,
        ttsPlayMode: TTSPlayMode = .queue,
        ttsMessageFormat: TTSMessageFormat = .userAndMessage,
        ttsForceEnglish: Bool = false,
        ttsIgnoreURLs: Bool = false,
        ttsIgnoreEmotes: Bool = false,
        ttsUserIgnoreList: [String] = []
    ) {
        self.uploaderConfig = uploaderConfig
        self.ttsEnabled = ttsEnabled
        self.ttsPlayMode = ttsPlayMode
        self.ttsMessageFormat = ttsMessageFormat
        self.ttsForceEnglish = ttsForceEnglish
        self.ttsIgnoreURLs = ttsIgnoreURLs
        self.ttsIgnoreEmotes = ttsIgnoreEmotes
        self.ttsUserIgnoreList = ttsUserIgnoreList
    }
}

@MainActor
public final class ToolsStore: ObservableObject {
    @Published public var settings: ToolsSettings {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let settingsKey = "tools.settings.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(ToolsSettings.self, from: data) {
            settings = decoded
        } else {
            settings = ToolsSettings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }
}

// MARK: - Uploader

public struct UploadedImage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var imageURL: String
    public var deleteURL: String?
    public var uploadedAt: Date
    public var channel: String?

    public init(
        id: UUID = UUID(),
        imageURL: String,
        deleteURL: String? = nil,
        uploadedAt: Date = Date(),
        channel: String? = nil
    ) {
        self.id = id
        self.imageURL = imageURL
        self.deleteURL = deleteURL
        self.uploadedAt = uploadedAt
        self.channel = channel
    }
}

public enum ImageUploadError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, body: String)
    case invalidResponse
    case missingLink

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The upload URL is invalid."
        case .httpError(let statusCode, let body):
            return "Upload failed (\(statusCode)): \(body.prefix(120))"
        case .invalidResponse:
            return "The upload server returned an unreadable response."
        case .missingLink:
            return "The upload response did not contain an image link."
        }
    }
}

public final class ImageUploader: @unchecked Sendable {
    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func upload(
        data: Data,
        filename: String,
        mimeType: String,
        config: ImageUploaderConfig,
        channel: String? = nil
    ) async throws -> UploadedImage {
        guard let url = URL(string: config.uploadURL) else {
            throw ImageUploadError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("dankchat-ios/1.0", forHTTPHeaderField: "User-Agent")
        for header in config.parsedHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(config.formField)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ImageUploadError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ImageUploadError.httpError(
                statusCode: http.statusCode,
                body: String(data: responseData, encoding: .utf8) ?? ""
            )
        }

        let imageURL: String
        let deleteURL: String?
        let trimmedPattern = config.imageLinkPattern.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedPattern.isEmpty {
            imageURL = String(data: responseData, encoding: .utf8) ?? ""
            deleteURL = nil
        } else {
            guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                throw ImageUploadError.invalidResponse
            }
            guard let extracted = Self.extractLink(pattern: trimmedPattern, from: json) else {
                throw ImageUploadError.missingLink
            }
            imageURL = extracted
            let deletePattern = config.deletionLinkPattern.trimmingCharacters(in: .whitespacesAndNewlines)
            deleteURL = deletePattern.isEmpty ? nil : Self.extractLink(pattern: deletePattern, from: json)
        }

        guard !imageURL.isEmpty else {
            throw ImageUploadError.missingLink
        }

        return UploadedImage(imageURL: imageURL, deleteURL: deleteURL, channel: channel)
    }

    private static func extractLink(pattern: String, from json: [String: Any]) -> String? {
        var result = pattern
        let regex = try? NSRegularExpression(pattern: #"\{([^}]+)\}"#)
        let range = NSRange(pattern.startIndex..., in: pattern)
        let matches = regex?.matches(in: pattern, range: range) ?? []

        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: pattern),
                  let fullRange = Range(match.range(at: 0), in: pattern)
            else { continue }
            let key = String(pattern[keyRange])
            guard let value = value(for: key, in: json) else { continue }
            result.replaceSubrange(fullRange, with: value)
        }
        guard !result.contains("{"), !result.isEmpty else { return nil }
        return result
    }

    private static func value(for keyPath: String, in json: [String: Any]) -> String? {
        var current: Any = json
        for key in keyPath.split(separator: ".").map(String.init) {
            guard let dictionary = current as? [String: Any], let next = dictionary[key] else {
                return nil
            }
            current = next
        }
        if let string = current as? String {
            return string
        }
        if let number = current as? NSNumber {
            return number.stringValue
        }
        return nil
    }
}

@MainActor
public final class RecentUploadsStore: ObservableObject {
    @Published public private(set) var uploads: [UploadedImage] = []

    private let defaults: UserDefaults
    private let storageKey = "uploads.recent.v1"
    private let limit = 50

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    public func add(_ upload: UploadedImage) {
        uploads.insert(upload, at: 0)
        if uploads.count > limit {
            uploads.removeLast(uploads.count - limit)
        }
        save()
    }

    public func remove(id: UUID) {
        uploads.removeAll { $0.id == id }
        save()
    }

    public func clear() {
        uploads.removeAll()
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([UploadedImage].self, from: data)
        else { return }
        uploads = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(uploads) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
