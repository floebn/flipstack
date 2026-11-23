// Erzeugt die Textbilder für die Kurzvideos (1080×1920, transparent):
// Untertitel-Kästen im Stil von TikTok und die Schlusskarte.
// Aufruf: swift tool/tiktok_overlays.swift <zielordner>
// Zusammengeschnitten wird mit tool/tiktok_videos.sh.
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "store_assets/tiktok/overlays"
try! FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
          blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
  let base = NSFont.systemFont(ofSize: size, weight: weight)
  return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
}
func canvas() -> CGContext {
  let ctx = CGContext(data: nil, width: 1080, height: 1920, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
  return ctx
}
func save(_ ctx: CGContext, _ name: String) {
  try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}

/// Untertitel: je Zeile ein weißer Kasten mit dunkler Schrift, mittig.
/// [top] = Abstand der ersten Zeile vom oberen Bildrand.
func caption(_ name: String, _ lines: [String], top: CGFloat = 360, size: CGFloat = 66,
             accentLine: Int? = nil) {
  let ctx = canvas()
  var y = 1920 - top
  for (i, line) in lines.enumerated() {
    let accent = i == accentLine
    let s = NSAttributedString(string: line, attributes: [
      .font: font(size, .heavy),
      .foregroundColor: accent ? color(0xFFFFFF) : color(0x202B38),
      .kern: -0.5,
    ])
    let t = s.size()
    let box = CGRect(x: (1080 - t.width) / 2 - 30, y: y - t.height - 14, width: t.width + 60,
                     height: t.height + 28)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: color(0x000000, 0.28).cgColor)
    ctx.addPath(CGPath(roundedRect: box, cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.setFillColor((accent ? color(0xF27C65) : color(0xFFFFFF)).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
    s.draw(at: CGPoint(x: (1080 - t.width) / 2, y: box.minY + 14))
    y = box.minY - 10
  }
  save(ctx, name)
}

/// Schlusskarte: Symbol, Name, Kernsatz und Hinweis auf den Store.
func endCard(_ name: String, line: String) {
  let ctx = canvas()
  let bg = CGGradient(colorsSpace: nil, colors: [color(0xF6EFE2).cgColor, color(0xE4D7C2).cgColor] as CFArray,
                      locations: [0, 1])!
  ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 1920), end: .zero, options: [])
  let icon = NSImage(contentsOfFile: "assets_src/icon/icon_g_fallend.png")!
    .cgImage(forProposedRect: nil, context: nil, hints: nil)!
  let r = CGRect(x: 540 - 210, y: 1050, width: 420, height: 420)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 50, color: color(0x202B38, 0.3).cgColor)
  ctx.addPath(CGPath(roundedRect: r, cornerWidth: 96, cornerHeight: 96, transform: nil))
  ctx.setFillColor(color(0xFFFFFF).cgColor)
  ctx.fillPath()
  ctx.restoreGState()
  ctx.saveGState()
  ctx.addPath(CGPath(roundedRect: r, cornerWidth: 96, cornerHeight: 96, transform: nil))
  ctx.clip()
  ctx.interpolationQuality = .high
  ctx.draw(icon, in: r)
  ctx.restoreGState()

  let f = font(128, .black)
  let flip = NSAttributedString(string: "FLIP", attributes: [.font: f, .foregroundColor: color(0x202B38), .kern: 2])
  let stack = NSAttributedString(string: "STACK", attributes: [.font: f, .foregroundColor: color(0x35B6A4), .kern: 2])
  let w = flip.size().width + stack.size().width
  flip.draw(at: CGPoint(x: (1080 - w) / 2, y: 850))
  stack.draw(at: CGPoint(x: (1080 - w) / 2 + flip.size().width, y: 850))

  let sub = NSAttributedString(string: line, attributes: [
    .font: font(50, .bold), .foregroundColor: color(0x202B38, 0.75)])
  sub.draw(at: CGPoint(x: (1080 - sub.size().width) / 2, y: 760))

  let cta = NSAttributedString(string: "Kostenlos im App Store", attributes: [
    .font: font(56, .heavy), .foregroundColor: color(0xFFFFFF)])
  let t = cta.size()
  let pill = CGRect(x: (1080 - t.width) / 2 - 56, y: 590, width: t.width + 112, height: t.height + 52)
  ctx.addPath(CGPath(roundedRect: pill, cornerWidth: pill.height / 2, cornerHeight: pill.height / 2, transform: nil))
  ctx.setFillColor(color(0x35B6A4).cgColor)
  ctx.fillPath()
  cta.draw(at: CGPoint(x: (1080 - t.width) / 2, y: pill.minY + 26))
  save(ctx, name)
}

// Video 1: die Regel
caption("v1_a", ["Du kannst den Stein", "NICHT drehen."], accentLine: 1)
caption("v1_b", ["Nur die Plattform. 🔄"])
caption("v1_c", ["Klingt einfach."])
caption("v1_d", ["Ist es nicht. 😅"])
// Video 2: das gute Gefühl
caption("v2_a", ["POV: Du findest das Spiel,", "bei dem alles passt 😌"])
caption("v2_b", ["Jede saubere Ablage", "erhöht die Combo 🔥"])
caption("v2_c", ["Combo ×2,0", "= doppelte Punkte"], accentLine: 0)
caption("v2_d", ["Volle Ebene ✨"])
// Video 3: die Herausforderung
caption("v3_a", ["Wie hoch kommst du,", "bevor nichts mehr passt?"])
caption("v3_b", ["Je höher der Turm,", "desto fieser die Steine"])
caption("v3_c", ["Ein falscher Stein", "und es ist vorbei 👀"])
caption("v3_d", ["Mein Rekord: Höhe 67", "Und deiner?"], top: 250, accentLine: 0)

endCard("end_1", line: "Dreh die Plattform, nicht den Stein.")
endCard("end_2", line: "Stapeln. Abschalten. Nochmal.")
endCard("end_3", line: "Wie hoch kommst du?")
print("OVERLAYS_DONE")
