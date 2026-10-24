import SwiftUI
import UIKit
import DankChatCore

struct ToolsSettingsView: View {
    @EnvironmentObject private var toolsStore: ToolsStore
    @EnvironmentObject private var recentUploadsStore: RecentUploadsStore
    @EnvironmentObject private var streamStore: StreamStore
    @State private var ignoredUserInput = ""
    @State private var copiedUploadId: UUID?

    var body: some View {
        Form {
            streamsSection
            uploaderSection
            recentUploadsSection
            ttsSection
            ttsIgnoreSection
        }
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var streamsSection: some View {
        Section {
            Toggle("Fetch Stream Info", isOn: $streamStore.settings.fetchStreams)
            Toggle("Show Stream Info", isOn: $streamStore.settings.showStreamInfo)
                .disabled(!streamStore.settings.fetchStreams)
            Toggle("Show Category", isOn: $streamStore.settings.showStreamCategory)
                .disabled(!streamStore.settings.showStreamInfo)
            Toggle("Prevent Stream Reloads", isOn: $streamStore.settings.preventStreamReloads)
            Toggle("Picture in Picture", isOn: $streamStore.settings.enablePiP)
        } header: {
            Text("Streams")
        } footer: {
            Text("Stream info refreshes every minute while signed in. Picture in Picture depends on the Twitch player.")
        }
    }

    private var uploaderSection: some View {
        Section {
            TextField("Upload URL", text: $toolsStore.settings.uploaderConfig.uploadURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            TextField("Form field", text: $toolsStore.settings.uploaderConfig.formField)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Headers (Name: value; Name: value)", text: $toolsStore.settings.uploaderConfig.headers, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Image link pattern", text: $toolsStore.settings.uploaderConfig.imageLinkPattern)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Deletion link pattern", text: $toolsStore.settings.uploaderConfig.deletionLinkPattern)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Reset Uploader Defaults") {
                toolsStore.settings.uploaderConfig = .default
            }
        } header: {
            Text("Image Uploader")
        } footer: {
            Text("Use {field} or {nested.field} placeholders to pull links out of the server's JSON response.")
        }
    }

    private var recentUploadsSection: some View {
        Section {
            if recentUploadsStore.uploads.isEmpty {
                Text("No uploads yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentUploadsStore.uploads) { upload in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(upload.imageURL)
                            .font(.caption)
                            .lineLimit(2)
                        HStack {
                            Button(copiedUploadId == upload.id ? "Copied" : "Copy") {
                                UIPasteboard.general.string = upload.imageURL
                                copiedUploadId = upload.id
                            }
                            .font(.caption)

                            if let deleteURL = upload.deleteURL, !deleteURL.isEmpty {
                                Button("Copy delete link") {
                                    UIPasteboard.general.string = deleteURL
                                }
                                .font(.caption)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                recentUploadsStore.remove(id: upload.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .font(.caption)
                        }
                    }
                }
            }

            if !recentUploadsStore.uploads.isEmpty {
                Button("Clear History", role: .destructive) {
                    recentUploadsStore.clear()
                }
            }
        } header: {
            Text("Recent Uploads")
        }
    }

    private var ttsSection: some View {
        Section {
            Toggle("Enable TTS", isOn: $toolsStore.settings.ttsEnabled)

            Picker("Play mode", selection: $toolsStore.settings.ttsPlayMode) {
                ForEach(TTSPlayMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .disabled(!toolsStore.settings.ttsEnabled)

            Picker("Message format", selection: $toolsStore.settings.ttsMessageFormat) {
                ForEach(TTSMessageFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .disabled(!toolsStore.settings.ttsEnabled)

            Toggle("Force English voice", isOn: $toolsStore.settings.ttsForceEnglish)
                .disabled(!toolsStore.settings.ttsEnabled)
            Toggle("Ignore URLs", isOn: $toolsStore.settings.ttsIgnoreURLs)
                .disabled(!toolsStore.settings.ttsEnabled)
            Toggle("Ignore emotes and symbols", isOn: $toolsStore.settings.ttsIgnoreEmotes)
                .disabled(!toolsStore.settings.ttsEnabled)
        } header: {
            Text("Text to Speech")
        } footer: {
            Text("TTS speaks messages from the active channel while the app is running.")
        }
    }

    private var ttsIgnoreSection: some View {
        Section {
            HStack {
                TextField("Username", text: $ignoredUserInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Add") {
                    let name = ignoredUserInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    if !toolsStore.settings.ttsUserIgnoreList.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                        toolsStore.settings.ttsUserIgnoreList.append(name)
                    }
                    ignoredUserInput = ""
                }
                .disabled(ignoredUserInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(Array(toolsStore.settings.ttsUserIgnoreList.enumerated()), id: \.offset) { index, user in
                HStack {
                    Text(user)
                    Spacer()
                    Button(role: .destructive) {
                        toolsStore.settings.ttsUserIgnoreList.remove(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        } header: {
            Text("TTS Ignored Users")
        }
    }
}
