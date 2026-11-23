// Baut Apples "Creative Assets" für die Produktseite:
//  - Header der Produktseite: 3840×1646 (21:9), Sicherheitsbereich 1646×661 bei (1097, 493)
//  - Suchergebnis: 3840×2560 (3:2), Sicherheitsbereich 2168×1030 bei (836, 765)
// Alles Wichtige liegt im Sicherheitsbereich, der Rest ist Stimmung und darf
// je nach Gerät abgeschnitten werden. PNG ohne Transparenz.
// Vorgaben: developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
//
// Aufruf: swift tool/store_creative.swift [--debug]   (--debug zeichnet den Sicherheitsbereich ein)
// Quelle: assets_src/store/*.png aus tools/blender/render_store_art.py
import AppKit

let debug = CommandLine.arguments.contains("--debug")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
          blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func cgImage(_ path: String) -> CGImage {
  NSImage(contentsOfFile: path)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
  let base = NSFont.systemFont(ofSize: size, weight: weight)
  return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
}
func text(_ s: String, _ f: NSFont, _ c: NSColor, kern: CGFloat = 0) -> NSAttributedString {
  NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c, .kern: kern])
}

let hero = cgImage("assets_src/store/hero.png")
let cubes = ["mint", "amber", "sky", "plum", "coral", "leaf", "block_cream"]
  .map { cgImage("assets_src/store/cube_\($0).png") }

/// Fester Zufall, damit jedes Bild bei jedem Lauf gleich aussieht.
struct Rng {
  var s: UInt64
  mutating func next() -> CGFloat {
    s = s &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((s >> 33) % 100_000) / 100_000
  }
}

/// Zeichnet das Bild. `safe` in Apples Angabe: Ursprung oben links.
func compose(w: Int, h: Int, safe: CGRect, seed: UInt64, path: String,
             content: (CGContext, CGRect) -> Void) {
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
  ctx.interpolationQuality = .high
  let W = CGFloat(w), H = CGFloat(h)
  // Sicherheitsbereich in Zeichenkoordinaten (Ursprung unten links).
  let s = CGRect(x: safe.minX, y: H - safe.maxY, width: safe.width, height: safe.height)

  // Grund: warmes Creme wie im Spiel, mit zwei weichen Farbflecken.
  let bg = CGGradient(colorsSpace: nil, colors: [color(0xF6EFE2).cgColor, color(0xE7DBC8).cgColor] as CFArray,
                      locations: [0, 1])!
  ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
  for (hex, cx, cy, r) in [(UInt32(0x35B6A4), 0.18, 0.75, 0.55), (UInt32(0xF27C65), 0.86, 0.2, 0.5),
                           (UInt32(0xF1BD58), 0.6, 0.95, 0.4)] {
    let g = CGGradient(colorsSpace: nil, colors: [color(hex, 0.22).cgColor, color(hex, 0).cgColor] as CFArray,
                       locations: [0, 1])!
    let c = CGPoint(x: W * cx, y: H * cy)
    ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: W * r, options: [])
  }

  // Schwebende Würfel außerhalb des Sicherheitsbereichs: klein und blass hinten,
  // groß und kräftig vorn.
  var rng = Rng(s: seed)
  let keepOut = s.insetBy(dx: -W * 0.035, dy: -H * 0.05)
  var placed: [(CGRect, CGFloat, Int)] = []
  var tries = 0
  while placed.count < 26 && tries < 4000 {
    tries += 1
    let depth = rng.next()
    let size = W * (0.035 + 0.085 * depth)
    let r = CGRect(x: rng.next() * (W + size) - size, y: rng.next() * (H + size) - size,
                   width: size, height: size)
    let k = Int(rng.next() * CGFloat(cubes.count)) % cubes.count
    if r.intersects(keepOut) { continue }
    if placed.contains(where: { $0.0.insetBy(dx: -size * 0.35, dy: -size * 0.35).intersects(r) }) { continue }
    placed.append((r, depth, k))
  }
  for (r, depth, k) in placed.sorted(by: { $0.1 < $1.1 }) {
    ctx.setAlpha(0.3 + 0.7 * depth)
    ctx.draw(cubes[k], in: r)
  }
  ctx.setAlpha(1)

  content(ctx, s)

  if debug {
    ctx.setStrokeColor(color(0xFF00FF).cgColor)
    ctx.setLineWidth(6)
    ctx.stroke(s)
  }
  try! FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                           withIntermediateDirectories: true)
  try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: path))
}

/// Der Turm füllt nur die Mitte seiner quadratischen Datei; `box` ist die
/// Fläche, in die das eigentliche Motiv passen soll.
func drawHero(_ ctx: CGContext, fitting box: CGRect) {
  let content = CGRect(x: 0.12, y: 0.08, width: 0.76, height: 0.82)  // Anteil mit Motiv
  let scale = min(box.width / content.width, box.height / content.height)
  let origin = CGPoint(x: box.midX - (content.midX) * scale, y: box.midY - (content.midY) * scale)
  ctx.draw(hero, in: CGRect(x: origin.x, y: origin.y, width: scale, height: scale))
}

func wordmark(at p: CGPoint, size: CGFloat) -> CGFloat {
  let f = font(size, .black)
  let flip = text("FLIP", f, color(0x202B38), kern: size * 0.01)
  let stack = text("STACK", f, color(0x35B6A4), kern: size * 0.01)
  flip.draw(at: p)
  stack.draw(at: CGPoint(x: p.x + flip.size().width, y: p.y))
  return flip.size().width + stack.size().width
}

let out = debug ? CommandLine.arguments.last! : "store_assets/creative_assets"

// Header: eine klare Idee, sprachneutral. Turm links, Schriftzug rechts.
compose(w: 3840, h: 1646, safe: CGRect(x: 1097, y: 493, width: 1646, height: 661), seed: 11,
        path: "\(out)/header_3840x1646.png") { ctx, s in
  drawHero(ctx, fitting: CGRect(x: s.minX, y: s.minY, width: 640, height: s.height))
  _ = wordmark(at: CGPoint(x: s.minX + 670, y: s.midY - 64), size: 160)
}

// Suchergebnis: sofort klar, worum es geht. Kurzer Satz links, Spielszene rechts.
for (lang, l1, l2) in [("de", "Dreh die Plattform,", "nicht den Stein."),
                       ("en", "Rotate the platform,", "not the piece.")] {
  compose(w: 3840, h: 2560, safe: CGRect(x: 836, y: 765, width: 2168, height: 1030), seed: 23,
          path: "\(out)/suche_\(lang)_3840x2560.png") { ctx, s in
    drawHero(ctx, fitting: CGRect(x: s.maxX - 1000, y: s.minY, width: 1000, height: s.height))
    let x = s.minX + 20
    // Der Schriftzug trägt das Bild, der Satz darunter erklärt.
    _ = wordmark(at: CGPoint(x: x, y: s.midY + 10), size: 220)
    let f = font(84, .heavy)
    text(l1, f, color(0x202B38), kern: -0.5).draw(at: CGPoint(x: x + 6, y: s.midY - 130))
    text(l2, f, color(0xF27C65), kern: -0.5).draw(at: CGPoint(x: x + 6, y: s.midY - 236))
  }
}
print("CREATIVE_DONE")
