import AgentCronCore
import Foundation
import Testing

/// Just enough of the String Catalog to read one plural entry's English forms.
private struct PluralCatalog: Decodable {
    let strings: [String: PluralEntry]
}

private struct PluralEntry: Decodable {
    private enum CodingKeys: String, CodingKey {
        case localizations
    }

    let localizations: [String: PluralLocalization]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localizations = try container.decodeIfPresent(
            [String: PluralLocalization].self,
            forKey: .localizations,
        ) ?? [:]
    }
}

private struct PluralLocalization: Decodable {
    struct Variations: Decodable {
        let plural: [String: Form]
    }

    struct Form: Decodable {
        let stringUnit: StringUnit
    }

    struct StringUnit: Decodable {
        let value: String
    }

    let variations: Variations?
}

@MainActor
@Suite("PopoverText")
struct PopoverTextTests {
    private static let usEnglish = Locale(identifier: "en_US")
    private static let start = Date(timeIntervalSince1970: 1_790_640_000)

    @Test
    func `the failure banner reads many runs, and its catalog entry is plural`() throws {
        #expect(PopoverText.failureBanner(count: 2)
            .resolved(in: .english) == "2 failed runs since you last looked.")
        // `swift test` does not compile the catalog, so the singular is read from it.
        let url = LocalizationTests.coreSources.appending(path: "Resources/Localizable.xcstrings")
        let catalog = try JSONDecoder().decode(PluralCatalog.self, from: Data(contentsOf: url))
        let english = catalog.strings["popover.banner.failures"]?.localizations["en"]
        let one = try #require(english?.variations?.plural["one"]?.stringUnit.value)
        #expect(String(format: one, 1) == "1 failed run since you last looked.")
    }

    @Test(arguments: [
        (0.0, "0:00"),
        (252.0, "4:12"),
        (3_599.0, "59:59"),
        (3_725.0, "1:02:05"),
        (-5.0, "0:00"),
    ])
    func `elapsed time reads as a clock`(seconds: TimeInterval, expected: String) {
        let now = Self.start.addingTimeInterval(seconds)
        #expect(PopoverText.elapsed(since: Self.start, now: now) == expected)
    }

    @Test
    func `the remaining keep-awake time reads as hours and minutes`() {
        #expect(PopoverText.remaining(.seconds(14_340))
            .resolved(in: .english) == "(3:59 left)")
        #expect(PopoverText.remaining(.seconds(59)).resolved(in: .english) == "(0:00 left)")
    }

    @Test
    func `a finished run's duration reads in one narrow unit`() {
        #expect(PopoverText.duration(.seconds(120), locale: Self.usEnglish) == "2m")
        #expect(PopoverText.duration(.seconds(45), locale: Self.usEnglish) == "45s")
    }

    @Test
    func `a cost reads in dollars and cents`() {
        #expect(PopoverText.cost(Decimal(string: "0.12") ?? 0, locale: Self.usEnglish) == "$0.12")
        #expect(PopoverText.cost(Decimal(3), locale: Self.usEnglish) == "$3.00")
    }
}
