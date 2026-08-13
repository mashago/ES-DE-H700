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
progdir="$(cd "$(dirname "$0")" && pwd)"
(ls -l /lib/aarch64-linux-gnu/libfontconfig.so.1 2>/dev/null | grep -q '1.10.1') && \
  ln -sf /lib/aarch64-linux-gnu/libfontconfig.so.1.12.0 /lib/aarch64-linux-gnu/libfontconfig.so.1
export LD_LIBRARY_PATH=/mnt/data/mali-lib
export SDL_AUDIODRIVER=dummy
export HOME=/
cd "${progdir}/esde"
"${progdir}/esde/es-de" --home /mnt/data/es-de-home > "${progdir}/esde/log.txt" 2>&1
