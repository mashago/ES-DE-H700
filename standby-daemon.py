#!/usr/bin/env python3
# standby-daemon.py — ES-DE 待机守护(2026-08-14)
#
# 触发源(二者任一):
#   1. 合盖:轮询 hallkey(1=开盖,0=合盖),连续 2 次读到 0 才触发(去抖)
#   2. 电源键:/dev/input/event0 的 KEY_POWER(116)按下事件
# 动作:内核挂起(echo mem > /sys/power/state)
# 唤醒:电源键(PMIC 硬件,无需用户态支持)
#
# 防误触设计:
#   - 游戏中跳过:/tmp/esde_game_running 标志由 ES-DE 事件脚本维护,
#     游戏场景(合盖/电源键)由厂商/模拟器原生处理,防双重挂起
#   - 合盖:唤醒后需先观察到开盖(hallkey=1)才重新武装
#   - 电源键:唤醒后 5 秒冷却 + 清空事件队列(唤醒那次按键的
#     press/release 会残留在队列,否则唤醒瞬间会再次挂起)
#
# 由 ES-DE.sh 启动/退出时杀掉。日志:/tmp/standby_daemon.log

import os
import select
import struct
import time

HALL = "/sys/class/power_supply/axp2202-battery/hallkey"
GAME_FLAG = "/tmp/esde_game_running"
LOG = "/tmp/standby_daemon.log"
EVENT0 = "/dev/input/event0"

# struct input_event(64 位): tv_sec, tv_usec, type, code, value = 24 字节
EVENT_SIZE = struct.calcsize("llHHi")
EV_KEY = 1
KEY_POWER = 116


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


def suspend(reason):
    log(reason + " → suspend")
    with open("/sys/power/state", "w") as f:
        f.write("mem")
    log("resumed (wake by power key)")


def drain_events(fd):
    try:
        while os.read(fd, EVENT_SIZE * 16):
            pass
    except (BlockingIOError, OSError):
        pass


def read_hall():
    try:
        with open(HALL) as f:
            return f.read().strip()
    except OSError:
        return None


def main():
    fd = None
    try:
        fd = os.open(EVENT0, os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        log("cannot open " + EVENT0 + ", lid-only mode")

    prev_hall = "1"
    armed = True
    power_grace_until = 0.0

    while True:
        power_press = False
        if fd is not None:
            try:
                r, _, _ = select.select([fd], [], [], 0.5)
                if r:
                    now = time.time()
                    if now < power_grace_until:
                        # 唤醒后冷却期:丢弃队列残留(含唤醒按键本身)
                        drain_events(fd)
                    else:
                        buf = os.read(fd, EVENT_SIZE * 16)
                        for i in range(0, len(buf) - EVENT_SIZE + 1, EVENT_SIZE):
                            (_, _, etype, code, value) = struct.unpack(
                                "llHHi", buf[i:i + EVENT_SIZE])
                            if etype == EV_KEY and code == KEY_POWER and value == 1:
                                power_press = True
            except (BlockingIOError, OSError):
                pass
        else:
            time.sleep(0.5)

        hall = read_hall()
        if hall is None:
            hall = prev_hall  # 读取失败保持上次状态,不误触发

        if hall == "1":
            armed = True

        lid_close = (hall == "0" and prev_hall == "0" and armed)
        game_running = os.path.exists(GAME_FLAG)

        if not game_running and (power_press or lid_close):
            reason = "power key" if power_press else "lid close"
            suspend(reason)
            # 唤醒后重新武装/冷却
            power_grace_until = time.time() + 5.0
            if fd is not None:
                drain_events(fd)
            armed = False
            prev_hall = "1"
            continue

        prev_hall = hall


if __name__ == "__main__":
    main()
