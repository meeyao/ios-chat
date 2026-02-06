import SwiftUI
import DankChatCore

struct BadgeView: View {
    let badge: Badge
    @State private var showingName = false

    var body: some View {
        Button {
            showingName = true
        } label: {
            badgeImage
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(displayName))
        .alert("Badge", isPresented: $showingName) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(displayName)
        }
    }

    private var badgeImage: some View {
        AsyncImage(url: badge.imageURLs.preferred) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 18, height: 18)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            case .failure:
                Image(systemName: "tag.slash")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)
            @unknown default:
                Color.clear
                    .frame(width: 18, height: 18)
            }
        }
    }

    private var displayName: String {
        let trimmed = badge.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed ?? badge.badgeId : badge.badgeId
    }
}
