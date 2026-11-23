// Baut zwei Zusatzbilder für den Store-Auftritt:
//  - header_<sprache>.png: Banner mit Schriftzug und Motiv (2048×1000 und
//    1024×500, das zweite ist zugleich die "Feature Graphic" für Google Play)
//  - suchergebnis_<sprache>.png: Vorschau, wie Symbol, Name und die ersten drei
//    Bilder im Suchergebnis des App Store nebeneinander wirken (nur zur Ansicht)
//
// Aufruf: swift tool/store_extras.swift   (nach store_frames.swift)
import AppKit

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
func canvas(_ w: Int, _ h: Int) -> CGContext {
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
  ctx.interpolationQuality = .high
  return ctx
}
func save(_ ctx: CGContext, _ path: String) {
  try! FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                           withIntermediateDirectories: true)
  try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: path))
}

let out = "store_assets/extras"
let motif = cgImage("assets_src/icon/launch_g_fallend.png")
let icon = cgImage("assets_src/icon/icon_g_fallend.png")

func header(lang: String, w: Int, h: Int, suffix: String) {
  let ctx = canvas(w, h)
  let W = CGFloat(w), H = CGFloat(h), u = W / 2048
  ctx.setFillColor(color(0x202B38).cgColor)
  ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
  // Weicher Lichtfleck hinter dem Motiv.
  let glow = CGGradient(colorsSpace: nil, colors: [color(0x35B6A4, 0.38).cgColor,
                                                    color(0x35B6A4, 0).cgColor] as CFArray,
                        locations: [0, 1])!
  let c = CGPoint(x: W * 0.76, y: H * 0.5)
  ctx.drawRadialGradient(glow, startCenter: c, startRadius: 0, endCenter: c,
                         endRadius: 620 * u, options: [])
  let m = 900 * u
  ctx.draw(motif, in: CGRect(x: c.x - m / 2, y: c.y - m / 2 + 10 * u, width: m, height: m))

  let big = font(190 * u, .black)
  let flip = text("FLIP", big, color(0xF2EEE5), kern: 2 * u)
  let stack = text("STACK", big, color(0x35B6A4), kern: 2 * u)
  let x = 150 * u, y = H * 0.5 - 20 * u
  flip.draw(at: CGPoint(x: x, y: y))
  stack.draw(at: CGPoint(x: x + flip.size().width, y: y))
  let tag = lang == "de" ? "DREHEN  ·  STAPELN  ·  HOCH HINAUS" : "ROTATE  ·  STACK  ·  AIM HIGH"
  text(tag, font(44 * u, .bold), color(0xF2EEE5, 0.7), kern: 5 * u)
    .draw(at: CGPoint(x: x + 6 * u, y: y - 70 * u))
  save(ctx, "\(out)/header_\(lang)\(suffix).png")
}

func searchResult(lang: String) {
  let w = 1320, h = 1250
  let ctx = canvas(w, h)
  let W = CGFloat(w), H = CGFloat(h)
  ctx.setFillColor(color(0xFFFFFF).cgColor)
  ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
  let pad: CGFloat = 60
  // Symbol mit Apples Eckenrundung.
  let iconRect = CGRect(x: pad, y: H - pad - 220, width: 220, height: 220)
  ctx.saveGState()
  ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: 50, cornerHeight: 50, transform: nil))
  ctx.clip()
  ctx.draw(icon, in: iconRect)
  ctx.restoreGState()
  let name = lang == "de" ? "FlipStack: Dreh & Stapel" : "FlipStack: Spin & Stack"
  let sub = lang == "de" ? "Plattform drehen, Turm bauen" : "Rotate the platform, build up"
  text(name, NSFont.systemFont(ofSize: 52, weight: .semibold), color(0x000000))
    .draw(at: CGPoint(x: pad + 260, y: H - pad - 95))
  text(sub, NSFont.systemFont(ofSize: 40, weight: .regular), color(0x8A8A8E))
    .draw(at: CGPoint(x: pad + 260, y: H - pad - 155))
  // Laden-Knopf.
  let btn = CGRect(x: W - pad - 230, y: H - pad - 160, width: 230, height: 90)
  ctx.addPath(CGPath(roundedRect: btn, cornerWidth: 45, cornerHeight: 45, transform: nil))
  ctx.setFillColor(color(0xEFEFF4).cgColor)
  ctx.fillPath()
  let get = text(lang == "de" ? "LADEN" : "GET", NSFont.systemFont(ofSize: 40, weight: .bold), color(0x007AFF))
  get.draw(at: CGPoint(x: btn.midX - get.size().width / 2, y: btn.midY - get.size().height / 2))
  // Die ersten drei Bilder nebeneinander.
  let gap: CGFloat = 24
  let sw = (W - 2 * pad - 2 * gap) / 3
  for (i, n) in ["01_drehen", "02_turm", "03_stil"].enumerated() {
    let img = cgImage("store_assets/store_bilder/\(lang)/iphone_6_9/\(n).png")
    let sh = sw * CGFloat(img.height) / CGFloat(img.width)
    let r = CGRect(x: pad + CGFloat(i) * (sw + gap), y: H - pad - 220 - 60 - sh, width: sw, height: sh)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 40, cornerHeight: 40, transform: nil))
    ctx.clip()
    ctx.draw(img, in: r)
    ctx.restoreGState()
  }
  save(ctx, "\(out)/suchergebnis_\(lang).png")
}

for lang in ["de", "en"] {
  header(lang: lang, w: 2048, h: 1000, suffix: "")
  header(lang: lang, w: 1024, h: 500, suffix: "_1024x500")
  searchResult(lang: lang)
}
print("EXTRAS_DONE")
