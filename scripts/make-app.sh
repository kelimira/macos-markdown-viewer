#!/bin/sh
# Builds MarkdownViewer.app (with .md file association) into ./build.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/MarkdownViewer.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp .build/release/MarkdownViewer "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MarkdownViewer</string>
<key>CFBundleIdentifier</key><string>local.markdownviewer</string>
<key>CFBundleExecutable</key><string>MarkdownViewer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
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
echo "Built $APP"
