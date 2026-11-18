#!/bin/sh
# Builds MarkdownViewer.app (with .md file association) and a release zip into ./build.
# Usage: scripts/make-app.sh [version]
set -e
VERSION="${1:-1.0}"
cd "$(dirname "$0")/.."
swift build -c release --arch arm64 --arch x86_64
APP=build/MarkdownViewer.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MarkdownViewer" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MarkdownViewer</string>
<key>CFBundleIdentifier</key><string>local.markdownviewer</string>
<key>CFBundleExecutable</key><string>MarkdownViewer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>VERSION_PLACEHOLDER</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>Markdown</string>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSHandlerRank</key><string>Alternate</string>
<key>LSItemContentTypes</key><array><string>net.daringfireball.markdown</string><string>public.plain-text</string></array>
<key>CFBundleTypeExtensions</key><array><string>md</string><string>markdown</string></array>
</dict></array>
</dict></plist>
PL
sed -i '' "s/VERSION_PLACEHOLDER/$VERSION/" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP" # ad-hoc: unsigned arm64 binaries won't launch
ZIP="build/MarkdownViewer-$VERSION.zip"
rm -f "$ZIP"; ditto -c -k --keepParent "$APP" "$ZIP"
# Register with Launch Services so "Open With" lists the app right away.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true
echo "Built $APP and $ZIP"
