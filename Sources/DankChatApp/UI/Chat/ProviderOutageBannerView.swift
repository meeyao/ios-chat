import SwiftUI
import DankChatCore

struct ProviderOutageBannerView: View {
    @EnvironmentObject var providerStatusStore: ProviderStatusStore

    @State private var activeOutage: ProviderOutageEvent?
    @State private var isVisible = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let outage = activeOutage, isVisible {
                bannerContent(for: outage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .onAppear {
            if let latest = providerStatusStore.outages.first {
                show(outage: latest)
            }
        }
        .onChange(of: providerStatusStore.outages) { _, newValue in
            guard let latest = newValue.first else { return }
            if latest.id != activeOutage?.id {
                show(outage: latest)
            }
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    private func bannerContent(for outage: ProviderOutageEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.footnote.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(outage.provider.displayName) outage")
                    .font(.footnote.weight(.semibold))
                Text(outage.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Provider outage for \(outage.provider.displayName)")
        .accessibilityValue(outage.message)
    }

    private func show(outage: ProviderOutageEvent) {
        activeOutage = outage
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            isVisible = true
        }
        scheduleDismiss()
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible = false
                }
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
            await MainActor.run {
                if !isVisible {
                    activeOutage = nil
                }
            }
        }
    }
}
