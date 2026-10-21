// Draws the installed Claude icon with a numbered badge, as a 1024px PNG.
// The icon is read from the user's own Claude.app at install time, so it
// always matches the Claude version they have installed.
// Usage: make-icon <out.png> <label> <hex color>
import AppKit

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write("usage: make-icon <out.png> <label> <hex>\n".data(using: .utf8)!)
    exit(2)
}
let (out, label, hex) = (args[1], args[2], args[3])

func color(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let size: CGFloat = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSWorkspace.shared.icon(forFile: "/Applications/Claude.app")
    .draw(in: NSRect(x: 0, y: 0, width: size, height: size))

// Badge in the bottom-right corner (AppKit's origin is bottom-left).
let (cx, cy, r, ring): (CGFloat, CGFloat, CGFloat, CGFloat) = (760, 264, 215, 14)
NSColor.white.setFill()
NSBezierPath(ovalIn: NSRect(x: cx - r - ring, y: cy - r - ring,
                            width: 2 * (r + ring), height: 2 * (r + ring))).fill()
color(hex).setFill()
NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)).fill()

var font = NSFont.systemFont(ofSize: label.count > 1 ? 210 : 290, weight: .bold)
if let rounded = font.fontDescriptor.withDesign(.rounded) {
    font = NSFont(descriptor: rounded, size: font.pointSize) ?? font
}
let text = NSAttributedString(string: label, attributes: [.font: font, .foregroundColor: NSColor.white])
// Glyph bounds relative to the baseline, so the digit itself is centred.
let glyphs = text.boundingRect(with: NSSize(width: 1000, height: 1000), options: [.usesDeviceMetrics])
let origin = NSPoint(x: cx - glyphs.width / 2 - glyphs.minX, y: cy - glyphs.height / 2 - glyphs.minY)
text.draw(with: NSRect(origin: origin, size: NSSize(width: 1000, height: 1000)), options: [])

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: out))
