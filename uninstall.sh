#!/bin/bash
# ES-DE for Anbernic H700 卸载脚本
# 用法: sh uninstall.sh          移除程序文件,保留用户数据(es-de-home)
#       sh uninstall.sh --purge  连同用户数据一起删除
# 注意:游戏存档在 RetroArch 自己的配置目录(/.config/retroarch/saves|states),
#       不在 es-de-home 里,卸载不影响游戏进度
# 路径配置与 install.sh 一致(读 install.conf,缺省标准布局)
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF="$REPO_DIR/install.conf"
[ -f "$CONF" ] && . "$CONF"
APPS_DIR="${APPS_DIR:-/mnt/mmc/Roms/APPS}"
DATA_DIR="${DATA_DIR:-/mnt/data}"
HOME_DIR="$DATA_DIR/es-de-home"

echo "== ES-DE H700 卸载器 =="
echo "路径: APPS=$APPS_DIR DATA=$DATA_DIR"

# ── 程序文件 ─────────────────────────────────────────────
rm -f  "$APPS_DIR/ES-DE.sh"
rm -rf "$APPS_DIR/esde"
rm -f  "$APPS_DIR/Imgs/ES-DE.png"
rm -rf "$DATA_DIR/mali-lib"
rm -f  "$DATA_DIR/retroarch-wrapper.sh"
rm -f  "$DATA_DIR/standby-daemon.py"
rm -f  "$DATA_DIR/lid-daemon.sh"      # 旧版残留清理
rm -f  /tmp/esde_game_running         # 事件脚本标志
echo "  ✓ 程序文件已移除"

# ── 用户数据(默认保留) ───────────────────────────────────
if [ "$1" = "--purge" ]; then
    rm -rf "$HOME_DIR"
    echo "  ✓ 用户数据已删除($HOME_DIR)"
else
    echo "  ! 保留用户数据: $HOME_DIR"
    echo "    (主题/设置/刮削媒体;游戏存档在 RetroArch 配置目录,不受影响)"
    echo "    如需一并删除: sh uninstall.sh --purge"
fi

echo "== 完成 =="
