#!/bin/bash
# ES-DE 启动脚本(APPS 应用形态,GLES/mali 通路)
# 2026-08-13 修订:
#   --home /mnt/data/es-de-home:用户目录放 ext4(/mnt/mmc 是 vfat 同名冲突)
#   HOME=/:让 RetroArch 用厂商配置(/.config/retroarch,video_driver=gl 实测可用)
#   SDL_AUDIODRIVER=dummy:暂静音(试音频时删掉此行)
# 2026-08-14 修订:
#   fontconfig 修复:ES-DE 的 libpangoft2 需要 FcWeightFromOpenTypeDouble(仅
#   1.12.0 有),而厂商 RA_launch.sh 启动 32 位 RetroArch 前会换成 1.10.1
#   → 每次启动 ES-DE 前必须翻回 1.12.0,否则 es-de 秒退(symbol lookup error)
#   SDL_AUDIODRIVER=dummy:静音运行(音频调研结论见 AUDIO_RESEARCH.md:
#   ES-DE 若用 ALSA 会独占声卡导致游戏无声;音量键被厂商 hook 锁死,
#   两害相权,保持 dummy —— 游戏内声音不受影响)
progdir="$(cd "$(dirname "$0")" && pwd)"
(ls -l /lib/aarch64-linux-gnu/libfontconfig.so.1 2>/dev/null | grep -q '1.10.1') && \
  ln -sf /lib/aarch64-linux-gnu/libfontconfig.so.1.12.0 /lib/aarch64-linux-gnu/libfontconfig.so.1
export LD_LIBRARY_PATH=/mnt/data/mali-lib
export SDL_AUDIODRIVER=dummy
export HOME=/

# 待机守护(合盖/电源键 → 挂起,电源键唤醒;游戏中自动让位给厂商守护)
STANDBY_DAEMON="/mnt/data/standby-daemon.py"
if [ -x "$STANDBY_DAEMON" ] && command -v python3 >/dev/null 2>&1; then
    python3 "$STANDBY_DAEMON" &
    STANDBY_PID=$!
    trap 'kill "$STANDBY_PID" 2>/dev/null' EXIT
fi

cd "${progdir}/esde"
"${progdir}/esde/es-de" --home /mnt/data/es-de-home > "${progdir}/esde/log.txt" 2>&1
