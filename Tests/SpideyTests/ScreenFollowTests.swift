import AppKit
import XCTest
@testable import Spidey

final class ScreenFollowTests: XCTestCase {
    // A laptop at the origin and a wide monitor to its right, Cocoa coordinates.
    let laptop = NSRect(x: 0, y: 0, width: 1512, height: 945)
    let wide = NSRect(x: 1512, y: 0, width: 3440, height: 1415)

    func testPicksTheScreenContainingTheClick() {
        let screens = [laptop, wide]
        XCTAssertEqual(ScreenFollow.index(of: NSPoint(x: 2000, y: 500), in: screens), 1)
        XCTAssertEqual(ScreenFollow.index(of: NSPoint(x: 100, y: 100), in: screens), 0)
    }

    func testPointOffEveryScreenFallsBackToTheNearest() {
        XCTAssertEqual(ScreenFollow.index(of: NSPoint(x: 6000, y: 700), in: [laptop, wide]), 1)
    }

    func testWindowKeepsItsRelativePlaceAndSize() {
        let window = NSRect(x: 100, y: 100, width: 800, height: 600)
        let moved = ScreenFollow.relocate(window, from: laptop, to: wide)
        XCTAssertEqual(moved.size, window.size)
        XCTAssertTrue(wide.contains(moved))
    }

    func testTooBigWindowShrinksToFit() {
        let window = NSRect(x: 0, y: 0, width: 3000, height: 1400)
        let moved = ScreenFollow.relocate(window, from: wide, to: laptop)
        XCTAssertTrue(laptop.contains(moved))
        XCTAssertEqual(moved.width, laptop.width)
        XCTAssertEqual(moved.height, laptop.height)
    }

    func testWindowMostlyOnTheTargetIsLeftAlone() {
        let window = NSRect(x: 1600, y: 100, width: 800, height: 600)
        XCTAssertFalse(ScreenFollow.needsMove(window, target: wide))
        XCTAssertTrue(ScreenFollow.needsMove(window, target: laptop))
    }

    func testNamedAppMovesOnlyOnceItIsInFront() {
        XCTAssertFalse(ScreenFollow.isOpenedWindow(
            frontBundleID: "com.other", expected: "com.brave.Browser", changed: true, elapsed: 2))
        XCTAssertTrue(ScreenFollow.isOpenedWindow(
            frontBundleID: "com.brave.Browser", expected: "com.brave.Browser", changed: true, elapsed: 0.2))
    }

    func testAlreadyFrontWindowWaitsBrieflyForANewOne() {
        XCTAssertFalse(ScreenFollow.isOpenedWindow(
            frontBundleID: "com.brave.Browser", expected: "com.brave.Browser", changed: false, elapsed: 0.3))
        XCTAssertTrue(ScreenFollow.isOpenedWindow(
            frontBundleID: "com.brave.Browser", expected: "com.brave.Browser", changed: false, elapsed: 1))
    }

    func testUnknownAppNeedsAChangedWindow() {
        XCTAssertFalse(ScreenFollow.isOpenedWindow(frontBundleID: "x", expected: nil, changed: false, elapsed: 5))
        XCTAssertTrue(ScreenFollow.isOpenedWindow(frontBundleID: "x", expected: nil, changed: true, elapsed: 0.2))
    }
}
