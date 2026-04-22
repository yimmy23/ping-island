import SwiftUI

struct UsageSummaryStripView: View {
    enum DisplayStyle {
        case numeric
        case battery
    }

    let providers: [UsageSummaryProvider]
    var inline = false
    var alignment: HorizontalAlignment = .leading
    var displayStyle: DisplayStyle = .numeric

    var body: some View {
        Group {
            if inline {
                HStack(spacing: 6) {
                    ForEach(providers) { provider in
                        providerSection(provider)
                    }
                }
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
            } else {
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
        }
    }

    @ViewBuilder
    private func providerSection(_ provider: UsageSummaryProvider) -> some View {
        if inline {
            HStack(alignment: .center, spacing: 6) {
                Text(provider.title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))

                ForEach(provider.windows, id: \.id) { window in
                    if displayStyle == .battery {
                        HStack(spacing: 4) {
                            Text(window.label)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))

                            BatteryQuotaIndicator(severity: window.severity)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                        .help(window.resetText ?? "")
                    } else {
                        HStack(spacing: 3) {
                            Text(window.label)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))

                            Text(window.valueText)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(emphasisColor(for: window.severity))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(backgroundColor(for: window.severity))
                        )
                        .help(window.resetText ?? "")
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
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
                            .foregroundColor(emphasisColor(for: window.severity))
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
                            .fill(backgroundColor(for: window.severity))
                    )
                }
            }
        }
    }

    private func emphasisColor(for severity: UsageSummarySeverity) -> Color {
        switch severity {
        case .healthy:
            return Color(red: 0.42, green: 0.92, blue: 0.60)
        case .warning:
            return Color(red: 0.98, green: 0.82, blue: 0.32)
        case .critical:
            return Color(red: 0.98, green: 0.44, blue: 0.38)
        }
    }

    private func backgroundColor(for severity: UsageSummarySeverity) -> Color {
        switch severity {
        case .healthy:
            return Color(red: 0.26, green: 0.52, blue: 0.34).opacity(0.22)
        case .warning:
            return Color(red: 0.56, green: 0.42, blue: 0.14).opacity(0.24)
        case .critical:
            return Color(red: 0.52, green: 0.18, blue: 0.16).opacity(0.26)
        }
    }
}

private struct BatteryQuotaIndicator: View {
    let severity: UsageSummarySeverity

    private var fillLevel: CGFloat {
        switch severity {
        case .healthy:
            return 0.82
        case .warning:
            return 0.42
        case .critical:
            return 0.14
        }
    }

    private var fillColor: Color {
        switch severity {
        case .healthy:
            return Color(red: 0.42, green: 0.92, blue: 0.60)
        case .warning:
            return Color(red: 0.98, green: 0.82, blue: 0.32)
        case .critical:
            return Color(red: 0.98, green: 0.44, blue: 0.38)
        }
    }

    var body: some View {
        HStack(spacing: 1.5) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.white.opacity(0.26), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(fillColor)
                        .frame(width: max(2, (proxy.size.width - 4) * fillLevel))
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                }
            }
            .frame(width: 18, height: 10)

            RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                .fill(Color.white.opacity(0.24))
                .frame(width: 1.8, height: 4.8)
        }
    }
}
