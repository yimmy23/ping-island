import SwiftUI

struct UsageSummaryStripView: View {
    let providers: [UsageSummaryProvider]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ForEach(providers) { provider in
                    providerSection(provider)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func providerSection(_ provider: UsageSummaryProvider) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(provider.title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.72))

            ForEach(provider.windows, id: \.id) { window in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(window.label)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.52))

                        Text(window.valueText)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.88))
                            .lineLimit(1)
                    }

                    if let resetText = window.resetText {
                        Text(resetText)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
    }
}
