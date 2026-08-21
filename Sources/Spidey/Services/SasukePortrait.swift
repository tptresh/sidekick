import AppKit

// The picture of Sasuke the theme entrance shows, bundled in the app's
// Resources.
//
// It is a still from the series rather than something drawn here, so it is the
// one asset in this repo that is not ours to relicense. Swap or drop it before
// the project is open sourced; the entrance handles it being missing.
enum SasukePortrait {
    private static var cached: NSImage?
    private static var didLoad = false

    static func image() -> NSImage? {
        if !didLoad {
            didLoad = true
            cached = Bundle.main.url(forResource: "sasuke", withExtension: "png")
                .flatMap { NSImage(contentsOf: $0) }
        }
        return cached
    }
}
