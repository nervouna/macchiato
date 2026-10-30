import XCTest

final class SeasonTests: XCTestCase {
    func testSolarTermDatesIn2026() {
        let expected: [String: [Int]] = [
            "小寒": [1, 5], "大寒": [1, 20], "立春": [2, 4], "雨水": [2, 18], "惊蛰": [3, 5], "春分": [3, 20],
            "清明": [4, 5], "谷雨": [4, 20], "立夏": [5, 5], "小满": [5, 21], "芒种": [6, 5], "夏至": [6, 21],
            "小暑": [7, 7], "大暑": [7, 23], "立秋": [8, 7], "处暑": [8, 23], "白露": [9, 7], "秋分": [9, 23],
            "寒露": [10, 8], "霜降": [10, 23], "立冬": [11, 7], "小雪": [11, 22], "大雪": [12, 7], "冬至": [12, 22],
        ]
        var found: [String: [Int]] = [:]
        var day = Day(year: 2026, month: 1, day: 1)
        while day.year == 2026 {
            let (index, isFirstDay) = Season.solarTerm(on: day)
            if isFirstDay { found[Season.terms[index].name] = [day.month, day.day] }
            day = day.adding(days: 1)
        }
        XCTAssertEqual(found, expected)
    }

    func testStyleRotatesDailyAndTermDayAddsAccent() {
        let styles = (0..<8).map { Season.prompts(for: Day(year: 2026, month: 11, day: 8).adding(days: $0)).style }
        XCTAssertEqual(Array(styles[0..<4]), Array(styles[4..<8]))
        XCTAssertEqual(Set(styles).count, 4)

        let termDay = Season.prompts(for: Day(year: 2026, month: 11, day: 7))
        XCTAssertTrue(termDay.termDay)
        XCTAssertEqual(termDay.term, "立冬")
        XCTAssertTrue(termDay.day.contains("luminous accent"))
        XCTAssertFalse(Season.prompts(for: Day(year: 2026, month: 11, day: 8)).day.contains("luminous accent"))
    }

    func testDayArithmetic() {
        XCTAssertEqual(Day(year: 2026, month: 10, day: 31).ordinal, 739_920)
        XCTAssertEqual(Day(year: 1970, month: 1, day: 1).ordinal, 719_163)
        XCTAssertEqual(Day(year: 2026, month: 12, day: 31).adding(days: 1).description, "2027-01-01")
        XCTAssertEqual(Day(year: 2028, month: 2, day: 28).adding(days: 1).description, "2028-02-29")
        XCTAssertEqual(Day("2026-10-31")?.description, "2026-10-31")
        XCTAssertNil(Day("2026-13-01"))
    }
}
