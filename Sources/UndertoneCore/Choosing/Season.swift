import Foundation

/// The time of year, for choosing a tonality by season: winter's cold blues, spring's greens, summer's warm and
/// sea colours, autumn's ambers. Never mono, which is no season's colour.
public enum Season: String, CaseIterable, Sendable {
    case winter, spring, summer, autumn

    /// The tonalities that suit it, most fitting first.
    public var tonalities: [Tonality] {
        switch self {
        case .winter: [.glacier, .tide, .aurora]
        case .spring: [.moss, .aurora, .dusk]
        case .summer: [.citrus, .tide, .ember]
        case .autumn: [.ember, .dusk, .moss]
        }
    }

    public var title: String {
        rawValue.capitalized
    }

    /// The season on `date` (meteorological: whole months) in `hemisphere`.
    public static func on(_ date: Date, in hemisphere: Hemisphere, calendar: Calendar = .current) -> Season {
        let month = calendar.component(.month, from: date)
        let north: Season = switch month {
        case 3 ... 5: .spring
        case 6 ... 8: .summer
        case 9 ... 11: .autumn
        default: .winter
        }
        guard hemisphere.resolved == .south else { return north }
        return switch north {
        case .winter: .summer
        case .spring: .autumn
        case .summer: .winter
        case .autumn: .spring
        }
    }
}

/// Which half of the world the seasons follow: worked out from the Mac's region unless set.
public enum Hemisphere: String, CaseIterable, Sendable {
    case auto, north, south

    /// Regions wholly or mostly south of the equator.
    static let southernRegions: Set<String> = [
        "AR", "AU", "BO", "BR", "BW", "CL", "FJ", "LS", "MG", "MU", "MW", "MZ", "NA", "NC", "NZ", "PE", "PF", "PY",
        "SZ", "TO", "UY", "VU", "WS", "ZA", "ZM", "ZW",
    ]

    public var resolved: Hemisphere {
        resolved(region: Locale.current.region?.identifier)
    }

    func resolved(region: String?) -> Hemisphere {
        guard self == .auto else { return self }
        return region.map { Self.southernRegions.contains($0) } == true ? .south : .north
    }
}
