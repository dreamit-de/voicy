import AppKit

// Composites a full-bleed icon image (e.g. docs/assets/voicy-logo-master.png)
// onto a 1024 canvas with Apple's standard margins (824px content) and a
// subtle drop shadow, for use as the macOS app icon.
//
// Usage:
//   swift scripts/compose-app-icon.swift docs/assets/voicy-logo-master.png icon_1024.png
//   for s in 16 32 64 128 256 512; do sips -z $s $s icon_1024.png --out icon_$s.png; done
//   then copy into Voicy/Resources/Assets.xcassets/AppIcon.appiconset/
//   (filenames per Contents.json: 16/32/128/256/512 each at 1x and @2x)

let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]

guard let src = NSImage(contentsOfFile: input) else { exit(1) }

let canvas: CGFloat = 1024
let content: CGFloat = 824
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
gctx.cgContext.setShadow(offset: CGSize(width: 0, height: -10), blur: 22,
                         color: NSColor.black.withAlphaComponent(0.3).cgColor)
let origin = (canvas - content) / 2
src.draw(in: CGRect(x: origin, y: origin, width: content, height: content),
         from: .zero, operation: .sourceOver, fraction: 1.0)
gctx.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: output))
print("written \(output)")
