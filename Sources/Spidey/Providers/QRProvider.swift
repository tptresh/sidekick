import AppKit
import CoreImage

// "qr <text>": the row's icon is a live QR preview. Return copies the PNG,
// Cmd+Return saves qr.png to the Desktop and reveals it in Finder.
enum QRProvider {
    static func qrImage(for text: String, size: CGFloat) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        // Integer-scale the tiny module grid so the squares stay crisp.
        let scale = max(1, (size / output.extent.width).rounded(.down))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let representation = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }

    static func pngData(for text: String, size: CGFloat = 512) -> Data? {
        guard let image = qrImage(for: text, size: size),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix("qr ") else { return [] }
        let text = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let preview = qrImage(for: text, size: 32) else { return [] }
        preview.size = NSSize(width: 32, height: 32)
        return [ResultItem(
            title: "QR code for \"\(text)\"",
            subtitle: "Return copies the PNG. Cmd+Return saves qr.png to the Desktop.",
            icon: .appIcon(preview),
            score: 950,
            secondaryAction: { saveToDesktop(text: text) },
            action: {
                guard let png = pngData(for: text) else { return }
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setData(png, forType: .png)
            }
        )]
    }

    private static func saveToDesktop(text: String) {
        guard let png = pngData(for: text),
              let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        else { return }
        var url = desktop.appendingPathComponent("qr.png")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = desktop.appendingPathComponent("qr \(counter).png")
            counter += 1
        }
        guard (try? png.write(to: url)) != nil else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
