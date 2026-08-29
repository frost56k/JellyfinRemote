#!/bin/bash
set -e

echo "🚀 [1/4] Сборка релизного бинарника JellyfinRemote..."

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="JellyfinRemote"
BUILD_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
RESOURCES_DIR="${PROJECT_DIR}/Resources"

cd "${PROJECT_DIR}"

# 1. Генерация AppIcon.icns, если его еще нет
if [ ! -f "${RESOURCES_DIR}/AppIcon.icns" ]; then
    bash "${PROJECT_DIR}/scripts/generate_icon.sh"
fi

# 2. Компиляция в Universal Binary (Intel + Apple Silicon)
if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
    echo "✅ Universal бинарник успешно собран (arm64 + x86_64)"
    BIN_PATH="${PROJECT_DIR}/.build/apple/Products/Release/${APP_NAME}"
else
    echo "⚠️ Сборка под архитектуру текущего хоста..."
    swift build -c release
    BIN_PATH=$(swift build -c release --show-bin-path)/${APP_NAME}
fi

echo "📦 [2/4] Формирование структуры .app бандла..."

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Копирование бинарника и иконки
cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${RESOURCES_DIR}/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# 3. Создание Info.plist с указанием AppIcon
cat <<EOF > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ru</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.jellyfinremote.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>JellyfinRemote требуется доступ к Safari для управления воспроизведением и навигацией.</string>
</dict>
</plist>
EOF

echo "✍️ [3/4] Локальная подпись приложения (Ad-hoc codesign)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "🎉 [4/4] Сборка завершена! Бандл готов: ${APP_BUNDLE}"
