import Foundation

public struct HTMLContent {
    public static let indexHTML = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no, viewport-fit=cover">
        <meta name="apple-mobile-web-app-capable" content="yes">
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
        <meta name="theme-color" content="#0b0e17">
        <title>Jellyfin Remote</title>
        <style>
            * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; user-select: none; }
            body {
                margin: 0;
                padding: calc(env(safe-area-inset-top) + 6px) 14px calc(env(safe-area-inset-bottom) + 8px) 14px;
                background-color: #0b0e17;
                color: #ffffff;
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", Roboto, sans-serif;
                display: flex;
                flex-direction: column;
                align-items: center;
                min-height: 100vh;
                justify-content: space-between;
            }
            .header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                width: 100%;
                max-width: 360px;
                margin-bottom: 6px;
            }
            h1 { font-size: 1.05rem; margin: 0; color: #a5b4fc; text-transform: uppercase; letter-spacing: 1px; font-weight: 700; }
            
            .header-actions { display: flex; gap: 6px; }
            .btn-action {
                background: rgba(255,255,255,0.08);
                border: 1px solid rgba(255,255,255,0.15);
                color: #fff;
                padding: 6px 10px;
                border-radius: 10px;
                font-size: 0.8rem;
                font-weight: 600;
                cursor: pointer;
            }
            .btn-action:active { background: #4f46e5; }

            .section { width: 100%; max-width: 360px; }
            
            /* Player Info Card */
            .player-card {
                background: #15192b;
                border: 1px solid rgba(255,255,255,0.08);
                border-radius: 14px;
                padding: 8px 12px;
                display: flex;
                flex-direction: column;
                gap: 4px;
                margin-bottom: 8px;
            }
            .player-title { font-size: 0.85rem; font-weight: 600; color: #e2e8f0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
            .player-time { font-size: 0.75rem; color: #94a3b8; display: flex; justify-content: space-between; }
            .progress-bar { width: 100%; height: 4px; background: rgba(255,255,255,0.1); border-radius: 2px; overflow: hidden; }
            .progress-fill { width: 0%; height: 100%; background: #6366f1; transition: width 0.3s ease; }

            /* Playback Controls (Middle Zone) */
            .playback-grid {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                gap: 6px;
            }
            .btn-playback { height: 44px; font-size: 1rem; border-radius: 12px; }
            .btn-play { background: #059669; border-color: #10b981; grid-column: span 3; font-size: 1.15rem; font-weight: 600; height: 46px; }
            .btn-play:active { background: #10b981; }

            /* Search Input Bar */
            .search-box {
                display: flex;
                gap: 6px;
                margin: 6px 0;
            }
            .search-input {
                flex: 1;
                background: #15192b;
                border: 1px solid rgba(255,255,255,0.15);
                border-radius: 10px;
                padding: 8px 12px;
                color: #fff;
                font-size: 0.85rem;
                outline: none;
                user-select: text;
            }
            .search-input:focus { border-color: #6366f1; }
            
            /* Grids */
            .grid-3 {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                gap: 6px;
                margin-top: 4px;
            }
            .btn-small { height: 36px; font-size: 0.8rem; border-radius: 10px; }
            .btn-macro { background: #232842; border-color: #3b82f6; }

            /* D-Pad Styling (Bottom Thumb Zone) */
            .dpad-container {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                grid-template-rows: repeat(3, 1fr);
                gap: 8px;
                width: 230px;
                height: 230px;
                margin: 8px auto 4px auto;
            }
            .btn {
                background: #1c2035;
                border: 1px solid rgba(255,255,255,0.1);
                color: #fff;
                font-size: 1.2rem;
                font-weight: 600;
                border-radius: 18px;
                display: flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                box-shadow: 0 4px 10px rgba(0,0,0,0.3);
            }
            .btn:active { background: #4f46e5; transform: scale(0.93); }
            .btn-ok { background: #3730a3; border-color: #6366f1; border-radius: 50%; font-size: 1.15rem; }

            .status { font-size: 0.75rem; color: #64748b; text-align: center; margin-top: 2px; }
        </style>
    </head>
    <body>
        <!-- Header -->
        <div class="header">
            <h1>🍿 Jellyfin Remote</h1>
            <div class="header-actions">
                <button class="btn-action" onclick="send('reload')">🔄 Reload</button>
                <button class="btn-action" onclick="send('fullscreen')">⛶ Screen</button>
            </div>
        </div>
        
        <!-- Live Playback Status Card -->
        <div class="section">
            <div class="player-card">
                <div class="player-title" id="player-title">Jellyfin Safari</div>
                <div class="progress-bar"><div class="progress-fill" id="progress-fill"></div></div>
                <div class="player-time">
                    <span id="time-current">0:00</span>
                    <span id="time-duration">0:00</span>
                </div>
            </div>

            <!-- Playback Controls -->
            <div class="playback-grid">
                <button class="btn btn-playback btn-play" id="btn-play" onclick="send('play_pause')">⏯ Play / Pause</button>
                <button class="btn btn-playback" onclick="send('seek_backward')">⏮ -10s</button>
                <button class="btn btn-playback" onclick="send('mute')">🔇 Mute</button>
                <button class="btn btn-playback" onclick="send('seek_forward')">+10s ⏭</button>
            </div>
            
            <!-- Quick Search Input -->
            <form class="search-box" onsubmit="submitSearch(event)">
                <input type="text" id="search-text" class="search-input" placeholder="Type to search from phone..." />
                <button type="submit" class="btn btn-small" style="padding: 0 14px;">Find</button>
            </form>

            <!-- Macros & Navigation Shortcuts -->
            <div class="grid-3">
                <button class="btn btn-small btn-macro" onclick="send('home')">🏠 Home</button>
                <button class="btn btn-small btn-macro" onclick="send('movies')">🎬 Movies</button>
                <button class="btn btn-small btn-macro" onclick="send('series')">📺 Shows</button>
            </div>
        </div>

        <!-- D-Pad Navigation in Natural Thumb Zone (Bottom) -->
        <div class="section">
            <div class="dpad-container">
                <div></div>
                <button class="btn" onclick="send('up')">▲</button>
                <div></div>
                <button class="btn" onclick="send('left')">◀</button>
                <button class="btn btn-ok" onclick="send('enter')">OK</button>
                <button class="btn" onclick="send('right')">▶</button>
                <div></div>
                <button class="btn" onclick="send('down')">▼</button>
                <div></div>
            </div>
            
            <div class="grid-3" style="width: 230px; margin: 4px auto 0 auto;">
                <button class="btn btn-small" onclick="send('escape')">◀ Back</button>
                <button class="btn btn-small" onclick="send('focus_safari')">⚡ Safari</button>
                <button class="btn btn-small" onclick="send('search')">🔍 Search</button>
            </div>
        </div>

        <div class="status" id="status">Connected</div>

        <script>
            function send(cmd, extraParams = '') {
                const statusEl = document.getElementById('status');
                if (navigator.vibrate) navigator.vibrate(30);
                
                fetch('/api/command?cmd=' + cmd + extraParams)
                    .then(r => r.json())
                    .then(data => {
                        statusEl.innerText = 'Status: ' + (data.result || 'OK');
                        pollStatus();
                    })
                    .catch(() => {
                        statusEl.innerText = 'Connection error!';
                    });
            }

            function submitSearch(e) {
                e.preventDefault();
                const input = document.getElementById('search-text');
                const text = encodeURIComponent(input.value.trim());
                if (text) {
                    send('type_text', '&text=' + text);
                    input.blur();
                }
            }

            function formatTime(secs) {
                const m = Math.floor(secs / 60);
                const s = Math.floor(secs % 60);
                return m + ':' + (s < 10 ? '0' : '') + s;
            }

            function pollStatus() {
                fetch('/api/status')
                    .then(r => r.json())
                    .then(st => {
                        if (st.hasVideo) {
                            document.getElementById('player-title').innerText = st.title || 'Playing';
                            document.getElementById('time-current').innerText = formatTime(st.currentTime);
                            document.getElementById('time-duration').innerText = formatTime(st.duration);
                            const percent = st.duration > 0 ? (st.currentTime / st.duration) * 100 : 0;
                            document.getElementById('progress-fill').style.width = percent + '%';
                            document.getElementById('btn-play').innerText = st.isPlaying ? '⏸ Pause' : '▶ Play';
                        } else {
                            document.getElementById('player-title').innerText = st.title || 'Jellyfin Safari';
                            document.getElementById('progress-fill').style.width = '0%';
                            document.getElementById('btn-play').innerText = '⏯ Play / Pause';
                        }
                    })
                    .catch(() => {});
            }

            setInterval(pollStatus, 2000);
            pollStatus();
        </script>
    </body>
    </html>
    """
}
