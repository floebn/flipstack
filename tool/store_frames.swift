// Baut aus den rohen Simulator-Aufnahmen die Store-Bilder: farbiger Grund,
// Überschrift oben, darunter die Aufnahme mit runden Ecken und Schatten.
//
// Aufruf: swift tool/store_frames.swift
// Quelle: store_assets/screenshots/<sprache>/iphone_6_9/*.png
// Ziel:   store_assets/store_bilder/<sprache>/<größe>/*.png (ohne Transparenz)
import AppKit

struct Shot {
  let source: String, name: String, bg: UInt32, fg: UInt32, accent: UInt32
  let de: [String], en: [String]
}

// Die ersten drei stehen im Store nebeneinander im Suchergebnis.
let shots = [
  Shot(source: "01_spiel", name: "01_drehen", bg: 0x35B6A4, fg: 0xFFFFFF, accent: 0x202B38,
       de: ["Dreh die Plattform,", "nicht den Stein"], en: ["Rotate the platform,", "not the piece"]),
  Shot(source: "02_winter", name: "02_turm", bg: 0x202B38, fg: 0xF2EEE5, accent: 0x35B6A4,
       de: ["Bau den", "höchsten Turm"], en: ["Build the", "tallest tower"]),
  Shot(source: "03_neon", name: "03_stil", bg: 0xF27C65, fg: 0xFFFFFF, accent: 0x202B38,
       de: ["Spiel in", "deinem Stil"], en: ["Play in", "your style"]),
  Shot(source: "06_shop", name: "04_designs", bg: 0x5FA8D8, fg: 0xFFFFFF, accent: 0x202B38,
       de: ["Schalte neue", "Designs frei"], en: ["Unlock", "new designs"]),
  Shot(source: "04_ergebnis", name: "05_bestwert", bg: 0xF1BD58, fg: 0x202B38, accent: 0xFFFFFF,
       de: ["Jag deinen", "Bestwert"], en: ["Beat your", "high score"]),
  Shot(source: "05_start", name: "06_aufgaben", bg: 0x9585CC, fg: 0xFFFFFF, accent: 0x202B38,
       de: ["Jeden Tag", "neue Aufgaben"], en: ["New quests", "every day"]),
]

let sizes: [(String, Int, Int)] = [("iphone_6_9", 1320, 2868), ("iphone_6_3", 1206, 2622)]

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
          blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func render(_ shot: Shot, lang: String, w: Int, h: Int, to path: String) {
  let src = "store_assets/screenshots/\(lang)/iphone_6_9/\(shot.source).png"
  guard let image = NSImage(contentsOfFile: src),
        let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("FEHLT", src); return
  }
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  let W = CGFloat(w), H = CGFloat(h), u = W / 1320  // Maße bezogen auf 1320 Breite
  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

  // Grund mit leichtem Verlauf nach unten dunkler.
  ctx.setFillColor(color(shot.bg).cgColor)
  ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
  let grad = CGGradient(colorsSpace: nil, colors: [color(0x000000, 0).cgColor,
                                                    color(0x000000, 0.16).cgColor] as CFArray,
                        locations: [0, 1])!
  ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

  // Überschrift: erste Zeile in Schriftfarbe, zweite in der Akzentfarbe.
  let lines = lang == "de" ? shot.de : shot.en
  let base = NSFont.systemFont(ofSize: 112 * u, weight: .black)
  let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 112 * u) } ?? base
  var y = H - 250 * u
  for (i, line) in lines.enumerated() {
    let attr: [NSAttributedString.Key: Any] = [
      .font: font, .foregroundColor: color(i == 0 ? shot.fg : shot.accent), .kern: -1.5 * u,
    ]
    let s = NSAttributedString(string: line, attributes: attr)
    let size = s.size()
    s.draw(at: CGPoint(x: (W - size.width) / 2, y: y - size.height / 2))
    y -= 132 * u
  }

  // Aufnahme: runde Ecken, Schatten, heller Rahmen; läuft unten leicht aus dem Bild.
  let fw = 1040 * u, fh = fw * CGFloat(cg.height) / CGFloat(cg.width)
  let top = H - 520 * u
  let frame = CGRect(x: (W - fw) / 2, y: top - fh, width: fw, height: fh)
  let radius = 96 * u
  let outer = frame.insetBy(dx: -14 * u, dy: -14 * u)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -24 * u), blur: 70 * u,
                color: color(0x000000, 0.35).cgColor)
  ctx.addPath(CGPath(roundedRect: outer, cornerWidth: radius + 14 * u, cornerHeight: radius + 14 * u, transform: nil))
  ctx.setFillColor(color(0x161E28).cgColor)
  ctx.fillPath()
  ctx.restoreGState()
  ctx.saveGState()
  ctx.addPath(CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil))
  ctx.clip()
  ctx.interpolationQuality = .high
  ctx.draw(cg, in: frame)
  ctx.restoreGState()

  let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
  try! FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                           withIntermediateDirectories: true)
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

for lang in ["de", "en"] {
  for (dir, w, h) in sizes {
    for shot in shots {
      render(shot, lang: lang, w: w, h: h, to: "store_assets/store_bilder/\(lang)/\(dir)/\(shot.name).png")
    }
  }
}
print("FRAMES_DONE")
