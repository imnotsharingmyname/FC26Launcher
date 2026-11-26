#!/bin/bash
# Build script for FC 26 Launcher

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build"
APP_NAME="FC 26 Launcher"
RESOURCES="$PROJECT_DIR/Sources/FC26Launcher/Resources"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$RESOURCES/Info.plist")

echo "🔨 Building $APP_NAME..."

# Create build directory
mkdir -p "$BUILD_DIR"

# Build with Swift Package Manager
echo "📦 Building with SwiftPM..."
swift build -c release --arch arm64 --package-path "$PROJECT_DIR"

# Create app bundle
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$PROJECT_DIR/.build/release/FC26Launcher" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "$RESOURCES/Info.plist" "$APP_BUNDLE/Contents/"

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Include the setup script and the manifest in the signed app.
cp "$RESOURCES/prepare-fc26.py" "$RESOURCES/recomplauncher.json" "$APP_BUNDLE/Contents/Resources/"

# Draw a launcher icon without importing any game artwork.
cat > "$BUILD_DIR/create_icon.swift" << 'EOF'
import AppKit
let size: CGFloat = 512
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect.insetBy(dx: 40, dy: 40), xRadius: 80, yRadius: 80)
NSColor.systemBlue.setFill()
path.fill()
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 180),
    .foregroundColor: NSColor.white
]
let text = "FC26"
let textSize = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: (size - textSize.width)/2, y: (size - textSize.height)/2), withAttributes: attrs)
image.unlockFocus()
if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
EOF
swift "$BUILD_DIR/create_icon.swift" "$BUILD_DIR/icon_512.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512; do
    for scale in 1 2; do
        pixel_size=$((size * scale))
        suffix=""
        [ "$scale" -eq 2 ] && suffix="@2x"
        sips -s format png -z "$pixel_size" "$pixel_size" "$BUILD_DIR/icon_512.png" --out "$ICONSET_DIR/icon_${size}x${size}${suffix}.png" >/dev/null
    done
done
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Code sign (ad-hoc)
echo "🔏 Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

# RecompLauncher expects the manifest next to the .app at the top of the ZIP.
codesign --verify --deep --strict "$APP_BUNDLE"
cp "$RESOURCES/recomplauncher.json" "$BUILD_DIR/recomplauncher.json"
PACKAGE_DIR=$(mktemp -d "$BUILD_DIR/package.XXXXXX")
trap 'rm -rf "$PACKAGE_DIR"' EXIT
ARCHIVE="FC26Launcher-v$VERSION-macos-arm64.zip"
(cd "$BUILD_DIR" && /usr/bin/zip -q -r -y "$PACKAGE_DIR/$ARCHIVE" "$APP_NAME.app" recomplauncher.json)
mv -f "$PACKAGE_DIR/$ARCHIVE" "$BUILD_DIR/$ARCHIVE"

echo "✅ Build complete!"
echo "App location: $APP_BUNDLE"
echo "Release ZIP: $BUILD_DIR/$ARCHIVE"
echo ""
echo "To run: open \"$APP_BUNDLE\""
echo "To install: cp -R \"$APP_BUNDLE\" /Applications/"
