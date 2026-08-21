import XCTest
@testable import Spidey

final class TempEmblemRenderTests: XCTestCase {
    func testRenderIronManEmblem() throws {
        let dir = "/private/tmp/claude-501/-Users-tanushpandey-Scripts-Spidey--claude-worktrees-spidey-feature-list-9f8ab6/bb23764a-8c57-462c-bd48-f71886be4bc9/scratchpad"
        let image = StatusIcons.watermark(for: .ironMan, size: 360, color: NSColor(red: 0.678, green: 0.106, blue: 0.086, alpha: 1))
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 360, pixelsHigh: 360, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 360, height: 360).fill()
        image.draw(in: NSRect(x: 0, y: 0, width: 360, height: 360))
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: dir + "/ironman-emblem.png"))
    }
}
