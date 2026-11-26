#!/bin/bash
# Build script for FC 26 Launcher

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build"
APP_NAME="FC 26 Launcher"
BUNDLE_ID="com.fc26launcher.app"
VERSION="1.0.0"

echo "🔨 Building $APP_NAME..."

# Create build directory
mkdir -p "$BUILD_DIR"

# Build with Swift Package Manager
echo "📦 Building with SwiftPM..."
swift build -c release --package-path "$PROJECT_DIR"

# Create app bundle
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$PROJECT_DIR/.build/release/FC26Launcher" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/FC26Launcher/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Copy recomplauncher.json to app bundle (for RecompLauncher support)
cp "$PROJECT_DIR/Sources/FC26Launcher/Resources/recomplauncher.json" "$APP_BUNDLE/Contents/Resources/recomplauncher.json"

# Create app icon from the game's icon if available, otherwise create a placeholder
ICON_SOURCE="/Users/faycalelhandi/Documents/NSP GAMES/FC 26/01004FF021942000_build/extract/v1179648/icon.jpg"
if [ -f "$ICON_SOURCE" ]; then
    echo "🎨 Creating app icon from game icon..."
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"

    for size in 16 32 128 256 512; do
        for scale in 1 2; do
            pixel_size=$((size * scale))
            suffix=""
            [ $scale -eq 2 ] && suffix="@2x"
            sips -s format png -z $pixel_size $pixel_size "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}${suffix}.png" 2>/dev/null
        done
    done

    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "⚠️ Game icon not found, creating placeholder..."
    # Create a simple placeholder icon
    cat > "$BUILD_DIR/create_icon.swift" << 'EOF'
import AppKit
let size = 512
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
    try png.write(to: URL(fileURLWithPath: "/Users/faycalelhandi/FC26Launcher/.build/icon_512.png"))
}
EOF
    swift run -c release --package-path "$PROJECT_DIR" create_icon 2>/dev/null || true

    if [ -f "$BUILD_DIR/icon_512.png" ]; then
        ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
        mkdir -p "$ICONSET_DIR"
        for size in 16 32 128 256 512; do
            for scale in 1 2; do
                pixel_size=$((size * scale))
                suffix=""
                [ $scale -eq 2 ] && suffix="@2x"
                sips -s format png -z $pixel_size $pixel_size "$BUILD_DIR/icon_512.png" --out "$ICONSET_DIR/icon_${size}x${size}${suffix}.png" 2>/dev/null
            done
        done
        iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    fi
fi

# Code sign (ad-hoc)
echo "🔏 Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Build complete!"
echo "App location: $APP_BUNDLE"
echo ""
echo "To run: open \"$APP_BUNDLE\""
echo "To install: cp -R \"$APP_BUNDLE\" /Applications/"
