import AppKit
import XCTest
@testable import Spidey

// Contract for the Keep Mac Awake icon: the emblem itself takes the theme's
// awake color (Spider-Man red, Batman white) and stays a template when idle.
final class AwakeIconTests: XCTestCase {
    private func pixels(_ image: NSImage) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: 36, height: 36))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private func opaqueColors(_ image: NSImage) -> [NSColor] {
        let rep = pixels(image)
        var colors: [NSColor] = []
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.6 {
                    colors.append(color)
                }
            }
        }
        return colors
    }

    func testIdleIconIsTemplate() {
        for theme in HeroTheme.allCases {
            XCTAssertTrue(StatusIcons.menuBarIcon(for: theme, awake: false).isTemplate)
        }
    }

    func testAwakeIconIsColoredNotTemplate() {
        for theme in HeroTheme.allCases {
            XCTAssertFalse(StatusIcons.menuBarIcon(for: theme, awake: true).isTemplate,
                           "\(theme) awake icon must keep its own color")
        }
    }

    func testAwakeTintPerTheme() {
        let red = StatusIcons.awakeTint(for: .spiderman).usingColorSpace(.deviceRGB)!
        XCTAssertGreaterThan(red.redComponent, 0.7)
        XCTAssertLessThan(red.greenComponent, 0.35)
        let white = StatusIcons.awakeTint(for: .batman).usingColorSpace(.deviceRGB)!
        XCTAssertGreaterThan(white.redComponent, 0.9)
        XCTAssertGreaterThan(white.greenComponent, 0.9)
        XCTAssertGreaterThan(white.blueComponent, 0.9)
    }

    func testSpidermanAwakeIconActuallyRendersRed() {
        let colors = opaqueColors(StatusIcons.menuBarIcon(for: .spiderman, awake: true))
        let reds = colors.filter { $0.redComponent > 0.6 && $0.greenComponent < 0.35 }
        XCTAssertGreaterThan(reds.count, colors.count / 2, "most of the emblem should be red")
    }

    func testBatmanAwakeIconActuallyRendersWhite() {
        let colors = opaqueColors(StatusIcons.menuBarIcon(for: .batman, awake: true))
        let whites = colors.filter { $0.redComponent > 0.85 && $0.greenComponent > 0.85 && $0.blueComponent > 0.85 }
        XCTAssertGreaterThan(whites.count, colors.count / 3, "the bat should be white")
    }

    // Visibility: the bat covered about 10% of its square and read as a smudge
    // at menu bar size; Spider-Man was about 34%. Neither may be fainter than this.
    func testEmblemsHaveEnoughInkToBeVisible() {
        let minimum: [HeroTheme: Double] = [.spiderman: 0.34, .batman: 0.18]
        for theme in HeroTheme.allCases {
            let ink = opaqueColors(StatusIcons.menuBarIcon(for: theme, awake: false)).count
            XCTAssertGreaterThan(Double(ink) / (36 * 36), minimum[theme] ?? 0.2, "\(theme) emblem is too faint")
        }
    }
}

// Contract for the weather location: when Core Location cannot deliver a fix,
// the panel falls back to a typed city or an approximate network location
// instead of showing nothing.
final class WeatherLocationTests: XCTestCase {
    func testSourcePrefersManualCity() {
        XCTAssertEqual(
            WeatherStore.locationSource(authorized: true, coreLocationFailed: false, manualCity: "Paris"),
            .manual
        )
    }

    func testSourceUsesCoreLocationWhenItWorks() {
        XCTAssertEqual(
            WeatherStore.locationSource(authorized: true, coreLocationFailed: false, manualCity: nil),
            .coreLocation
        )
    }

    func testSourceFallsBackWhenCoreLocationFailsOrIsDenied() {
        XCTAssertEqual(
            WeatherStore.locationSource(authorized: true, coreLocationFailed: true, manualCity: nil),
            .network
        )
        XCTAssertEqual(
            WeatherStore.locationSource(authorized: false, coreLocationFailed: false, manualCity: "  "),
            .network
        )
    }

    func testParsesOpenMeteoGeocodingResult() {
        let json = #"{"results":[{"name":"London","latitude":51.50853,"longitude":-0.12574,"country":"United Kingdom"}]}"#
        let place = WeatherStore.parseGeocoding(Data(json.utf8))
        XCTAssertEqual(place?.name, "London")
        XCTAssertEqual(place?.latitude ?? 0, 51.50853, accuracy: 0.0001)
        XCTAssertEqual(place?.longitude ?? 0, -0.12574, accuracy: 0.0001)
        XCTAssertNil(WeatherStore.parseGeocoding(Data(#"{"generationtime_ms":0.5}"#.utf8)))
    }

    func testParsesNetworkLocation() {
        let json = #"{"success":true,"city":"Toronto","latitude":43.65,"longitude":-79.38}"#
        let place = WeatherStore.parseNetworkLocation(Data(json.utf8))
        XCTAssertEqual(place?.name, "Toronto")
        XCTAssertEqual(place?.latitude ?? 0, 43.65, accuracy: 0.0001)
        XCTAssertNil(WeatherStore.parseNetworkLocation(Data(#"{"success":false}"#.utf8)))
    }
}
