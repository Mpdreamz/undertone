/// Light or dark: which half of a tonality is drawn, following the system's appearance.
public enum Appearance: String, CaseIterable, Codable, Sendable {
    case dark, light
}

/// A family of colours with a dark and a light set of five: the base the picture sits on, a deep tone, two accents
/// and a shade. A tonality stays the same across every space; only the seed (and perhaps the style) varies.
public enum Tonality: String, CaseIterable, Codable, Sendable {
    case ember, tide, aurora, dusk, moss, glacier, citrus, mono

    public func palette(_ appearance: Appearance) -> Palette {
        let hex: [String] = switch (self, appearance) {
        case (.ember, .dark): ["#08090B", "#3D2C10", "#FFB03D", "#A96BFF", "#2A1A4D"]
        case (.ember, .light): ["#FBF6EE", "#FFE2B0", "#FFB03D", "#C9A6FF", "#F3E9FF"]
        case (.tide, .dark): ["#05080F", "#0B2545", "#1F6FEB", "#36C5F0", "#0A3D62"]
        case (.tide, .light): ["#F2F7FC", "#CFE6FF", "#6FA8FF", "#8EE3F5", "#E4F1FF"]
        case (.aurora, .dark): ["#04090A", "#08332E", "#2EE6A6", "#7B5CFF", "#0E1F3D"]
        case (.aurora, .light): ["#F1FAF7", "#C4F2E0", "#5FE0B2", "#B9A8FF", "#E6F4FF"]
        case (.dusk, .dark): ["#0B0710", "#3A1030", "#FF5E7E", "#FF9F45", "#2B1650"]
        case (.dusk, .light): ["#FFF5F3", "#FFD3DA", "#FF8FA3", "#FFC48A", "#EADCFF"]
        case (.moss, .dark): ["#070906", "#1E2A14", "#9BC53D", "#E0C55A", "#123124"]
        case (.moss, .light): ["#F6F8F0", "#E0EBC8", "#A9CF6A", "#F0DC8C", "#D9EEDD"]
        case (.glacier, .dark): ["#07090C", "#1A2230", "#A9C6E8", "#E8EEF6", "#3C4A63"]
        case (.glacier, .light): ["#F7F9FC", "#E3EAF3", "#B7CBE3", "#FFFFFF", "#D3DCE8"]
        case (.citrus, .dark): ["#0A0805", "#3B2405", "#FF7A1A", "#FFD23F", "#5C1A1A"]
        case (.citrus, .light): ["#FFFAF0", "#FFE7B8", "#FF9A4D", "#FFE066", "#FFD6C9"]
        case (.mono, .dark): ["#060606", "#1A1A1A", "#6E6E6E", "#D9D9D9", "#2C2C2C"]
        case (.mono, .light): ["#F7F7F7", "#E4E4E4", "#BDBDBD", "#FFFFFF", "#D0D0D0"]
        }
        return Palette(colors: hex.map { RGB(hex: $0) }, isDark: appearance == .dark)
    }
}

/// The five colours a style draws with, by role, as the prototype's `p[0]` … `p[4]`.
public struct Palette: Sendable {
    let colors: [RGB]
    let isDark: Bool

    subscript(_ i: Int) -> RGB {
        colors[i]
    }

    var base: RGB {
        colors[0]
    }

    func ramp(_ roles: [Int]) -> Ramp {
        Ramp(roles.map { colors[$0] })
    }
}
