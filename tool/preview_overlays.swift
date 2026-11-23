// Textbilder für das App-Store-Vorschauvideo (886×1920, transparent).
// Aufruf: swift tool/preview_overlays.swift <zielordner>
import AppKit

let out = CommandLine.arguments[1]
try! FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
          blue: CGFloat(hex & 255) / 255, alpha: a)
}
func caption(_ name: String, _ lines: [String]) {
  let W: CGFloat = 886, H: CGFloat = 1920
  let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
  let base = NSFont.systemFont(ofSize: 56, weight: .heavy)
  let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 56) } ?? base
  var y = H - 400
  for (i, line) in lines.enumerated() {
    let accent = i == lines.count - 1
    let s = NSAttributedString(string: line, attributes: [
      .font: font, .foregroundColor: accent ? color(0xFFFFFF) : color(0x202B38), .kern: -0.5])
    let t = s.size()
    let box = CGRect(x: (W - t.width) / 2 - 26, y: y - t.height - 12, width: t.width + 52, height: t.height + 24)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -5), blur: 16, color: color(0, 0.28).cgColor)
    ctx.addPath(CGPath(roundedRect: box, cornerWidth: 22, cornerHeight: 22, transform: nil))
    ctx.setFillColor((accent ? color(0x35B6A4) : color(0xFFFFFF)).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    s.draw(at: CGPoint(x: (W - t.width) / 2, y: box.minY + 12))
    y = box.minY - 8
  }
  try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
caption("de_1", ["Dreh die Plattform,", "nicht den Stein."])
caption("de_2", ["Sauber stapeln,", "Combo aufbauen"])
caption("de_3", ["Wie hoch", "kommst du?"])
caption("en_1", ["Rotate the platform,", "not the piece."])
caption("en_2", ["Stack cleanly,", "build your combo"])
caption("en_3", ["How high", "can you go?"])
