import XCTest
@testable import Spidey

final class ScriptOutputParsingTests: XCTestCase {
    func testJSONItems() {
        let stdout = """
        {"items": [
            {"title": "Branch", "subtitle": "current git branch", "arg": "main", "action": "copy"},
            {"title": "Repo", "arg": "https://github.com/x/y", "action": "open"}
        ]}
        """
        let output = ScriptCommandStore.parseOutput(stdout)
        XCTAssertEqual(output, .items([
            .init(title: "Branch", subtitle: "current git branch", arg: "main", action: .copy),
            .init(title: "Repo", subtitle: "", arg: "https://github.com/x/y", action: .open),
        ]))
    }

    func testJSONDefaults() {
        let output = ScriptCommandStore.parseOutput(#"{"items": [{"title": "Hello"}]}"#)
        XCTAssertEqual(output, .items([
            .init(title: "Hello", subtitle: "", arg: "Hello", action: .copy),
        ]))
    }

    func testUnknownActionFallsBackToCopy() {
        let output = ScriptCommandStore.parseOutput(
            #"{"items": [{"title": "T", "arg": "x", "action": "paste-to-clipboard"}]}"#
        )
        XCTAssertEqual(output, .items([.init(title: "T", subtitle: "", arg: "x", action: .copy)]))
    }

    func testJSONWithTrailingNewline() {
        let output = ScriptCommandStore.parseOutput("{\"items\": [{\"title\": \"A\"}]}\n")
        XCTAssertEqual(output, .items([.init(title: "A", subtitle: "", arg: "A", action: .copy)]))
    }

    func testEmptyOrTitlelessItemsFallBackToPlain() {
        XCTAssertEqual(
            ScriptCommandStore.parseOutput(#"{"items": []}"#),
            .plain(#"{"items": []}"#)
        )
        XCTAssertEqual(
            ScriptCommandStore.parseOutput(#"{"items": [{"title": "  "}]}"#),
            .plain(#"{"items": [{"title": "  "}]}"#)
        )
    }

    func testMalformedJSONIsPlain() {
        XCTAssertEqual(
            ScriptCommandStore.parseOutput(#"{"items": [{"title":"#),
            .plain(#"{"items": [{"title":"#)
        )
        XCTAssertEqual(
            ScriptCommandStore.parseOutput(#"{"results": [1, 2]}"#),
            .plain(#"{"results": [1, 2]}"#)
        )
    }

    func testPlainTextStaysPlain() {
        XCTAssertEqual(
            ScriptCommandStore.parseOutput("42 files\ndetails here"),
            .plain("42 files\ndetails here")
        )
    }
}

final class ScriptDescriptionTests: XCTestCase {
    func testHashLeader() {
        let source = "#!/bin/bash\n# spidey: Shows the weather\necho hi"
        XCTAssertEqual(ScriptCommandStore.description(fromSource: source), "Shows the weather")
    }

    func testOtherCommentLeaders() {
        XCTAssertEqual(
            ScriptCommandStore.description(fromSource: "// spidey: JS tool"),
            "JS tool"
        )
        XCTAssertEqual(
            ScriptCommandStore.description(fromSource: "-- spidey: Lua tool"),
            "Lua tool"
        )
        XCTAssertEqual(
            ScriptCommandStore.description(fromSource: "; spidey: Lisp tool"),
            "Lisp tool"
        )
    }

    func testCaseInsensitiveMarker() {
        XCTAssertEqual(
            ScriptCommandStore.description(fromSource: "# Spidey: Mixed case"),
            "Mixed case"
        )
    }

    func testBeyondFirstFiveLinesIgnored() {
        let source = "#!/bin/bash\n\n\n\n\n# spidey: too late"
        XCTAssertNil(ScriptCommandStore.description(fromSource: source))
    }

    func testMissingOrEmptyDescription() {
        XCTAssertNil(ScriptCommandStore.description(fromSource: "#!/bin/bash\necho hi"))
        XCTAssertNil(ScriptCommandStore.description(fromSource: "# spidey:   "))
        XCTAssertNil(ScriptCommandStore.description(fromSource: ""))
    }
}

final class ScriptScanTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpideyScriptScanTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func write(_ name: String, executable: Bool, contents: String = "#!/bin/bash\necho hi") throws {
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: url.path
        )
    }

    func testScanFindsOnlyExecutables() throws {
        try write("weather.sh", executable: true, contents: "#!/bin/bash\n# spidey: Shows the weather\necho hi")
        try write("notes.txt", executable: false)
        try write(".hidden.sh", executable: true)
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("subdir"), withIntermediateDirectories: true
        )

        let commands = ScriptCommandStore.scan(directory: directory)
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.keyword, "weather")
        XCTAssertEqual(commands.first?.description, "Shows the weather")
    }

    func testKeywordDropsExtensionAndLowercases() throws {
        try write("MyTool.py", executable: true)
        XCTAssertEqual(ScriptCommandStore.scan(directory: directory).first?.keyword, "mytool")
    }

    func testMissingDirectoryScansEmpty() {
        let missing = directory.appendingPathComponent("nope")
        XCTAssertTrue(ScriptCommandStore.scan(directory: missing).isEmpty)
    }
}
