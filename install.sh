#!/bin/bash
# ES-DE for Anbernic H700 (DeepPlayOS) 安装脚本
# 用法:把本仓库放到掌机任意目录,cd 到仓库根目录后运行: sh install.sh
# 前提:原厂 DeepPlayOS(带 muos/dmenu 启动器),SSH root 登录
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APPS_DIR="/mnt/mmc/Roms/APPS"
LIB_DIR="/mnt/data/mali-lib"
HOME_DIR="/mnt/data/es-de-home"
WRAPPER="/mnt/data/retroarch-wrapper.sh"

echo "== ES-DE H700 安装器 =="

# ── 1. 前置检查 ─────────────────────────────────────────
echo "[1/5] 检查厂商依赖..."
fail=0
[ -x /mnt/vendor/deep/retro/retroarch ] || { echo "  ✗ 找不到 32 位 RetroArch(/mnt/vendor/deep/retro/retroarch)"; fail=1; }
[ -f /mnt/mod/ctrl/RA_launch.sh ] || { echo "  ✗ 找不到 RA_launch.sh(需要 muOS 版启动器的系统)"; fail=1; }
[ -f /usr/lib/libmali.so ] || { echo "  ✗ 找不到 libmali"; fail=1; }
[ -f /mnt/vendor/ctrl/dmenu_ln ] || { echo "  ✗ 找不到 dmenu_ln(不是原厂 DeepPlayOS?)"; fail=1; }
SDL28="$(ls /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.28* 2>/dev/null | head -1)"
[ -n "$SDL28" ] || { echo "  ✗ 找不到 SDL2 2.28.x(需要厂商 BSP 自带带 mali 驱动的版本)"; fail=1; }
[ "$fail" -eq 1 ] && { echo "依赖检查失败,终止安装"; exit 1; }
echo "  ✓ 依赖齐全(SDL: $(basename $SDL28))"

# ── 2. mali-lib 软链(运行库锁定) ───────────────────────
echo "[2/5] 创建 $LIB_DIR ..."
mkdir -p "$LIB_DIR"
ln -sf /usr/lib/libmali.so       "$LIB_DIR/libEGL.so"
ln -sf /usr/lib/libmali.so       "$LIB_DIR/libGLESv2.so"
ln -sf /usr/lib/libmali.so       "$LIB_DIR/libGLESv1_CM.so"
ln -sf /usr/lib/libmali.so       "$LIB_DIR/libGLES_CM.so"
ln -sf "$SDL28"                  "$LIB_DIR/libSDL2-2.0.so.0"
echo "  ✓ 软链就绪"

# ── 3. 安装程序与资源 ───────────────────────────────────
echo "[3/5] 安装到 $APPS_DIR ..."
mkdir -p "$APPS_DIR/esde"
cp -rf "$REPO_DIR/esde/resources" "$APPS_DIR/esde/"
cp -f  "$REPO_DIR/esde/es-de"     "$APPS_DIR/esde/es-de"
cp -f  "$REPO_DIR/ES-DE.sh"       "$APPS_DIR/ES-DE.sh"
chmod +x "$APPS_DIR/ES-DE.sh" "$APPS_DIR/esde/es-de"
echo "  ✓ 程序安装完成"

# ── 4. 用户目录模板(不覆盖已有配置) ─────────────────────
echo "[4/5] 用户目录模板..."
if [ -d "$HOME_DIR/ES-DE" ]; then
    echo "  ! 已存在 $HOME_DIR/ES-DE,保留现有配置(如需全新安装请手动删除后重跑)"
else
    mkdir -p "$HOME_DIR"
    cp -r "$REPO_DIR/home-template/ES-DE" "$HOME_DIR/"
    echo "  ✓ 已创建 $HOME_DIR/ES-DE"
fi

# ── 5. wrapper ──────────────────────────────────────────
echo "[5/5] 安装 RetroArch wrapper..."
cp -f "$REPO_DIR/retroarch-wrapper.sh" "$WRAPPER"
chmod +x "$WRAPPER"
echo "  ✓ 完成"

echo ""
echo "== 安装完成 =="
echo "在 dmenu 的 APPS 分类里找到「ES-DE」启动即可。"
echo "首次使用提示:"
echo "  · 主题:解压主题文件夹到 $HOME_DIR/ES-DE/themes/"
echo "  · 键位:内置手柄已按 ANBERNIC-keys 配置;START 打开菜单,MENU 键无动作(ES-DE 设计)"
echo "  · 音频:当前静音运行,详见 README「已知限制」"
