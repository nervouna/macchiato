import Foundation

/// A calendar date without a time zone.
struct Day: Comparable, CustomStringConvertible, Sendable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    init?(_ text: String) {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    /// Days since 1970-01-01 (Howard Hinnant's civil-days algorithm).
    var epochDays: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// Proleptic Gregorian ordinal, 0001-01-01 is 1 (same as Python's date.toordinal()).
    var ordinal: Int { epochDays + 719_163 }

    init(epochDays: Int) {
        let z = epochDays + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let month = mp < 10 ? mp + 3 : mp - 9
        self.init(year: yoe + era * 400 + (month <= 2 ? 1 : 0), month: month, day: doy - (153 * mp + 2) / 5 + 1)
    }

    func adding(days: Int) -> Day { Day(epochDays: epochDays + days) }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    static func < (a: Day, b: Day) -> Bool { a.epochDays < b.epochDays }
}

struct Prompts: Codable, Sendable {
    var theme: String
    var term: String
    var termDay: Bool
    var style: String
    var day: String
    var night: String

    enum CodingKeys: String, CodingKey {
        case theme, term, style, day, night
        case termDay = "term_day"
    }
}

/// Solar terms (二十四节气) and the daily abstract-wallpaper prompt built from them.
enum Season {
    struct Term {
        let name: String
        let season: String
        let palette: String
        let accent: String
    }

    struct Style {
        let name: String
        let description: String
        let compositions: [String]
    }

    // Index i covers solar longitudes [15*i, 15*i + 15); the term itself starts at 15*i.
    static let terms: [Term] = [
        Term(name: "春分", season: "mid spring", palette: "rapeseed yellow, fresh spring green, clear sky blue and soft white", accent: "a touch of cherry blossom pink"),
        Term(name: "清明", season: "late spring", palette: "celadon green, rain grey, soft white and pale jade", accent: "a hint of willow yellow-green"),
        Term(name: "谷雨", season: "late spring", palette: "tea green, peony pink, warm grey and cream", accent: "a small deep peony magenta"),
        Term(name: "立夏", season: "early summer", palette: "emerald, fresh lime, pale mint and cream", accent: "a touch of lotus pink"),
        Term(name: "小满", season: "early summer", palette: "ripening wheat gold, leaf green, sky blue and warm white", accent: "a touch of poppy red"),
        Term(name: "芒种", season: "early summer", palette: "harvest amber, deep green, warm white and straw", accent: "a touch of vivid orange"),
        Term(name: "夏至", season: "midsummer", palette: "lotus pink, deep teal, bright white and aqua", accent: "a touch of golden sun yellow"),
        Term(name: "小暑", season: "midsummer", palette: "turquoise, coral, sand and pale sky", accent: "a touch of sunlit lemon"),
        Term(name: "大暑", season: "midsummer", palette: "storm indigo, cobalt blue, pale cloud white and silver", accent: "a touch of fiery orange"),
        Term(name: "立秋", season: "early autumn", palette: "pale gold, sage green, soft sky blue and cream", accent: "a touch of first-leaf amber"),
        Term(name: "处暑", season: "early autumn", palette: "rice gold, terracotta, soft blue and warm white", accent: "a touch of burnt sienna"),
        Term(name: "白露", season: "mid autumn", palette: "silver white, pale lavender, misty grey-blue and pearl", accent: "a touch of soft rose"),
        Term(name: "秋分", season: "mid autumn", palette: "osmanthus gold, burnt orange, deep teal and cream", accent: "a touch of bright amber"),
        Term(name: "寒露", season: "late autumn", palette: "maple red, chrysanthemum yellow, slate blue and warm grey", accent: "a touch of deep crimson"),
        Term(name: "霜降", season: "late autumn", palette: "persimmon orange, muted gold, slate blue-grey and warm cream", accent: "a touch of bright persimmon red"),
        Term(name: "立冬", season: "early winter", palette: "smoky violet, dusty rose, pewter grey and pale cream", accent: "a touch of cold silver"),
        Term(name: "小雪", season: "early winter", palette: "ice blue, pale lilac, soft grey and snow white", accent: "a touch of pale rose gold"),
        Term(name: "大雪", season: "mid winter", palette: "snow white, deep navy, silver grey and pale blue", accent: "a touch of warm candle amber"),
        Term(name: "冬至", season: "midwinter", palette: "deep indigo, warm lantern amber, ink blue and soft cream", accent: "a touch of glowing lantern red"),
        Term(name: "小寒", season: "midwinter", palette: "plum, frost blue, pale grey and ivory", accent: "a touch of first-blossom pink"),
        Term(name: "大寒", season: "late winter", palette: "deep teal blue, wintersweet yellow, slate and pale ice", accent: "a touch of bright wintersweet gold"),
        Term(name: "立春", season: "early spring", palette: "pale willow green, blush pink, cream and light sky blue", accent: "a touch of fresh bud green"),
        Term(name: "雨水", season: "early spring", palette: "misty teal grey, soft peach, pale green and white", accent: "a touch of early plum pink"),
        Term(name: "惊蛰", season: "mid spring", palette: "fresh green, peach blossom pink, pale sky blue and cream", accent: "a touch of lilac"),
    ]

