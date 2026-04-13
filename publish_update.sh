#!/bin/bash
# publish_update.sh - Sign and publish a new Notext update
# Usage: ./publish_update.sh /path/to/Notext.app

set -e

APP_PATH="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPCAST="$SCRIPT_DIR/appcast.xml"
SPARKLE_BIN="$SCRIPT_DIR/.local-build/SourcePackages/artifacts/sparkle/Sparkle/bin"

if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 /path/to/Notext.app"
    echo "Example: $0 ~/Downloads/Notext.app"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

APP_NAME="Notext"
ZIP_NAME="${APP_NAME}.zip"
ZIP_PATH="/tmp/$ZIP_NAME"

# Get version info
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
APP_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")

echo "📦 Notext v$APP_VERSION (build $APP_BUILD)"

# Create zip
echo "🗜️ Creating $ZIP_NAME..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
ZIP_SIZE=$(stat -f%z "$ZIP_PATH")

# Sign the update
echo "✍️ Signing update..."
SIGN_OUTPUT=$("$SPARKLE_BIN/sign_update" "$ZIP_PATH" 2>&1)
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')

if [ -z "$ED_SIGNATURE" ]; then
    echo "❌ Failed to sign update. Make sure Sparkle tools are built."
    exit 1
fi

echo "✅ Signature: $ED_SIGNATURE"

# Create appcast entry
PUB_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$APPCAST" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.sparkle-project.org/xml/1.0">
  <channel>
    <title>Notext Updates</title>
    <link>https://raw.githubusercontent.com/EVELETTE/Notext/main/appcast.xml</link>
    <description>Most recent changes with links to updates.</description>
    <language>en</language>
    <item>
      <title>Version $APP_VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$APP_BUILD</sparkle:version>
      <sparkle:shortVersionString>$APP_VERSION</sparkle:shortVersionString>
      <enclosure
          url="https://github.com/EVELETTE/Notext/releases/download/v$APP_VERSION/$ZIP_NAME"
          sparkle:edSignature="$ED_SIGNATURE"
          length="$ZIP_SIZE"
          type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
EOF

echo ""
echo "✅ appcast.xml updated"
echo ""
echo "Next steps:"
echo "1. Create a GitHub release: gh release create v$APP_VERSION --title \"Notext v$APP_VERSION\" --generate-notes"
echo "2. Upload the zip: gh release upload v$APP_VERSION $ZIP_PATH"
echo "3. Commit and push appcast.xml: git add appcast.xml && git commit -m \"Update appcast for v$APP_VERSION\" && git push"
