#!/bin/bash
set -e

if [ -d "/Library/Developer/CommandLineTools" ]; then
    export DEVELOPER_DIR="/Library/Developer/CommandLineTools"
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAVER_NAME="SiriEdge"
SAVER_BUNDLE="${PROJECT_DIR}/${SAVER_NAME}.saver"
MACOS_DIR="${SAVER_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${SAVER_BUNDLE}/Contents/Resources"

echo "🔨 Building ${SAVER_NAME}.saver (macOS Screen Saver Bundle)..."

rm -rf "${SAVER_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Compile the Screen Saver dynamic library with Apple Silicon optimization
swiftc \
    -target arm64-apple-macos13.0 \
    -emit-library \
    -o "${MACOS_DIR}/SiriEdgeScreenSaver" \
    -module-name SiriEdgeScreenSaver \
    -framework ScreenSaver \
    -framework Metal \
    -framework MetalKit \
    -framework AppKit \
    -framework SwiftUI \
    -framework QuartzCore \
    -framework Combine \
    -framework IOKit \
    -O \
    "${PROJECT_DIR}/SiriEdge/Models/EdgeSettings.swift" \
    "${PROJECT_DIR}/SiriEdge/Models/PowerSource.swift" \
    "${PROJECT_DIR}/SiriEdge/Audio/MusicReactiveState.swift" \
    "${PROJECT_DIR}/SiriEdge/Rendering/EdgeAnimation.swift" \
    "${PROJECT_DIR}/SiriEdge/Rendering/EdgeRenderer.swift" \
    "${PROJECT_DIR}/SiriEdge/Views/EdgeOverlayView.swift" \
    "${PROJECT_DIR}/SiriEdge/Views/SettingsView.swift" \
    "${PROJECT_DIR}/SiriEdge/ScreenSaver/ScreenSaverConfigureSheet.swift" \
    "${PROJECT_DIR}/SiriEdge/ScreenSaver/SiriEdgeScreenSaverView.swift"

# Copy Info.plist and Metal shader resources into the bundle
cp "${PROJECT_DIR}/SiriEdge/ScreenSaver/ScreenSaverInfo.plist" "${SAVER_BUNDLE}/Contents/Info.plist"
cp "${PROJECT_DIR}/SiriEdge/Resources/Shaders/EdgeGlow.metal" "${RESOURCES_DIR}/EdgeGlow.metal"

# Set clean rpath install name
install_name_tool -id @rpath/SiriEdgeScreenSaver "${MACOS_DIR}/SiriEdgeScreenSaver"

echo "✅ Successfully generated: ${SAVER_BUNDLE}"
