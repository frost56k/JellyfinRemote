#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="JellyfinRemote"
VERSION="2.0.0"
DIST_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_FINAL_PATH="${DIST_DIR}/${DMG_NAME}"
STAGING_DIR="${DIST_DIR}/dmg_staging"

# 1. Проверяем наличие .app или собираем его
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "⚙️ .app бандл не найден. Запускаем сборку..."
    bash "${PROJECT_DIR}/scripts/build_app.sh"
fi

echo "💽 [1/3] Подготовка содержимого DMG инсталлятора..."
rm -rf "${STAGING_DIR}" "${DMG_FINAL_PATH}"
mkdir -p "${STAGING_DIR}"

# Копируем .app в staging
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

# Создаем символическую ссылку на /Applications для Drag-and-Drop установки
ln -s /Applications "${STAGING_DIR}/Applications"

echo "🔨 [2/3] Создание сжатого DMG образа через hdiutil..."

hdiutil create \
    -volname "${APP_NAME} Installer" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_FINAL_PATH}"

# Очистка временной папки
rm -rf "${STAGING_DIR}"

echo "✨ [3/3] Инсталлятор готов!"
echo "📍 Файл: ${DMG_FINAL_PATH}"
echo "📏 Размер: $(du -sh "${DMG_FINAL_PATH}" | awk '{print $1}')"
