# Streaming LAN Cast — TV Remote Edition

A modified, self-contained edition of [Streaming LAN Cast](https://github.com/fabriziosantidev/streaming-lan-cast) (based on `v0.5.17`) tailored for **DLNA Smart TVs** (tested on Samsung Tizen UHD TVs) with full remote playback controls, VOD seeking, disguised-extension HLS support, and binge-watching episode controls right inside Chrome / Edge / Brave.

> **Required Notice:** Copyright 2026 Fabrizio Santi (https://github.com/fabriziosantidev/streaming-lan-cast)
> Licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE) (noncommercial & personal use only).

---

## What's Added Over Upstream (`v0.5.17`)

### 1. Better DLNA Stream Compatibility & VOD Seeking
- **Disguised-extension & fMP4 HLS fix for DLNA:** Many web players disguise HLS playlists and fMP4 segments as `.jpg`, `.png`, or `.jpeg`. The helper pulls sniffed HLS VODs and non-`.m3u8` HLS streams through `ffmpeg` (`-f hls -allowed_extensions ALL -extension_picky 0 -c copy -f mpegts`) with queue backpressure so they play smoothly on DLNA TVs with zero re-encoding.
- **True DLNA VOD playback (Pause & Seek enabled):** Computes exact playlist duration and sends `object.item.videoItem.movie` DIDL-Lite metadata with `DLNA.ORG_OP=10` (time-based seeking) and connection-stalling flags (`01700000...`), handles `TimeSeekRange.dlna.org` seek requests via `ffmpeg -ss` + `-output_ts_offset`, and keeps the session alive while `PAUSED_PLAYBACK`.
- **Automatic timestamp pickup:** Casting a video already partway through in Chrome automatically sends a UPnP `Seek` to jump the TV to your current browser timestamp (or start at any explicit timestamp you type).

### 2. Full TV Remote in the Browser Extension
- **Live timeline scrub bar** (`MM:SS / MM:SS` from UPnP `GetPositionInfo`) — drag and release to jump in one hop.
- **Play / Pause** and **Stop** directly from the popup.
- **Quick skip buttons:** `-30s`, `-10s`, `+10s`, `+30s`, and **`+1:30`** *(Skip Intro)*.
- **Exact timestamp box:** Type `12:45` or `1:05:20` **before casting** (*Start at*) or **while casting** (*Go*), plus **`↻ Tab`** to sync the TV to your browser player's current time.
- **TV Volume slider & Mute toggle** (`🔊` / `🔇`) via UPnP `RenderingControl1`.
- **Keyboard shortcuts** when the popup is open: `Space` (Play/Pause), `←` / `→` (±10s), `M` (Mute).

### 3. Episode Navigation & Auto-Play Next
- **`⏮ Prev Ep` / `Next Ep ⏭` buttons:** Advances or rewinds episodes using URL pattern matching (e.g. `/watch/tv/<id>/<season>/<ep>`, `s04e16`, `episode-16`, `?ep=16`) or in-page Next/Prev button detection, waits for the new stream to be sniffed automatically, and casts the next episode starting from `0:00`.
- **Auto-play next episode toggle:** Watches for natural end-of-episode playback in the background service worker (works even when the popup is closed) and automatically loads and casts the next episode. Manual **Stop** never triggers auto-next.

---

## Project Layout

```text
streaming-lan-cast-remote/
├── helper/
│   └── streaming-lan-cast-helper.py   # Patched local helper (127.0.0.1:9988 + DLNA proxy)
├── extension/                         # Unpacked Chrome / Edge / Brave MV3 extension
├── scripts/
│   ├── install-windows.ps1            # One-command Windows installer
│   ├── uninstall-windows.ps1          # Clean Windows uninstaller
│   └── install-unix.sh                # One-command Linux / macOS installer
├── requirements.txt                   # streamlink, pychromecast, curl_cffi
└── LICENSE                            # PolyForm Noncommercial License 1.0.0
```

---

## Quick Start

### Prerequisites
- **Chrome, Edge, or Brave** (102+)
- **Python 3.10+** or **[uv](https://docs.astral.sh/uv/)**
- **FFmpeg** *(auto-installed via `winget` on Windows if missing; on Linux `apt`/`pacman install ffmpeg`; on macOS `brew install ffmpeg`)*
- Laptop and Smart TV on the **same local network** *(on Windows, set your Wi-Fi network profile to **Private**)*

### 1. Install the Local Helper

**Windows (PowerShell):**
```powershell
git clone https://github.com/AbdelhamidQ/streaming-lan-cast-remote.git
cd streaming-lan-cast-remote
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

**Linux / macOS:**
```bash
git clone https://github.com/AbdelhamidQ/streaming-lan-cast-remote.git
cd streaming-lan-cast-remote
chmod +x scripts/install-unix.sh
./scripts/install-unix.sh
```

The installer sets up an isolated virtual environment, registers auto-start on login, starts the helper on `http://127.0.0.1:9988`, and prints your **32-character pairing token**.

### 2. Load the Custom Chrome Extension
1. Open `chrome://extensions` and turn **Developer mode** ON (top-right).
2. Click **Load unpacked** and select the installed `custom-extension` folder printed by the installer (or the `extension/` folder directly from this repo).
3. Pin **Streaming LAN Cast (TV Remote)** to your toolbar → click it → **Open options** → paste your 32-character token → **Save**.
4. Open a video in Chrome, pick your TV, and click **Cast this tab**.
   - Allow **Windows Firewall** if prompted on the first cast (for Private networks).
   - Click **Allow** on your Samsung TV remote if prompted on the first connection.

---

## Privacy & Security
- Everything runs locally on your machine and LAN—zero analytics, zero cloud accounts, zero telemetry.
- The control API binds exclusively to `127.0.0.1:9988` with a random per-install `X-LanCast-Token`, loopback `Host` validation, and extension-only CORS.
- The DLNA stream server only opens while casting and refuses requests from any IP other than the target TV and `127.0.0.1`.

## License & Credits
- Upstream project: **[fabriziosantidev/streaming-lan-cast](https://github.com/fabriziosantidev/streaming-lan-cast)** by Fabrizio Santi.
- License: **[PolyForm Noncommercial License 1.0.0](LICENSE)**.
