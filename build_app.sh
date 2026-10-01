#!/bin/bash
set -e

if [ -d "/Library/Developer/CommandLineTools" ]; then
    export DEVELOPER_DIR="/Library/Developer/CommandLineTools"
fi

echo "🔨 Building SiriEdge (Release configuration)..."
swift build -c release --target SiriEdge

APP_NAME="SiriEdge"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Creating macOS App Bundle: ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
cp "SiriEdge/Resources/Shaders/EdgeGlow.metal" "${RESOURCES_DIR}/EdgeGlow.metal"
cp SiriEdge/Resources/*.png "${RESOURCES_DIR}/" 2>/dev/null || true

# Copy SPM resource bundle if present
find .build -name "SiriEdge_SiriEdge.bundle" -exec cp -R {} "${RESOURCES_DIR}/" \; 2>/dev/null || true

cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SiriEdge</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.SiriEdge</string>
    <key>CFBundleName</key>
    <string>SiriEdge</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ Successfully generated ${APP_BUNDLE}!"
echo "🚀 You can now launch SiriEdge with: open ${APP_BUNDLE} or swift run"
