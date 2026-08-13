#!/bin/bash
# ES-DE → 厂商 RA_launch.sh 委托 wrapper(2026-08-13/14 方案 A)
# ES-DE 传参: -L /mnt/vendor/deep/retro/cores/mgba_libretro.so <rom>
# 翻译为:    RA_launch.sh mgba_libretro.so <rom>
# 关键:重建厂商 32 位库环境(RA 是 32 位 armhf;ES-DE 自身的
# LD_LIBRARY_PATH=/mnt/data/mali-lib 全是 64 位库,继承会导致
# "libGLESv2.so.2: wrong ELF class" 秒退)
core_path=""
rom=""
while [ $# -gt 0 ]; do
  case "$1" in
    -L) core_path="$2"; shift 2 ;;
     *) rom="$1"; shift ;;
  esac
done
export LD_LIBRARY_PATH=/usr/lib32:/usr/lib:/mnt/vendor/lib
exec /mnt/mod/ctrl/RA_launch.sh "${core_path##*/}" "$rom"
