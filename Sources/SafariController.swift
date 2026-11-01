import Foundation
import CoreGraphics
import AppKit

public class SafariController {

    // MARK: - Контекстное выполнение JavaScript в Safari

    /// Выполняет JS в активной вкладке YouTube (если открыта спереди),
    /// либо в целевой вкладке Jellyfin.
    @discardableResult
    public static func runJS(_ jsCode: String) -> String? {
        let escapedJS = jsCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let scriptSource = """
        tell application "Safari"
            if (count of windows) = 0 then return "no_windows"

            -- 1. Если текущая активная вкладка — это YouTube, выполняем прямо в ней
            try
                set curUrl to (URL of current tab of front window) as string
                if curUrl contains "youtube.com" then
                    return do JavaScript "\(escapedJS)" in current tab of front window
                end if
            end try

            -- 2. Иначе ищем вкладку Jellyfin по URL или портам
            set targetTab to missing value
            repeat with w in windows
                repeat with t in tabs of w
                    set tabUrl to (URL of t) as string
                    if tabUrl contains "jellyfin" or tabUrl contains ":8096" or tabUrl contains ":8088" or tabUrl contains ":8097" then
                        set targetTab to t
                        exit repeat
                    end if
                end repeat
                if targetTab is not missing value then exit repeat
            end repeat

            if targetTab is not missing value then
                return do JavaScript "\(escapedJS)" in targetTab
            else
                -- Резерв: пробуем выполнить в активной вкладке
                try
                    return do JavaScript "\(escapedJS)" in current tab of front window
                on error
                    return "no_matching_tab"
                end try
            end if
        end tell
        """

        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            let output = script.executeAndReturnError(&error)
            if let err = error {
                print("❌ Ошибка AppleScript: \(err)")
                return nil
            }
            let value = output.stringValue
            return (value == "no_windows" || value == "no_matching_tab") ? nil : value
        }
        return nil
    }

    /// Проверяет, активен ли сейчас YouTube на переднем плане
    public static func isYouTubeFrontmost() -> Bool {
        let scriptSource = """
        tell application "Safari"
            if (count of windows) = 0 then return false
            try
                set curUrl to (URL of current tab of front window) as string
                return curUrl contains "youtube.com"
            on error
                return false
            end try
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            let out = script.executeAndReturnError(&error)
            return out.booleanValue
        }
        return false
    }

    /// Выводит Safari и вкладку Jellyfin на передний план
    public static func activateSafari() {
        let scriptSource = """
        tell application "Safari"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    set tabUrl to (URL of t) as string
                    if tabUrl contains "jellyfin" or tabUrl contains ":8096" or tabUrl contains ":8088" or tabUrl contains ":8097" then
                        set current tab of w to t
                        set index of w to 1
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }

    // MARK: - Smart TV Режим & Авто-фокус (Jellyfin)

    public static func ensureFocusAndTVMode() {
        let js = """
        (function(){
            if (localStorage.getItem('displayMode') !== 'tv') {
                localStorage.setItem('displayMode', 'tv');
            }
            const active = document.activeElement;
            if (!active || active === document.body || active === document.documentElement) {
                const target = document.querySelector('.card, .emby-button, [focusable="true"], .itemDetailImage, button, a');
                if (target) target.focus();
            }
        })()
        """
        runJS(js)
    }

    // MARK: - Системные макросы Safari

    @discardableResult
    public static func reloadPage() -> String? {
        return runJS("location.reload(); 'reloaded';")
    }

    // MARK: - Управление Плеером (Playback & Status)

    public static func getPlaybackStatus() -> String {
        let js = """
        (function(){
            const v = document.querySelector('video');
            const titleEl = document.querySelector('.pageTitle, .headerItemTitle, .videoTitle, .itemTitle');
            const title = titleEl ? titleEl.innerText : document.title;

            if (!v) {
                return JSON.stringify({
                    hasVideo: false,
                    title: title || 'Jellyfin / YouTube',
                    isPlaying: false,
                    currentTime: 0,
                    duration: 0,
                    volume: 1,
                    muted: false
                });
            }

            return JSON.stringify({
                hasVideo: true,
                title: title || 'Воспроизведение',
                isPlaying: !v.paused,
                currentTime: Math.round(v.currentTime),
                duration: Math.round(v.duration || 0),
                volume: Math.round(v.volume * 100),
                muted: v.muted
            });
        })()
        """
        return runJS(js) ?? "{\"hasVideo\":false}"
    }

    @discardableResult
    public static func togglePlayPause() -> String? {
        if isYouTubeFrontmost() {
            // Для YouTube TV шлем нативный пробел через System Events
            sendSystemKey(code: KeyCode.space)
            return "toggled"
        }

        let js = """
        (function(){
            const v = document.querySelector('video');
            if (!v) return 'No video';
            if (v.paused) { v.play(); return 'playing'; }
            else { v.pause(); return 'paused'; }
        })()
        """
        return runJS(js)
    }

    @discardableResult
    public static func seek(by seconds: Double) -> String? {
        let js = """
        (function(){
            const v = document.querySelector('video');
            if (!v) return 'No video';
            v.currentTime += \(seconds);
            return 'seeked';
        })()
        """
        return runJS(js)
    }

    @discardableResult
    public static func toggleFullscreen() -> String? {
        let js = """
        (function(){
            const v = document.querySelector('video');
            if (document.fullscreenElement) {
                document.exitFullscreen();
                return 'windowed';
            } else if (v) {
                v.requestFullscreen().catch(() => {});
                return 'fullscreen';
            }
            return 'no video';
        })()
        """
        return runJS(js)
    }

    // MARK: - Громкость (с защитой от сброса рекламой YouTube)

    @discardableResult
    public static func toggleMute() -> String? {
        let js = """
        (function(){
            const v = document.querySelector('video');
            if (!v) return 'No video';
            v.muted = !v.muted;
            return v.muted ? 'muted' : 'unmuted';
        })()
        """
        return runJS(js)
    }

    @discardableResult
    public static func changeVolume(by delta: Double) -> String? {
        // Устанавливаем громкость и вешаем хук сохранения (anti-ad reset)
        let js = """
        (function(){
            const v = document.querySelector('video');
            if (!v) return 'No video';

            let cur = (typeof window.__targetVol === 'number') ? window.__targetVol : v.volume;
            let next = Math.min(1, Math.max(0, cur + (\(delta))));
            window.__targetVol = next;
            v.volume = next;

            // Вешаем хук защиты от сброса рекламой (один раз)
            if (!window.__volHookInstalled) {
                window.__volHookInstalled = true;
                setInterval(function(){
                    const vid = document.querySelector('video');
                    if (vid && typeof window.__targetVol === 'number') {
                        if (Math.abs(vid.volume - window.__targetVol) > 0.04) {
                            vid.volume = window.__targetVol;
                        }
                    }
                }, 800);
            }

            return 'vol: ' + Math.round(next * 100) + '%';
        })()
        """
        return runJS(js)
    }

    // MARK: - Макросы Навигации

    public static func goHome() {
        if isYouTubeFrontmost() {
            sendSystemKey(code: KeyCode.escape)
            return
        }
        runJS("window.location.hash = '#/home.html';")
        ensureFocusAndTVMode()
    }

    public static func goMovies() {
        runJS("window.location.hash = '#/movies.html';")
        ensureFocusAndTVMode()
    }

    public static func goSeries() {
        runJS("window.location.hash = '#/tv.html';")
        ensureFocusAndTVMode()
    }

    public static func focusSearch() {
        let js = """
        (function(){
            window.location.hash = '#/search.html';
            setTimeout(function(){
                const input = document.querySelector('input[type="search"], input.searchInput, input');
                if (input) input.focus();
            }, 200);
        })()
        """
        runJS(js)
        ensureFocusAndTVMode()
    }

    @discardableResult
    public static func typeSearchText(_ text: String) -> String? {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let js = """
        (function(){
            if (!window.location.hash.includes('search.html')) {
                window.location.hash = '#/search.html';
            }
            setTimeout(function(){
                const input = document.querySelector('input[type="search"], input.searchInput, input');
                if (input) {
                    input.value = "\(escaped)";
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                    input.dispatchEvent(new Event('change', { bubbles: true }));
                }
            }, 150);
            return 'typed';
        })()
        """
        return runJS(js)
    }

    // MARK: - D-Pad Навигация

    /// Отправляет системный key code через System Events (идеально для YouTube TV)
    public static func sendSystemKey(code: CGKeyCode) {
        let scriptSource = """
        tell application "Safari" to activate
        tell application "System Events"
            key code \(code)
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }

    public static func sendKey(code: CGKeyCode) {
        // Если открыт YouTube TV — используем нативный System Events key code
        if isYouTubeFrontmost() {
            sendSystemKey(code: code)
            return
        }

        // Для Jellyfin используем проверенную эмуляцию KeyboardEvent
        var jsKey = ""
        var jsKeyCode = 0

        switch code {
        case KeyCode.up: jsKey = "ArrowUp"; jsKeyCode = 38
        case KeyCode.down: jsKey = "ArrowDown"; jsKeyCode = 40
        case KeyCode.left: jsKey = "ArrowLeft"; jsKeyCode = 37
        case KeyCode.right: jsKey = "ArrowRight"; jsKeyCode = 39
        case KeyCode.enter: jsKey = "Enter"; jsKeyCode = 13
        case KeyCode.escape: jsKey = "Escape"; jsKeyCode = 27
        default: break
        }

        if !jsKey.isEmpty {
            let js = """
            (function(){
                const target = document.activeElement || document.body || document;

                if ('\(jsKey)' === 'Enter' && target && typeof target.click === 'function' && target !== document.body) {
                    target.click();
                    return;
                }

                const eDown = new KeyboardEvent('keydown', {
                    key: '\(jsKey)', code: '\(jsKey)', keyCode: \(jsKeyCode), which: \(jsKeyCode),
                    bubbles: true, cancelable: true
                });
                const eUp = new KeyboardEvent('keyup', {
                    key: '\(jsKey)', code: '\(jsKey)', keyCode: \(jsKeyCode), which: \(jsKeyCode),
                    bubbles: true, cancelable: true
                });

                target.dispatchEvent(eDown);
                target.dispatchEvent(eUp);
            })()
            """
            runJS(js)
        }
    }

    public enum KeyCode {
        public static let up: CGKeyCode = 126
        public static let down: CGKeyCode = 125
        public static let left: CGKeyCode = 123
        public static let right: CGKeyCode = 124
        public static let enter: CGKeyCode = 36
        public static let escape: CGKeyCode = 53
        public static let space: CGKeyCode = 49
    }

    // MARK: - Переключение и открытие сервисов (YouTube / Jellyfin)

    public static func openOrSwitchTab(url: String, matchPattern: String) {
        let scriptSource = """
        tell application "Safari"
            activate
            set found to false
            repeat with w in windows
                repeat with t in tabs of w
                    set tabUrl to (URL of t) as string
                    if tabUrl contains "\(matchPattern)" then
                        set current tab of w to t
                        set index of w to 1
                        set found to true
                        exit repeat
                    end if
                end repeat
                if found then exit repeat
            end repeat
            if not found then
                if (count of windows) = 0 then
                    make new document with properties {URL:"\(url)"}
                else
                    tell front window
                        set current tab to (make new tab with properties {URL:"\(url)"})
                    end tell
                end if
            end if
        end tell
        """
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(&error)
        }
    }

    public static func openYouTube() {
        openOrSwitchTab(url: "https://www.youtube.com/tv#/", matchPattern: "youtube.com")
    }

    public static func openJellyfin() {
        openOrSwitchTab(url: "http://192.168.100.7:8096/web/", matchPattern: "8096")
    }
}
