import SwiftUI

// MARK: - Status badge

/// Capsule status badge used in the permission cards, the sidebar legend and
/// the final checklist of the setup assistant.
struct StatusBadge: View {
    enum Kind {
        case granted        // "Erlaubt"
        case pending        // "Ausstehend"
        case notYetAllowed  // "Noch nicht erlaubt"
        case denied         // "Verweigert"
        case installed      // "Installiert"
        case skipped        // "Übersprungen"
    }

    let kind: Kind

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(color)
        .background(color.opacity(0.15), in: Capsule())
    }

    private var title: String {
        switch kind {
        case .granted: return "Erlaubt"
        case .pending: return "Ausstehend"
        case .notYetAllowed: return "Noch nicht erlaubt"
        case .denied: return "Verweigert"
        case .installed: return "Installiert"
        case .skipped: return "Übersprungen"
        }
    }

    private var symbol: String {
        switch kind {
        case .granted, .installed: return "checkmark.circle.fill"
        case .pending: return "circle.dashed"
        case .notYetAllowed: return "exclamationmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        }
    }

    private var color: Color {
        switch kind {
        case .granted, .installed: return .green
        case .pending: return .gray
        case .notYetAllowed, .skipped: return .orange
        case .denied: return .red
        }
    }
}

// MARK: - Status card

/// Card showing one labelled status row (e.g. "Mikrofonzugriff" + badge).
/// Styling matches the mode cards in `MenuBarView` (.regularMaterial, radius 8).
struct OnboardingStatusCard: View {
    let title: String
    let badge: StatusBadge.Kind

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            StatusBadge(kind: badge)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Notice box

/// Informational / warning box with optional technical detail line and an
/// optional action button. The warning styling matches the permissions banner
/// in `MenuBarView` (orange icon on `Color.orange.opacity(0.1)`).
struct OnboardingNoticeBox: View {
    enum Style {
        case info     // neutral hint, `info.circle`
        case warning  // orange, `exclamationmark.triangle.fill`
        case restart  // orange, `arrow.clockwise.circle`
    }

    let style: Style
    let text: String
    var detail: String?
    var buttonTitle: String?
    var action: (@MainActor () -> Void)?

    init(
        style: Style,
        text: String,
        detail: String? = nil,
        buttonTitle: String? = nil,
        action: (@MainActor () -> Void)? = nil
    ) {
        self.style = style
        self.text = text
        self.detail = detail
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(iconColor)
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private var symbol: String {
        switch style {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .restart: return "arrow.clockwise.circle"
        }
    }

    private var iconColor: Color {
        switch style {
        case .info: return .secondary
        case .warning, .restart: return .orange
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .info: return Color.gray.opacity(0.1)
        case .warning, .restart: return Color.orange.opacity(0.1)
        }
    }
}

// MARK: - Keycap badge

/// Small monospaced keycap (e.g. "⌥" / "⌥⌃"). Styling matches
/// `MenuBarView.modeTrailing`.
struct OnboardingKeycap: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.callout.monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.tertiary.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
