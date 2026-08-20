import XCTest
@testable import Spidey

final class DevToolsProviderTests: XCTestCase {
    func testBase64RoundTrip() {
        XCTAssertEqual(DevToolsProvider.base64Encode("hello"), "aGVsbG8=")
        XCTAssertEqual(DevToolsProvider.base64Decode("aGVsbG8="), "hello")
        // Missing padding is tolerated.
        XCTAssertEqual(DevToolsProvider.base64Decode("aGVsbG8"), "hello")
        XCTAssertNil(DevToolsProvider.base64Decode("!!not base64!!"))
    }

    func testURLEncodeDecode() {
        XCTAssertEqual(DevToolsProvider.urlEncode("hello world&x=1"), "hello%20world%26x%3D1")
        XCTAssertEqual(DevToolsProvider.urlEncode("safe-._~"), "safe-._~")
        XCTAssertEqual(DevToolsProvider.urlDecode("hello%20world%26x%3D1"), "hello world&x=1")
        XCTAssertEqual(DevToolsProvider.urlDecode("a+b"), "a b")
        XCTAssertNil(DevToolsProvider.urlDecode("bad%zz"))
    }

    func testHashes() {
        XCTAssertEqual(
            DevToolsProvider.sha256Hex("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        XCTAssertEqual(DevToolsProvider.md5Hex("abc"), "900150983cd24fb0d6963f7d28e17f72")
    }

    func testEpochParsing() {
        XCTAssertEqual(
            DevToolsProvider.date(fromEpoch: "1700000000")?.timeIntervalSince1970, 1_700_000_000
        )
        // 13-digit values read as milliseconds.
        XCTAssertEqual(
            DevToolsProvider.date(fromEpoch: "1700000000000")?.timeIntervalSince1970, 1_700_000_000
        )
        XCTAssertNil(DevToolsProvider.date(fromEpoch: "not a number"))
        XCTAssertNil(DevToolsProvider.date(fromEpoch: "-5"))
    }

    func testISOParsing() {
        XCTAssertEqual(
            DevToolsProvider.date(fromISO: "2023-11-14T22:13:20Z")?.timeIntervalSince1970,
            1_700_000_000
        )
        XCTAssertEqual(
            DevToolsProvider.date(fromISO: "2023-11-14T22:13:20.500Z")
                .map { $0.timeIntervalSince1970 } ?? 0,
            1_700_000_000.5, accuracy: 0.001
        )
        XCTAssertEqual(
            DevToolsProvider.date(fromISO: "2023-11-14")?.timeIntervalSince1970,
            1_699_920_000
        )
        XCTAssertNil(DevToolsProvider.date(fromISO: "yesterday"))
    }

    func testUTCFormatting() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(DevToolsProvider.format(date, utc: true), "2023-11-14 22:13:20")
    }

    func testResultsRecognizeKeywords() {
        XCTAssertEqual(DevToolsProvider.results(for: "uuid").count, 2)
        XCTAssertEqual(DevToolsProvider.results(for: "b64 hi").first?.title, "aGk=")
        XCTAssertEqual(DevToolsProvider.results(for: "b64d aGk=").first?.title, "hi")
        XCTAssertEqual(DevToolsProvider.results(for: "sha256 abc").first?.title.count, 64)
        XCTAssertEqual(DevToolsProvider.results(for: "ts").count, 2)
        XCTAssertEqual(DevToolsProvider.results(for: "ts 1700000000").count, 2)
        XCTAssertEqual(
            DevToolsProvider.results(for: "ts 2023-11-14T22:13:20Z").first?.title, "1700000000"
        )
        XCTAssertTrue(DevToolsProvider.results(for: "safari").isEmpty)
        XCTAssertTrue(DevToolsProvider.results(for: "b64").isEmpty)
    }

    func testArgumentKeepsOriginalCase() {
        XCTAssertEqual(DevToolsProvider.results(for: "b64 Hello").first?.title, "SGVsbG8=")
    }
}

final class LargeTypeProviderTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(LargeTypeProvider.parse("large ABC-123"), "ABC-123")
        XCTAssertEqual(LargeTypeProvider.parse("lt hello there"), "hello there")
        XCTAssertNil(LargeTypeProvider.parse("large "))
        XCTAssertNil(LargeTypeProvider.parse("lte 4g"))
        XCTAssertNil(LargeTypeProvider.parse("largely fine"))
    }
}

final class QRProviderTests: XCTestCase {
    func testGeneratesImageAndPNG() {
        XCTAssertNotNil(QRProvider.qrImage(for: "https://example.com", size: 32))
        let png = QRProvider.pngData(for: "https://example.com")
        XCTAssertNotNil(png)
        // PNG magic bytes.
        XCTAssertEqual(png?.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
    }

    func testResultsRequireText() {
        XCTAssertTrue(QRProvider.results(for: "qr").isEmpty)
        XCTAssertTrue(QRProvider.results(for: "qr ").isEmpty)
        XCTAssertEqual(QRProvider.results(for: "qr hello").count, 1)
    }
}

final class SystemInfoProviderTests: XCTestCase {
    func testLocalIPAddressesSkipLoopback() {
        for (interface, address) in SystemInfoProvider.localIPAddresses() {
            XCTAssertNotEqual(interface, "lo0")
            XCTAssertNotEqual(address, "127.0.0.1")
        }
    }

    func testDiskSpaceIsSane() throws {
        let space = try XCTUnwrap(SystemInfoProvider.diskSpace())
        XCTAssertGreaterThan(space.total, 0)
        XCTAssertGreaterThanOrEqual(space.total, space.free)
    }
}
