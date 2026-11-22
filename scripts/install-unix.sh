#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${HOME}/.local/share/streaming-lan-cast-remote"
VENV_DIR="${INSTALL_DIR}/venv"
EXT_DIR="${INSTALL_DIR}/extension"
HELPER_DST="${INSTALL_DIR}/streaming-lan-cast-helper.py"
TOKEN_FILE="${HOME}/.streaming-lan-cast/token"

echo "==> Installing Streaming LAN Cast (TV Remote) to ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

# Stop running helper cleanly if active
if [[ -f "${TOKEN_FILE}" ]]; then
  TOK="$(tr -d '[:space:]' < "${TOKEN_FILE}")"
  if [[ -n "${TOK}" ]]; then
    curl -fsS -m 3 -X POST -H "X-LanCast-Token: ${TOK}" http://127.0.0.1:9988/quit >/dev/null 2>&1 || true
    sleep 1
  fi
fi

cp -f "${REPO_ROOT}/helper/streaming-lan-cast-helper.py" "${HELPER_DST}"
rm -rf "${EXT_DIR}"
cp -r "${REPO_ROOT}/extension" "${EXT_DIR}"

if command -v uv >/dev/null 2>&1; then
  echo "==> Setting up Python venv with uv..."
  uv venv --allow-existing "${VENV_DIR}"
  uv pip install --python "${VENV_DIR}/bin/python" -r "${REPO_ROOT}/requirements.txt"
else
  echo "==> Setting up Python venv with python3..."
  python3 -m venv "${VENV_DIR}"
  "${VENV_DIR}/bin/pip" install --upgrade -r "${REPO_ROOT}/requirements.txt"
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "WARNING: ffmpeg not found on PATH. Install ffmpeg (e.g. 'sudo apt install ffmpeg', 'sudo pacman -S ffmpeg', or 'brew install ffmpeg') for fMP4/VOD DLNA seeking." >&2
fi

OS="$(uname -s)"
if [[ "${OS}" == "Linux" ]] && command -v systemctl >/dev/null 2>&1; then
  UNIT_DIR="${HOME}/.config/systemd/user"
  mkdir -p "${UNIT_DIR}"
  cat > "${UNIT_DIR}/streaming-lan-cast-remote.service" <<EOF
[Unit]
Description=Streaming LAN Cast (TV Remote) Local Helper
After=network-online.target

[Service]
ExecStart=${VENV_DIR}/bin/python ${HELPER_DST} --serve
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now streaming-lan-cast-remote.service
elif [[ "${OS}" == "Darwin" ]]; then
  PLIST="${HOME}/Library/LaunchAgents/com.streaming-lan-cast.remote.plist"
  mkdir -p "${HOME}/Library/LaunchAgents"
  cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.streaming-lan-cast.remote</string>
  <key>ProgramArguments</key><array>
    <string>${VENV_DIR}/bin/python</string>
    <string>${HELPER_DST}</string>
    <string>--serve</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
EOF
  launchctl unload "${PLIST}" >/dev/null 2>&1 || true
  launchctl load -w "${PLIST}"
else
  nohup "${VENV_DIR}/bin/python" "${HELPER_DST}" --serve >/dev/null 2>&1 &
fi

for _ in $(seq 1 25); do
  [[ -s "${TOKEN_FILE}" ]] && break
  sleep 0.3
done

echo ""
echo "Installation complete!"
echo "  Helper URL : http://127.0.0.1:9988"
if [[ -s "${TOKEN_FILE}" ]]; then
  echo "  Token      : $(tr -d '[:space:]' < "${TOKEN_FILE}")"
fi
echo ""
echo "Next steps in Chrome / Edge / Brave:"
echo "  1. Open chrome://extensions and enable 'Developer mode'."
echo "  2. Click 'Load unpacked' and select: ${EXT_DIR}"
echo "  3. Click the extension -> Open options -> paste your Token -> Save."