    // The style rotates daily, the composition every four days.
    static let styles: [Style] = [
        Style(name: "mesh", description: "Smooth blurred gradient mesh of luminous color fields blending softly into each other, like frosted glass",
              compositions: ["a large warm field at the left fading into cool tones toward the right",
                             "a luminous field rising from the bottom edge and fading upward",
                             "two soft color fields meeting diagonally from corner to corner",
                             "a single large soft glow at the upper left with calm tones elsewhere"]),
        Style(name: "layers", description: "Layered flat paper-cut hills and ridges as overlapping translucent bands with soft atmospheric gradients between layers, minimal and graphic",
              compositions: ["a large pale sun disc low on the horizon",
                             "a pale sun disc high above three receding ridges",
                             "no disc, five receding ridges fading into mist",
                             "a pale sun disc partly behind a ridge in the left third"]),
        Style(name: "silk", description: "Flowing satin silk ribbons of color in a few wide smooth curves with soft highlights, minimal and elegant",
              compositions: ["ribbons sweeping from the lower left toward the center",
                             "ribbons arcing from the top left corner down and across",
                             "ribbons forming one wide S-curve across the lower half",
                             "ribbons billowing upward from the bottom edge"]),
        Style(name: "geo", description: "Quiet minimal geometric composition of a few large overlapping circles and arcs in soft matte tones over a smooth gradient background, Bauhaus-inspired, restrained",
              compositions: ["three overlapping circles at the lower left",
                             "one very large circle cut by the frame edge with a smaller circle beside it",
                             "concentric arcs rising from the bottom edge",
                             "two large overlapping circles at the upper left and a thin arc below"]),
    ]

    static let smooth = "Perfectly smooth and clean: grain-free, noise-free, no texture, no fine details, no repeating or lattice-like patterns, no hatching, no tiny elements. Large soft forms with generous calm negative space; keep the right edge quiet and low-contrast. No text, no logos, no people."

    static let nightEdit = "Re-render this exact composition as a dark-mode wallpaper. Keep every shape, edge, curve and position identical; change only the lighting and tone. Keep the same hues but deepen them: the overall image becomes deep, low in luminance, rich and calm, with the lightest areas only moderately lit and the background turning to a near-black tint of the palette's darkest hue. A bright sun disc becomes a dimmer pale moon-like disc. Stay perfectly smooth and grain-free with no added texture, stars or details. No text, no watermark."

    /// Apparent solar longitude in degrees (Meeus ch. 25, ~0.01 deg accuracy).
    static func solarLongitude(unix: Double) -> Double {
        let jd = unix / 86_400 + 2_440_587.5
        let t = (jd - 2_451_545.0) / 36_525.0
        let l0 = 280.46646 + 36_000.76983 * t + 0.0003032 * t * t
        let m = (357.52911 + 35_999.05029 * t - 0.0001537 * t * t) * .pi / 180
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(m)
            + (0.019993 - 0.000101 * t) * sin(2 * m)
            + 0.000289 * sin(3 * m)
        let omega = (125.04 - 1_934.136 * t) * .pi / 180
        let apparent = l0 + c - 0.00569 - 0.00478 * sin(omega)
        return apparent.truncatingRemainder(dividingBy: 360) + (apparent < 0 ? 360 : 0)
    }

    /// Solar terms are defined in UTC+8, so a day starts at 00:00 CST.
    private static func longitudeAtCSTMidnight(_ day: Day) -> Double {
        solarLongitude(unix: Double(day.epochDays) * 86_400 - 8 * 3_600)
    }

    /// The term whose span contains `day`, and whether `day` is that term's first day.
    static func solarTerm(on day: Day) -> (index: Int, isFirstDay: Bool) {
        let start = Int(longitudeAtCSTMidnight(day) / 15) % 24
        let end = Int(longitudeAtCSTMidnight(day.adding(days: 1)) / 15) % 24
        return end != start ? (end, true) : (start, false)
    }

    /// Prompt for the light image, plus metadata. The dark image is an edit of the light one.
    static func prompts(for day: Day) -> Prompts {
        let (index, isTermDay) = solarTerm(on: day)
        let term = terms[index]
        let n = day.ordinal
        let style = styles[n % styles.count]
        let composition = style.compositions[(n / styles.count) % style.compositions.count]
        var light = "Abstract desktop wallpaper, 16:9, for light mode. \(style.description): \(composition). "
            + "Palette: \(term.palette). Overall bright and airy, mostly light tones with the deeper palette colors used sparingly."
        if isTermDay { light += " Include \(term.accent) as a single small luminous accent." }
        light += " \(smooth)"
        let theme = "\(term.name)\(isTermDay ? " (solar term day)" : " period"), \(style.name)"
        return Prompts(theme: theme, term: term.name, termDay: isTermDay, style: style.name, day: light, night: nightEdit)
    }
}
