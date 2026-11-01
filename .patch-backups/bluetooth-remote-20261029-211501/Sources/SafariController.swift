import Foundation
import CoreGraphics
import AppKit

public class SafariController {
    
    // MARK: - Выполнение JavaScript в целевой вкладке Jellyfin
    
    /// Находит вкладку Jellyfin и выполняет в ней JavaScript.
    /// Если вкладка не найдена, пробует выполнить в активной вкладке Safari (document 1).
    @discardableResult
    public static func runJS(_ jsCode: String) -> String? {
        let escapedJS = jsCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let scriptSource = """
        tell application "Safari"
            if (count of windows) = 0 then return "no_windows"
            
            set targetTab to missing value
            set targetWin to missing value
            
            -- Поиск вкладки Jellyfin по URL или порту
            repeat with w in windows
                repeat with t in tabs of w
                    set tabUrl to (URL of t) as string
                    if tabUrl contains "jellyfin" or tabUrl contains ":8096" or tabUrl contains ":8088" or tabUrl contains ":8097" then
                        set targetTab to t
                        set targetWin to w
                        exit repeat
                    end if
                end repeat
                if targetTab is not missing value then exit repeat
            end repeat
            
            -- Выполняем скрипт в найденной вкладке либо в активном документе
            if targetTab is not missing value then
                return do JavaScript "\(escapedJS)" in targetTab
            else
                return do JavaScript "\(escapedJS)" in document 1
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
            return output.stringValue
        }
        return nil
    }
    
    /// Выводит Safari и вкладку Jellyfin на передний план
    public static func activateSafari() {
        let scriptSource = """
        tell application "Safari"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    set tabUrl to (URL of t) as string
                    if tabUrl contains "jellyfin" or tabUrl contains ":8096" or tabUrl contains ":8088" then
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
    
    // MARK: - Smart TV Режим & Авто-фокус
    
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
    
    /// Получение статуса плеера в формате JSON
    public static func getPlaybackStatus() -> String {
        let js = """
        (function(){
            const v = document.querySelector('video');
            const titleEl = document.querySelector('.pageTitle, .headerItemTitle, .videoTitle, .itemTitle');
            const title = titleEl ? titleEl.innerText : document.title;
            
            if (!v) {
                return JSON.stringify({
                    hasVideo: false,
                    title: title || 'Jellyfin',
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
    
    // MARK: - Громкость
    
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
        let js = """
        (function(){
            const v = document.querySelector('video');
            if (!v) return 'No video';
            v.volume = Math.min(1, Math.max(0, v.volume + (\(delta))));
            return 'vol: ' + Math.round(v.volume * 100) + '%';
        })()
        """
        return runJS(js)
    }
    
    // MARK: - Макросы Навигации
    
    public static func goHome() {
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
    
    /// Ввод произвольного поискового текста с клавиатуры телефона
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
    
    public static func sendKey(code: CGKeyCode) {
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
}
