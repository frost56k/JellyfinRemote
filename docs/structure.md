```
# 🗺 Архитектура и Структура проекта JellyfinRemote

## 📁 Дерево проекта (Текущее состояние)

```text
JellyfinRemote/
├── Package.swift               # Манифест сборщика Swift Package Manager (macOS 14+)
├── Sources/
│   ├── main.swift              # Точка входа приложения, инициализация RunLoop
│   ├── WebServer.swift         # Легковесный HTTP/JSON сервер на Network.framework (порт 9999)
│   ├── SafariController.swift  # Мост управления Safari: AppleScript, JS DOM Injection, Key Events
│   └── HTMLContent.swift       # Встроенный мобильный Web UI (PWA/HTML5/CSS3/Vanilla JS)
└── docs/
    ├── structure.md            # Карта файлов, архитектура и потоки данных (этот файл)
    └── progress.md             # Журнал разработки и отчеты по сессиям
```

---

#### 🏗 Архитектурные слои (v2.0)

1. **macOS Menu Bar Layer (AppDelegate, QRCodeWindow, SettingsManager):**
   
   - Управление жизненным циклом приложения без отображения в Dock.
   
   - Наглядный вывод локального адреса и мгновенное сопряжение по QR-коду.
   
   - Динамическая смена порта и автозапуск через SMAppService.

2. **LAN Server Layer (WebServer, NetworkUtils):**
   
   - Обработка HTTP GET/POST запросов без сторонних библиотек.
   
   - Маршруты: /, /api/status, /api/command.

3. **Automation Engine (SafariController):**
   
   - Автоматический поиск нужной вкладки Jellyfin по URL (:8096, :8088 и т.д.).
   
   - Диспетчер одиночных событий DOM KeyboardEvent.
   
   - Двусторонний опрос статуса плеера (таймлайн, play/pause, заголовок).
   
   - Прямой ввод текста с клавиатуры телефона в поле поиска.

4. **Client Web UI (HTMLContent):**
   
   - Адаптивный мобильный пульт с тактильной отдачей (vibrate).
   
   - Карточка статуса плеера, D-Pad, кнопки разделов, быстрый поиск. 

---

## 🧩 Описание компонентов

| Файл                   | Ответственность                                                                                                                                                                    | Зависимости                      |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| main.swift             | Старт демона/приложения, проверка версии ОС, запуск WebServer.                                                                                                                     | Foundation                       |
| WebServer.swift        | Прием входящих соединений по TCP, маршрутизация эндпоинтов / и /api/command, получение локального IP (ifaddrs).                                                                    | Network, Foundation              |
| SafariController.swift | Генерация и выполнение AppleScript, трансляция D-Pad клавиш в JS KeyboardEvent, управление плеером (<video>), навигация по хэш-роутам (#/home.html, #/movies.html, #/search.html). | AppKit, CoreGraphics, Foundation |
| HTMLContent.swift      | Single Page Application для iOS: адаптивный D-Pad, кнопки плеера, макросы разделов, тактильный отклик (navigator.vibrate), отправка асинхронных fetch-запросов.                    | HTML5, CSS Grid, JS Fetch        |

---

## 🔒 Требования к безопасности и разрешениям macOS

- **macOS TCC Automation:** Разрешение управления Safari через Apple Events.

- **Safari Developer Menu:** Включенный пункт Разработка -> Разрешить события JavaScript Apple.

- **Сетевой стек:** Локальный порт TCP 9999 (доступен только внутри домашней LAN).
