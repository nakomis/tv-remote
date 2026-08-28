import SwiftUI

/// The colour palette, taken from nakostat's dark theme.
///
/// nakostat defines its tokens in OKLCH; these are those same values converted
/// to sRGB. It is a deliberately neutral, hueless greyscale — the only colour
/// in it is `destructive`, which is why the accents below are derived from
/// that one rather than invented.
///
/// Both apps run dark unconditionally, so there is no light variant. A remote
/// gets used in a dark room, and a menu bar popover that flashes white is
/// worse than useless at night.
enum Theme {

    // MARK: - Surfaces (nakostat's neutral scale)

    /// `--background`, oklch(0.145 0 0)
    static let background = Color(hex: 0x0A0A0A)
    /// `--card` / `--popover`, oklch(0.205 0 0)
    static let surface = Color(hex: 0x171717)
    /// `--secondary` / `--muted` / `--accent`, oklch(0.269 0 0)
    static let raised = Color(hex: 0x262626)

    // MARK: - Text

    /// `--foreground`, oklch(0.985 0 0)
    static let foreground = Color(hex: 0xFAFAFA)
    /// `--primary`, oklch(0.922 0 0)
    static let primary = Color(hex: 0xE5E5E5)
    /// `--muted-foreground`, oklch(0.708 0 0)
    static let mutedForeground = Color(hex: 0xA1A1A1)
    /// `--ring`, oklch(0.556 0 0)
    static let ring = Color(hex: 0x737373)

    /// `--border`, white at 10%
    static let border = Color.white.opacity(0.10)

    // MARK: - Accents

    /// `--destructive`, oklch(0.704 0.191 22.216). Used for power off.
    static let destructive = Color(hex: 0xFF6467)

    /// Power on.
    ///
    /// nakostat has no green, so this is `destructive` with its hue rotated to
    /// 152° at the same lightness and chroma — the same colour built to the
    /// same recipe, rather than an arbitrary green bolted on. It clips
    /// slightly at the sRGB gamut boundary, as nakostat's own red does.
    static let positive = Color(hex: 0x00C05F)

    /// `--sidebar-primary`, oklch(0.488 0.243 264.376). Marks the live input.
    ///
    /// Lightened from nakostat's value, which is tuned for a light sidebar and
    /// is too dark to read as a highlight against a near-black surface.
    static let accent = Color(hex: 0x4F7DFF)

    // MARK: - Metrics

    static let cornerRadius: CGFloat = 14
    static let cardRadius: CGFloat = 18
}

extension Color {
    /// Builds a colour from a `0xRRGGBB` literal, which keeps the palette
    /// above readable as the hex values it was converted from.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
