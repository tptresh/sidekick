import AppKit

// The picture used for the Sasuke theme's entrance.
//
// It lives in Application Support rather than in the repo on purpose: a still
// from the anime is someone else's artwork, and this project is headed for
// being open sourced, so nothing here should ship a copy of it. Point the app
// at a file in Preferences and it is copied next to the rest of the app's data;
// with no file set, the entrance falls back to the drawn face.
enum SasukePortrait {
    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Spidey/sasuke-portrait.png")
    }

    static var folderPath: String { "~/Library/Application Support/Spidey" }

    private static var cached: NSImage?
    private static var didLoad = false

    static func image() -> NSImage? {
        if !didLoad {
            didLoad = true
            cached = NSImage(contentsOf: fileURL)
        }
        return cached
    }

    // Re-encoded as PNG rather than copied, so any format NSImage can open
    // (jpeg, webp, heic) works and the stored file is always one we can read.
    static func install(from source: URL) -> Bool {
        guard let image = NSImage(contentsOf: source),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return false }
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard (try? png.write(to: fileURL)) != nil else { return false }
        didLoad = false
        return true
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        didLoad = false
        cached = nil
    }
}
