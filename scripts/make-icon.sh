#!/usr/bin/env bash
# scripts/make-icon.sh
#
# Generate a placeholder App icon for Lumina Music.
#
# Visual: §9.0 purple radial gradient (#7C5CFF → #2A1A6E) + a stylized
# sound-wave glyph in white. Pure swift+CoreGraphics rendering — no external
# image deps. Output: Resources/AppIcon.icns (and intermediate AppIcon.iconset).
#
# Usage:  ./scripts/make-icon.sh
#
# Idempotent — re-run any time to refresh.

set -euo pipefail

cd "$(dirname "$0")/.."

ICONSET="Resources/AppIcon.iconset"
ICNS="Resources/AppIcon.icns"
TMPPNG="$(mktemp -d)/icon-1024.png"

echo "─── Lumina Music · App Icon ───"

# 1. Render 1024² master PNG via Swift+CoreGraphics
SWIFT_RENDERER="$(mktemp).swift"
cat > "$SWIFT_RENDERER" <<'SWIFT_EOF'
import AppKit
import CoreGraphics
import Foundation

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// Squircle (rounded-rect with iOS/macOS app icon corner ratio ~22%)
let radius: CGFloat = CGFloat(size) * 0.225
let squircle = CGPath(
    roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil
)
ctx.addPath(squircle)
ctx.clip()

// Radial gradient: #2A1A6E (deep) → #7C5CFF (brand)
let center = CGPoint(x: CGFloat(size) * 0.5, y: CGFloat(size) * 0.42)
let deep = CGColor(red: 0x2A/255.0, green: 0x1A/255.0, blue: 0x6E/255.0, alpha: 1)
let bright = CGColor(red: 0x7C/255.0, green: 0x5C/255.0, blue: 0xFF/255.0, alpha: 1)
let glow = CGColor(red: 0xC9/255.0, green: 0xB8/255.0, blue: 0xFF/255.0, alpha: 1)
let grad = CGGradient(
    colorsSpace: cs,
    colors: [glow, bright, deep] as CFArray,
    locations: [0.0, 0.45, 1.0]
)!
ctx.drawRadialGradient(
    grad,
    startCenter: center, startRadius: 0,
    endCenter: center, endRadius: CGFloat(size) * 0.85,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

// Soft top highlight (vertical linear gradient overlay) for depth
let highlight = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray,
    locations: [0.0, 0.55]
)!
ctx.drawLinearGradient(
    highlight,
    start: CGPoint(x: 0, y: CGFloat(size)),
    end: CGPoint(x: 0, y: CGFloat(size) * 0.35),
    options: []
)

// Sound-wave glyph: 5 vertical bars with rounded caps, varying heights,
// centered at 50% width / 50% height. White, slight glow.
let glyphCount = 5
let glyphW: CGFloat = CGFloat(size) * 0.072
let glyphSpacing: CGFloat = CGFloat(size) * 0.046
let totalW = CGFloat(glyphCount) * glyphW + CGFloat(glyphCount - 1) * glyphSpacing
let glyphHeights: [CGFloat] = [0.30, 0.58, 0.78, 0.45, 0.26]
let baselineY: CGFloat = CGFloat(size) * 0.50

ctx.saveGState()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
ctx.setShadow(
    offset: .zero, blur: CGFloat(size) * 0.012,
    color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.6)
)

let startX = (CGFloat(size) - totalW) * 0.5
for i in 0..<glyphCount {
    let h = glyphHeights[i] * CGFloat(size) * 0.5
    let x = startX + CGFloat(i) * (glyphW + glyphSpacing)
    let y = baselineY - h / 2
    let bar = CGPath(
        roundedRect: CGRect(x: x, y: y, width: glyphW, height: h),
        cornerWidth: glyphW * 0.5, cornerHeight: glyphW * 0.5,
        transform: nil
    )
    ctx.addPath(bar)
    ctx.fillPath()
}
ctx.restoreGState()

// Subtle inner shadow at top edge for depth
ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()
let edgeShadow = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0, green: 0, blue: 0, alpha: 0.16),
        CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
    ] as CFArray,
    locations: [0.0, 0.08]
)!
ctx.drawLinearGradient(
    edgeShadow,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 0, y: CGFloat(size) * 0.10),
    options: []
)
ctx.restoreGState()

guard let img = ctx.makeImage() else { exit(2) }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
if !CGImageDestinationFinalize(dest) { exit(3) }
print("rendered \(size)x\(size) → \(url.path)")
SWIFT_EOF

# Note: need ImageIO (for CGImageDestination) → uses CoreServices → -framework Foundation, AppKit, ImageIO, CoreServices
swift -O -framework AppKit -framework ImageIO -framework CoreServices \
    "$SWIFT_RENDERER" "$TMPPNG"

ls -la "$TMPPNG"

# 2. Generate the 10-image iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

render() {
  local px="$1" name="$2"
  sips -z "$px" "$px" "$TMPPNG" --out "$ICONSET/$name" > /dev/null
  echo "  ${px}²  →  $name"
}

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

# 3. Build the .icns
rm -f "$ICNS"
iconutil -c icns "$ICONSET" -o "$ICNS"

# 4. Cleanup
rm -rf "$ICONSET"
rm -f "$SWIFT_RENDERER"

echo ""
echo "✓ Generated $ICNS ($(stat -f '%z' "$ICNS") bytes)"
