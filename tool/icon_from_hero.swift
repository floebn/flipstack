// Symbol-Entwurf H: die Spielszene aus den Store-Grafiken (Turm, fallender
// Stein, Drehpfeile) auf dem cremefarbenen Grund. 1024×1024 ohne Transparenz.
// Aufruf: swift tool/icon_from_hero.swift
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
          blue: CGFloat(hex & 255) / 255, alpha: alpha).cgColor
}
let hero = NSImage(contentsOfFile: "assets_src/store/hero.png")!
  .cgImage(forProposedRect: nil, context: nil, hints: nil)!
let n: CGFloat = 1024
let ctx = CGContext(data: nil, width: Int(n), height: Int(n), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.interpolationQuality = .high
let bg = CGGradient(colorsSpace: nil, colors: [color(0xF6EFE2), color(0xE4D7C2)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: n), end: CGPoint(x: 0, y: 0), options: [])
// Weicher Schatten unter der Plattform.
ctx.saveGState()
ctx.translateBy(x: n * 0.5, y: n * 0.2)
ctx.scaleBy(x: 1, y: 0.42)
let sh = CGGradient(colorsSpace: nil, colors: [color(0x202B38, 0.22), color(0x202B38, 0)] as CFArray,
                    locations: [0, 1])!
ctx.drawRadialGradient(sh, startCenter: .zero, startRadius: 0, endCenter: .zero,
                       endRadius: n * 0.42, options: [])
ctx.restoreGState()
// Das Motiv füllt nur die Mitte seiner Datei, deshalb größer als das Bild zeichnen.
let size = n * 1.08
ctx.draw(hero, in: CGRect(x: (n - size) / 2, y: (n - size) / 2 + n * 0.02, width: size, height: size))
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
  .write(to: URL(fileURLWithPath: "store_assets/icon_entwuerfe/icon_h_turm.png"))
print("ICON_H_DONE")
