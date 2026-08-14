#!/bin/bash
# ES-DE lid 守护(超级待机,2026-08-14)
#
# 合盖 → 内核挂起(echo mem > /sys/power/state);电源键唤醒(PMIC 硬件,无需用户态)
# 依据:厂商超级待机实测 = 标准内核 mem 挂起(见 OFFICIAL_LAUNCHER.md 3.3 与
# /tmp/vendor_sleep_trace.log 的 "PM: Preparing system for sleep (mem)" 铁证)
#
# 设计:
#   - 每 1s 轮询 hallkey(1=开盖,0=合盖),连续 2 次读到 0 才触发(去抖)
#   - 游戏中跳过:/tmp/esde_game_running 标志由 ES-DE 事件脚本
#     (scripts/game-start|game-end)维护;游戏场景由厂商守护原生接管,防双重挂起
#   - 唤醒后需先观察到开盖(hallkey=1)才重新武装,避免"闭盖时按电源键"
#     唤醒后立即二次挂起
#
# 由 ES-DE.sh 启动/退出时杀掉。

HALL="/sys/class/power_supply/axp2202-battery/hallkey"
GAME_FLAG="/tmp/esde_game_running"
LOG="/tmp/lid_daemon.log"

armed=1
prev=1
while true; do
    hall="$(cat "$HALL" 2>/dev/null)"
    if [ -z "$hall" ]; then
        sleep 1
        continue
    fi

    # 开盖 → 重新武装
    [ "$hall" = "1" ] && armed=1

    # 合盖(连续 2 次确认)且不在游戏中 → 挂起
    if [ "$hall" = "0" ] && [ "$armed" = "1" ] && [ "$prev" = "0" ] &&
       [ ! -f "$GAME_FLAG" ]; then
        echo "$(date +%H:%M:%S) lid close → suspend" >> "$LOG"
        echo mem > /sys/power/state
        echo "$(date +%H:%M:%S) resumed (wake by power key)" >> "$LOG"
        armed=0
        prev=1
        sleep 2
        continue
    fi

    prev="$hall"
    sleep 1
done
