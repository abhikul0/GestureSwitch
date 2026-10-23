#!/bin/bash
set -e

APP_NAME="GestureSwitch"
BUNDLE_DIR="$APP_NAME.app"
ICONSET_dir="AppIcon.iconset"

echo "🎨 Generating app icon..."
mkdir -p "$ICONSET_dir"

# Create a temporary Swift script to draw a high-res macOS style icon image
cat << 'EOF' > generate_icon.swift
import AppKit

let size = CGSize(width: 512, height: 512)
let image = NSImage(size: size)

image.lockFocus()
let context = NSGraphicsContext.current?.cgContext

// Background Rounded Rect with macOS style gradient
let rect = CGRect(origin: .zero, size: size)
let path = CGPath(roundedRect: rect, cornerWidth: 110, cornerHeight: 110, transform: nil)
context?.addPath(path)
context?.clip()

let colors = [NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0).cgColor,
              NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 1.0).cgColor]
let colorSpace = CGColorSpaceCreateDeviceRGB()
if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
    context?.drawLinearGradient(gradient, start: CGPoint(x: 256, y: 512), end: CGPoint(x: 256, y: 0), options: [])
}

// Draw inner window card representation
let windowRect = CGRect(x: 96, y: 128, width: 320, height: 256)
let windowPath = CGPath(roundedRect: windowRect, cornerWidth: 24, cornerHeight: 24, transform: nil)
context?.setFillColor(NSColor(calibratedWhite: 1.0, alpha: 0.1).cgColor)
context?.addPath(windowPath)
context?.fillPath()

// Draw active selection highlight bar
let highlightRect = CGRect(x: 116, y: 220, width: 280, height: 52)
let highlightPath = CGPath(roundedRect: highlightRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
context?.setFillColor(NSColor.systemBlue.cgColor)
context?.addPath(highlightPath)
context?.fillPath()

// Draw swipe gesture arrow indicator
let arrowPath = NSBezierPath()
arrowPath.move(to: CGPoint(x: 210, y: 310))
arrowPath.line(to: CGPoint(x: 160, y: 310))
arrowPath.line(to: CGPoint(x: 185, y: 290))
arrowPath.move(to: CGPoint(x: 160, y: 310))
arrowPath.line(to: CGPoint(x: 185, y: 330))
arrowPath.lineWidth = 10
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
NSColor.white.setStroke()
arrowPath.stroke()

image.unlockFocus()

// Export standard icon sizes for iconset
let resolutions = [16, 32, 64, 128, 256, 512]
for res in resolutions {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: res * 2, pixelsHigh: res * 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    rep?.size = NSSize(width: res, height: res)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep!)
    image.draw(in: CGRect(x: 0, y: 0, width: res, height: res), from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    
    if let data = rep?.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: "AppIcon.iconset/icon_\(res)x\(res).png"))
        if res <= 256 {
            try? data.write(to: URL(fileURLWithPath: "AppIcon.iconset/icon_\(res)x\(res)@2x.png"))
        }
    }
}
try? image.tiffRepresentation?.write(to: URL(fileURLWithPath: "AppIcon.iconset/icon_512x512@2x.png"))
EOF

swiftc generate_icon.swift -o generate_icon
./generate_icon
rm -f generate_icon generate_icon.swift

# Convert iconset to .icns
iconutil -c icns AppIcon.iconset
rm -rf "$ICONSET_dir"

echo "🔨 Compiling and packaging $APP_NAME..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Update Info.plist to reference the icon file
cat << 'EOF' > Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GestureSwitch</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.GestureSwitch</string>
    <key>CFBundleName</key>
    <string>GestureSwitch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
</dict>
</plist>
EOF

cp Info.plist "$BUNDLE_DIR/Contents/Info.plist"
mv AppIcon.icns "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"

# Compile Swift source
swiftc -O GestureSwitch.swift -o "$BUNDLE_DIR/Contents/MacOS/$APP_NAME" -framework AppKit -framework ApplicationServices

# Sign app bundle
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "✅ Success! Created $BUNDLE_DIR with a custom icon."
echo "👉 To refresh icon cache (if needed), run: touch GestureSwitch.app"