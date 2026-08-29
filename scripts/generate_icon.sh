#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET_DIR="${PROJECT_DIR}/AppIcon.iconset"
RESOURCES_DIR="${PROJECT_DIR}/Resources"

mkdir -p "${ICONSET_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "🎨 Генерация нативной иконки приложения JellyfinRemote..."

# Swift-скрипт отрисовки векторной иконки высокого разрешения
cat << 'EOF' > /tmp/generate_icon.swift
import Cocoa

func renderIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: radius, yRadius: radius)
    
    // Фон: глубокий темный индиго-градиент в стиле Jellyfin/macOS
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.24, alpha: 1.0),
        ending: NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.10, alpha: 1.0)
    )
    gradient?.draw(in: path, angle: -45)
    
    // Обводка
    NSColor(calibratedWhite: 1.0, alpha: 0.15).setStroke()
    path.lineWidth = size * 0.015
    path.stroke()
    
    // Эмодзи попкорна 🍿 в центре
    let emoji = "🍿"
    let fontSize = size * 0.55
    let font = NSFont.systemFont(ofSize: fontSize)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let str = NSAttributedString(string: emoji, attributes: attrs)
    let strSize = str.size()
    let textRect = NSRect(
        x: (size - strSize.width) / 2,
        y: (size - strSize.height) / 2 - (size * 0.02),
        width: strSize.width,
        height: strSize.height
    )
    str.draw(in: textRect)
    
    img.unlockFocus()
    return img
}

let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes {
    let img = renderIcon(size: CGFloat(s))
    if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
        if let png = rep.representation(using: .png, properties: [:]) {
            let url = URL(fileURLWithPath: "/tmp/icon_\(s)x\(s).png")
            try? png.write(to: url)
        }
    }
}
EOF

swift /tmp/generate_icon.swift

# Раскладываем по спецификации Apple Iconset
cp /tmp/icon_16x16.png "${ICONSET_DIR}/icon_16x16.png"
cp /tmp/icon_32x32.png "${ICONSET_DIR}/icon_16x16@2x.png"
cp /tmp/icon_32x32.png "${ICONSET_DIR}/icon_32x32.png"
cp /tmp/icon_64x64.png "${ICONSET_DIR}/icon_32x32@2x.png"
cp /tmp/icon_128x128.png "${ICONSET_DIR}/icon_128x128.png"
cp /tmp/icon_256x256.png "${ICONSET_DIR}/icon_128x128@2x.png"
cp /tmp/icon_256x256.png "${ICONSET_DIR}/icon_256x256.png"
cp /tmp/icon_512x512.png "${ICONSET_DIR}/icon_256x256@2x.png"
cp /tmp/icon_512x512.png "${ICONSET_DIR}/icon_512x512.png"
cp /tmp/icon_1024x1024.png "${ICONSET_DIR}/icon_512x512@2x.png"

# Упаковываем iconset в AppIcon.icns
iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"

rm -rf "${ICONSET_DIR}" /tmp/icon_*.png /tmp/generate_icon.swift
echo "✅ Готово: ${RESOURCES_DIR}/AppIcon.icns"
