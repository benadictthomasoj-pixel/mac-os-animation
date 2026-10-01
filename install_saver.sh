#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAVER_NAME="SiriEdge"
TARGET_DIR="${HOME}/Library/Screen Savers"
DESTINATION="${TARGET_DIR}/${SAVER_NAME}.saver"

echo "=============================================="
echo "✨ SiriEdge macOS Screen Saver Installer"
echo "=============================================="

# 1. Build the .saver bundle
"${PROJECT_DIR}/build_saver.sh"

# 2. Ensure target directory exists
mkdir -p "${TARGET_DIR}"

# 3. Clean up any existing version in ~/Library/Screen Savers/
if [ -d "${DESTINATION}" ]; then
    echo "🧹 Removing previous installation at: ${DESTINATION}"
    rm -rf "${DESTINATION}"
fi

# 4. Copy the freshly generated .saver bundle
echo "📦 Installing SiriEdge.saver to: ${DESTINATION}"
cp -R "${PROJECT_DIR}/${SAVER_NAME}.saver" "${DESTINATION}"

# 5. Verify the bundle installation
if [ -d "${DESTINATION}" ] && [ -f "${DESTINATION}/Contents/MacOS/SiriEdgeScreenSaver" ] && [ -f "${DESTINATION}/Contents/Info.plist" ]; then
    echo "=============================================="
    echo "🎉 SUCCESS: SiriEdge.saver installed successfully!"
    echo "📍 Location: ${DESTINATION}"
    echo "🖥️  You can now select and configure SiriEdge in macOS System Settings -> Screen Saver!"
    echo "=============================================="
else
    echo "❌ ERROR: Installation verification failed."
    exit 1
fi
