#!/bin/bash
# ES-DE for Anbernic H700 (DeepPlayOS) 安装/升级脚本
# 用法:把本仓库放到掌机任意目录,cd 到仓库根目录后运行:
#   sh install.sh          全新安装(不覆盖已有用户配置)
#   sh install.sh upgrade  升级:同步程序/资源/脚本 + 模板配置带 .bak 备份更新
# 前提:原厂 DeepPlayOS(带 muos/dmenu 启动器),SSH root 登录
set -e

MODE="${1:-install}"
if [ "$MODE" != "install" ] && [ "$MODE" != "upgrade" ]; then
    echo "用法: sh install.sh [install|upgrade]"
    exit 1
fi

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APPS_DIR="/mnt/mmc/Roms/APPS"
LIB_DIR="/mnt/data/mali-lib"
HOME_DIR="/mnt/data/es-de-home"
WRAPPER="/mnt/data/retroarch-wrapper.sh"

echo "== ES-DE H700 安装器($MODE 模式)=="

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

# ── 2. mali-lib 软链(运行库锁定,幂等) ─────────────────
echo "[2/5] 准备 $LIB_DIR ..."
mkdir -p "$LIB_DIR"
ln -sf /usr/lib/libmali.so       "$LIB_DIR/libEGL.so"
ln -sf /usr/lib/libmali.so       "$LIB_DIR/libGLESv2.so"
ln -sf /usr/lib/libmali.so       "$LIB_DIR/libGLESv1_CM.so"
ln -sf /usr/lib/libmali.so       "$LIB_DIR/libGLES_CM.so"
ln -sf "$SDL28"                  "$LIB_DIR/libSDL2-2.0.so.0"
echo "  ✓ 软链就绪"

# ── 3. 安装程序与资源(覆盖) ────────────────────────────
echo "[3/5] 同步到 $APPS_DIR ..."
mkdir -p "$APPS_DIR/esde"
cp -rf "$REPO_DIR/esde/resources" "$APPS_DIR/esde/"
cp -f  "$REPO_DIR/esde/es-de"     "$APPS_DIR/esde/es-de"
cp -f  "$REPO_DIR/ES-DE.sh"       "$APPS_DIR/ES-DE.sh"
cp -f  "$REPO_DIR/lid-daemon.sh"  "/mnt/data/lid-daemon.sh"
chmod +x "$APPS_DIR/ES-DE.sh" "$APPS_DIR/esde/es-de" "/mnt/data/lid-daemon.sh"
mkdir -p "$APPS_DIR/Imgs"
cp -f  "$REPO_DIR/ES-DE.png"    "$APPS_DIR/Imgs/ES-DE.png"
echo "  ✓ 程序安装完成"

# ── 4. 用户目录模板 ─────────────────────────────────────
echo "[4/5] 用户目录模板..."
if [ "$MODE" = "upgrade" ]; then
    # 升级模式:
    #   - es_input.xml / 手柄映射 / 事件脚本:发行管理的文件,带 .bak 备份后更新
    #   - es_settings.xml:只注入发行必需键(CustomEventScripts),绝不整体覆盖
    #     (否则会抹掉用户的主题/语言/刮削等设置)
    mkdir -p "$HOME_DIR"
    for f in settings/es_input.xml \
             controllers/es_controller_mappings.cfg \
             scripts/game-start/game-flag.sh scripts/game-end/game-flag.sh; do
        src="$REPO_DIR/home-template/ES-DE/$f"
        dst="$HOME_DIR/ES-DE/$f"
        [ -f "$src" ] || continue
        mkdir -p "$(dirname "$dst")"
        if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
            cp -f "$dst" "$dst.bak"
            echo "  · 备份并更新 $f(旧文件 → $f.bak)"
        fi
        cp -f "$src" "$dst"
    done
    SETTINGS="$HOME_DIR/ES-DE/settings/es_settings.xml"
    if [ -f "$SETTINGS" ] && grep -q 'name="CustomEventScripts" value="false"' "$SETTINGS"; then
        cp -f "$SETTINGS" "$SETTINGS.bak"
        sed -i 's/name="CustomEventScripts" value="false"/name="CustomEventScripts" value="true"/' "$SETTINGS"
        echo "  · es_settings.xml: CustomEventScripts → true(旧文件 → .bak)"
    elif [ -f "$SETTINGS" ] && ! grep -q 'name="CustomEventScripts"' "$SETTINGS"; then
        cp -f "$SETTINGS" "$SETTINGS.bak"
        echo '<bool name="CustomEventScripts" value="true" />' >> "$SETTINGS"
        echo "  · es_settings.xml 注入 CustomEventScripts=true(旧文件 → .bak)"
    fi
    echo "  ✓ 模板配置已同步"
else
    if [ -d "$HOME_DIR/ES-DE" ]; then
        echo "  ! 已存在 $HOME_DIR/ES-DE,保留现有配置(全新安装请先删除;日常升级请用: sh install.sh upgrade)"
    else
        mkdir -p "$HOME_DIR"
        cp -r "$REPO_DIR/home-template/ES-DE" "$HOME_DIR/"
        echo "  ✓ 已创建 $HOME_DIR/ES-DE"
    fi
fi

# ── 5. wrapper ──────────────────────────────────────────
echo "[5/5] 安装 RetroArch wrapper..."
cp -f "$REPO_DIR/retroarch-wrapper.sh" "$WRAPPER"
chmod +x "$WRAPPER"
echo "  ✓ 完成"

echo ""
echo "== 完成 =="
echo "在 dmenu 的 APPS 分类里找到「ES-DE」启动即可。"
echo "提示:"
echo "  · 主题:解压主题文件夹到 $HOME_DIR/ES-DE/themes/"
echo "  · 键位:内置手柄已按 ANBERNIC-keys 配置;START 打开菜单,MENU 键无动作(ES-DE 设计)"
echo "  · 音频:当前静音运行,详见 README「已知限制」"
echo "  · 新增 ROM:拷入对应目录后,下次启动 ES-DE 自动出现(无需任何操作)"
