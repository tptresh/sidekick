import XCTest
@testable import Spidey

final class BookmarkStoreTests: XCTestCase {
    private let fixture = """
    {
      "roots": {
        "bookmark_bar": {
          "type": "folder",
          "name": "Bookmarks bar",
          "children": [
            {"type": "url", "name": "Hacker News", "url": "https://news.ycombinator.com/"},
            {
              "type": "folder",
              "name": "Dev",
              "children": [
                {"type": "url", "name": "Swift Forums", "url": "https://forums.swift.org/"},
                {
                  "type": "folder",
                  "name": "Docs",
                  "children": [
                    {"type": "url", "name": "Swift Book", "url": "https://docs.swift.org/swift-book/"}
                  ]
                }
              ]
            }
          ]
        },
        "other": {
          "type": "folder",
          "name": "Other bookmarks",
          "children": [
            {"type": "url", "name": "HN duplicate", "url": "https://news.ycombinator.com/"},
            {"type": "url", "name": "Grand Seiko", "url": "https://www.grand-seiko.com/"}
          ]
        },
        "synced": {
          "type": "folder",
          "name": "Mobile bookmarks",
          "children": []
        }
      },
      "version": 1
    }
    """

    func testParseWalksNestedFolders() {
        let parsed = BookmarkStore.parse(Data(fixture.utf8))
        XCTAssertEqual(parsed.count, 5)
        XCTAssertEqual(parsed.map(\.name), [
            "Hacker News", "Swift Forums", "Swift Book", "HN duplicate", "Grand Seiko",
        ])
        XCTAssertEqual(parsed.first?.host, "news.ycombinator.com")
    }

    func testDedupeKeepsFirstOccurrenceByURL() {
        let parsed = BookmarkStore.parse(Data(fixture.utf8))
        let merged = BookmarkStore.dedupe(parsed)
        XCTAssertEqual(merged.count, 4)
        XCTAssertTrue(merged.contains { $0.name == "Hacker News" })
        XCTAssertFalse(merged.contains { $0.name == "HN duplicate" })
    }

    func testParseRejectsMalformedJSON() {
        XCTAssertEqual(BookmarkStore.parse(Data("not json".utf8)), [])
        XCTAssertEqual(BookmarkStore.parse(Data("{\"version\": 1}".utf8)), [])
    }
}

final class BookmarksProviderTests: XCTestCase {
    private let bookmarks: [Bookmark] = (1...20).map {
        Bookmark(name: "Recipe \($0)", url: "https://example.com/recipe/\($0)")
    } + [
        Bookmark(name: "Weekly planner", url: "https://planner.example.org/"),
        Bookmark(name: "Bank statements", url: "https://mybank.example.net/"),
    ]

    func testAmbientKeepsOnlyStrongNameMatchesCappedToThree() {
        let matches = BookmarksProvider.rank("recipe", in: bookmarks, mode: .ambient)
        XCTAssertEqual(matches.count, 3)
        // "cip" is only a substring match (0.7): too weak for ambient mode.
        XCTAssertTrue(BookmarksProvider.rank("cip", in: bookmarks, mode: .ambient).isEmpty)
    }

    func testAmbientScoresSitBelowAppsAndSiteDirectory() {
        let matches = BookmarksProvider.rank("weekly planner", in: bookmarks, mode: .ambient)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].score, 400)
        XCTAssertLessThan(matches[0].score, 600)
    }

    func testDedicatedMatchesHostnameAndCapsAtFifteen() {
        XCTAssertEqual(BookmarksProvider.rank("recipe", in: bookmarks, mode: .dedicated).count, 15)
        let byHost = BookmarksProvider.rank("mybank", in: bookmarks, mode: .dedicated)
        XCTAssertEqual(byHost.count, 1)
        XCTAssertEqual(byHost[0].bookmark.name, "Bank statements")
    }

    func testShortQueriesMatchNothing() {
        XCTAssertTrue(BookmarksProvider.rank("r", in: bookmarks, mode: .ambient).isEmpty)
        XCTAssertTrue(BookmarksProvider.rank("r", in: bookmarks, mode: .dedicated).isEmpty)
    }
}
