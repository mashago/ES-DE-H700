# 官方启动器(muos1.bin)调研手册

> 设备:Anbernic RG34XXSP(H700 / DeepPlayOS,Ubuntu 22.04 aarch64)
> 调研日期:2026-08-13
> 目的:记录官方启动器的位置、启动方式、内置功能、外部脚本调用,为 ES-DE 集成(替换/共存)提供依据。
> 调研方法:读取启动链脚本 + `strings` 提取二进制内嵌文本 + 内核日志/sysfs 实测。

---

## 一、位置与启动方式

### 1.1 启动链(实测)

```
/etc/init.d/launcher.sh (start)
  ├─ brightCtrl.bin &   ← 背光控制守护(后台)
  ├─ cexpert &          ← 电源专家守护(后台;负责 SD 卡热插拔调 mmc_new.sh)
  └─ /mnt/vendor/ctrl/loadapp.sh (后台子 shell)
       └─ while 循环: $RunBin=/mnt/vendor/ctrl/dmenu_ln
            ├─ /tmp/stopAPP.ini 存在 → break(手动测试钩子)
            ├─ /mnt/data/xudebug.ini 存在 → sleep 挡住
            └─ 执行 dmenu_ln
```

### 1.2 dmenu_ln 的选择逻辑(实测脚本全文要点)

```bash
export LD_LIBRARY_PATH=/usr/lib32:/usr/lib:/mnt/vendor/lib   # 32 位库优先
CMD="/mnt/vendor/bin/dmenu.bin"
MISCBIN="/mnt/mmc/dmenu.bin"
if [ -f "/mnt/vendor/muos1.ini" ]; then MISCBIN="/mnt/vendor/bin/muos1.bin"; fi
elif [ -f "/mnt/vendor/muos2.ini" ]; then MISCBIN="/mnt/vendor/bin/muos2.bin"; fi
# 运行 $CMD,若返回成功且 /tmp/.next 存在 → sh /tmp/.next(应用调度)
# /mnt/data/debug.ini 或 /mnt/sdcard/debug.ini 存在 → 输出到 /dev/console 调试模式
```

**当前状态**:`/mnt/vendor/muos1.ini` 存在(2026-08-11)→ **当前启动器 = /mnt/vendor/bin/muos1.bin**。

### 1.3 启动器二进制

| 文件 | 大小 | 日期 | 类型 | 状态 |
|---|---|---|---|---|
| `/mnt/vendor/bin/dmenu.bin` | 228KB | 05-26 | 32 位 armhf ELF | 旧版(dmenu_ln 默认) |
| `/mnt/vendor/bin/muos1.bin` | 199KB | 05-26 | 32 位 armhf ELF | **当前启用**(muos1.ini) |
| `/mnt/vendor/bin/muos2.bin` | 212KB | 05-26 | 32 位 armhf ELF | 备用(需 muos2.ini;比 muos1 多 NDS 相关串) |

- 三者引用的外部 .sh **完全一致**(strings 交叉验证)
- `launcher.sh stop` 里 `killall -s SIGUSR1 muos.bin`(注意名字对不上 muos1.bin,疑似厂商脚本遗留笔误;dmenu.bin 的 killall 正常)

### 1.3.5 接力退出机制(启动器与游戏/应用如何交替运行,2026-08-13 实测)

**现象**:启动游戏后 muos1 进程消失;关闭游戏后 muos1 又出现。

**原理:启动器"主动让位",不是被杀**。三环节接力:

**① loadapp.sh 循环**(常驻,负责"复活"):
```bash
while [ -f $RunBin ]; do
    $RunBin          # 前台跑 dmenu_ln,阻塞等它退出
done                 # dmenu_ln 一退出,循环立刻再来一轮 → muos1 复活
```

**② dmenu_ln 调度**(常驻,负责"交接"):
```bash
ACT="/tmp/.next"
if $CMD > /dev/null 2>&1; then     # 跑 muos1.bin,阻塞等它退出
    if [ -f "$ACT" ]; then
        sh $ACT > /dev/null 2>&1   # 跑游戏启动脚本,继续阻塞等游戏退出
    fi
    # rm -f "$ACT"  ← 被厂商注释掉(游戏结束 .next 会残留;muos1 启动时自行清理)
else
    sleep 30                       # muos1.bin 异常退出才走这(30 秒后重试)
fi
```

**③ muos1.bin 行为**:玩家选游戏/应用 → 把启动命令写进 `/tmp/.next` → **自己 exit(0)**。

**完整时序**:
```
玩家在菜单            玩家选游戏                    游戏中              退出游戏
─────────┬────────────┬─────────────────────────────┬──────────────────
muos1.bin│ 写.next退出 │ (消失,不占内存)              │ 被 loadapp.sh 重新拉起
dmenu_ln │  等待中     │ sh /tmp/.next → RA_launch → retroarch
loadapp  │  循环等待   │          ↑ 全链路阻塞等待游戏
```

**设计目的**:muos1.bin 常驻占 ~50MB RSS(实测,运行中 CPU ~80%),1.9G 内存设备玩游戏必须让位。

**推论**:
1. 盖屏"游戏中暂停"检测逻辑在 muos1.bin 里,但它游戏期间不在场 → 厂商要么用了别的方式实现暂停,要么没实现(待实测)
2. **ES-DE APPS 形态零风险的原因即此**:从 dmenu 启动 ES-DE 时,muos1 同样写 .next 退出,ES-DE 独占屏幕;ES-DE 退出 → muos1 复活。整条链天然就是为"应用让位"设计的
3. 进程树实测:`loadapp.sh` → `dmenu_ln` → `muos1.bin` 三级父子链

**2026-08-13 真机观测实证**(SSH 监视器每 2 秒快照,游戏启动全程):
- `/tmp/.next` 实际内容:`/mnt/mod/ctrl/RA_launch.sh mgba_libretro.so  "/mnt/mmc/Roms/GBA/B 变速齿轮-公路旅行.gba"`(core 名 + 双空格 + ROM 路径)
- 游戏期间进程链:`dmenu_ln → RA_launch.sh(26969)→(bezels.sh 瞬时)→ retroarch -c /.config/retroarch/retroarch_GBA.cfg -L /mnt/vendor/deep/retro/cores/mgba_libretro.so <rom>`;muos1.bin 全程不在;RA RSS 32MB → 164MB
- `RA_launch.sh` 自带 set -x 完整 trace → `/mnt/mod/ctrl/configs/RA_launch.log`(每次启动覆盖)
- 每机种预生成配置 `/.config/retroarch/retroarch_<EMU>.cfg`(出厂自带,每次启动动态更新)

### 1.3.6 电源键行为(2026-08-13 实测 pwr_new.sh + system.cfg)

由 cexpert 调 `pwr_new.sh`(无参 = 电源键按下),按 `/mnt/mod/ctrl/configs/system.cfg` 的 `power.key` 决定:
- `power.key=0`:直接挂起(`echo mem > /sys/power/state`,**内核挂起路径**,与超级待机的 PMIC os_sleep 是两条不同通路)
- `power.key=2`(本机当前值):1 秒内按住 **M 键+电源** = 关机,否则挂起
- 目标检测 `pidof retroarch/dmenu.bin/muos.bin` 决定关机分支 —— 注意 `muos.bin` 与实际进程名 `muos1.bin` 不符,**ES-DE 前台时三个 pidof 全空 → 落 "sleep" 分支**(即 ES-DE 下按电源键 = 内核挂起,可唤醒,ES-DE 仍在)

### 1.4 启动器配置存储

| 文件 | 内容 |
|---|---|
| `/mnt/data/dmenu/dmenu_attr.ini` | **二进制格式**设置(实测含 WiFi 名 "masha-iqoo" 等) |
| `/mnt/data/dmenu/localpad.map` | 手柄映射(strings 引用) |
| `/mnt/data/logo.ini`、`/mnt/mmc/dmenu.del` | 启动 logo / 删除标记(strings 引用) |
| `/mnt/vendor/oem/board.ini`、`language.ini` | 板型(RG28xx 等判断)、语言 |

---

## 二、内置功能(从 muos1.bin strings 提炼)

| 功能 | 实现证据 | 说明 |
|---|---|---|
| **待机模式**(正常/超级) | `Normal standby`/`Super standby`/`Standby mode`/`enter_sleep_state`/`++++ hall to sleep` | muos1.bin 有相关 UI 逻辑;**睡眠触发实为常驻守护写标准 mem 挂起**(2026-08-14 修正,见 3.3) |
| RetroArch 配置管理 | 调 `setRA.sh adv/easy/language/rest/run` | 高级/简单模式、语言同步、重置、直跑 |
| 语言切换 | 9 语言映射(zh_CN/zh_TW/en_US/ja_JP/ko_KR/es_LA/ru_RU/de_DE/fr_FR/pt_BR) | `sw` 脚本同步 APPS 名 |
| CPU 频率 | 调 `cpu_setting.sh` | performance/interactive/powersave |
| 蓝牙 | 调 `setBluetooth.sh init` | rtk_hciattach ttyS1 |
| WiFi 热点 | 调 `setHostapd.sh` | hostapd/dnsmasq |
| SSH 开关 | 调 `setSSH.sh` | systemctl restart ssh |
| 电源键 | 调 `pwr_new.sh` | 锁文件 /tmp/.power_key;见下方"电源键行为" |
| SD 卡热插拔 | 调 `mmc_new.sh add` / `mmc.sh remove` | **实际由 cexpert 守护调用**,与启动器无关 |
| 各模拟器专属设置 | setFlycast/setNDS/setPSP/setSaturn | 存档目录、BIOS/HLE、语言、配置恢复 |
| APPS 应用 | 扫 `/mnt/mmc/Roms/APPS`,目录内找 `launch.sh` | 多语言 "找不到 launch.sh" 提示 |
| 主题 | `get_muos_theme_by_dir` | muOS 风格主题加载 |

---

## 三、盖屏待机机制(翻盖掌机核心功能,ES-DE 缺失点)

### 3.1 硬件通路(实测)

- 翻盖检测 = **hall 开关**(磁感应),接在 **AXP2202 PMIC**
- 内核中断:dmesg 可见 `hall_switch_isr` / `hall_press_work_func: state=0/1`(`[allen]` 前缀厂商打印)
- 状态可读:`/sys/class/power_supply/axp2202-battery/hallkey`(**1=开盖,0=合盖**)
- GPIO:`gpio-135 (hall switch) in hi`(/sys/kernel/debug/gpio)
- 睡眠控制:`/sys/class/power_supply/axp2202-battery/os_sleep`(进睡眠)、`workled_sleep`(睡眠 LED)
- 唤醒相关:`rtcwake -d rtc1 -m mem -s 1`(strings)

### 3.2 两个模式

| 模式 | 关盖 | 开盖 | 唤醒 |
|---|---|---|---|
| 正常待机 | hall 检测 → 关背光/黑屏(+游戏中暂停?) | 自动亮屏恢复 | 自动 |
| 超级待机 | hall → 黑屏 + 断 WiFi + **标准内核 mem 挂起**(2026-08-14 修正:非 PMIC os_sleep 独立通路,见 3.3) | **不唤醒** | 需按电源键 |

### 3.3 超级待机实测(2026-08-13,设备端监视器 1 秒快照)

**实验**:超级待机模式下,合盖 → 等 20 秒 → 开盖 → 按电源键。

**实测时间线**:

| 时刻 | 事件 | 证据 |
|---|---|---|
| 01:00:27.587 | 合盖,**hallkey 1→0** | 监视器最后一条记录 |
| 27.6s → 57.2s | **整机睡眠(约 30 秒)** | 监视器 1 秒一跳期间零记录 = 用户态冻结 |
| ~01:00:47 | 开盖 | 无任何反应(超级待机不响应开盖) |
| ~01:00:50 | 按电源键 | 唤醒流程开始 |
| 01:00:57.168 | 系统恢复 | 监视器续记,hallkey=1 |

**唤醒瞬间内核活动**(真·挂起的铁证):
```
dmesg: sunxi-mmc sdc0: sdc set ios:clk 50000000Hz ... ← SD 卡重新初始化
dmesg: RTW: rtw_set_802_11_connect(wlan0) fw_state=0x08 ← WiFi 芯片重连
wlan0=dormant                                        ← WiFi 断了再恢复
```

**机制全图(2026-08-14 dmesg -w 实测修正,推翻初版结论)**:
1. **睡眠 = 标准内核 mem 挂起**:dmesg -w 捕获触发瞬间 —— 合盖(hall ISR)→ ~1.2s → `PM: Preparing system for sleep (mem)`,与 `echo mem > /sys/power/state` 完全相同。**初版"os_sleep 触发 PMIC 挂起"的结论有误**
2. **os_sleep 节点只是 PMIC 配置接口**:每 ~1.1s 写入值 1(内核打印 `os_sleep_type= 1`)是某个**常驻守护**的"上膛"循环(实测 ES-DE 前台、muos1 不在时打印照常 → 不是 muos1.bin;写入者身份未实锤,cexpert 无 hall 字符串);值域实测:1 被接受,0/2/3/5/10 静默拒绝;节点 write-only
3. 开盖不唤醒;**电源键唤醒由 PMIC 硬件负责**,不依赖任何进程
4. **白名单行为**(解释"为什么只有 muos/RA 前台会挂起"):常驻守护检测到合盖后,只对自家启动器/游戏执行挂起,对陌生应用(ES-DE 等 APPS)只做变暗 —— ES-DE 前台合盖无反应即此因
5. WiFi:长睡眠(30s)断网重连(本表实测);短睡眠(~20s)不断(echo mem 实测) —— 与 CPU 休眠深度无关,厂商睡眠通路可能附带 WiFi 断电动作
6. 充电唤醒:axp2202-usb 的 wakeup=enabled,但其 wakeup_count=0(历史上从未真正从挂起中被充电事件唤醒过)—— 充电插拔是否唤醒待实测

**ES-DE 的 lid 守护(最终实现,已验收,详见 3.4)**:
```bash
# 合盖(hallkey 连续 2 次为 0,且无游戏运行标志):
echo mem > /sys/power/state     # 标准内核挂起,与厂商同源
# 唤醒:电源键(PMIC 硬件);唤醒后需先观察到开盖才重新武装
```

### 3.4 ES-DE 待机守护(2026-08-14 实施,含合盖+电源键,验收通过)

**架构**:`standby-daemon.py`(python3 单进程,发行包内,安装到 `/mnt/data/`),由 ES-DE.sh 启动、ES-DE 退出时 trap 杀掉。**两个触发源汇聚一个挂起动作**:

```
standby-daemon.py(单线程:select 监听 event0 + 轮询 hallkey)
├── 触发 1:电源键(KEY_POWER=116 按下事件)
├── 触发 2:合盖(hallkey 连续 2 次为 0 去抖)
├── 共同守卫:/tmp/esde_game_running(游戏中让位,厂商/RA 原生处理)
└── 唯一动作:echo mem > /sys/power/state
```

**防误触设计**:
- 合盖:唤醒后需先观察到开盖(hallkey=1)才重新武装
- 电源键:**唤醒后 5 秒冷却 + 清空 event0 队列**(唤醒那次按键的 press/release 残留在队列,不处理会唤醒瞬间二次挂起)
- 原机"M 键+电源=关机"组合键不复刻(只做短按挂起),README 注明

**电源键无反应的根因(2026-08-14 evtest 实测)**:KEY_POWER 事件完整到达内核(event0,evtest 捕获 press/release),PMIC 驱动有反应(set_my_work_lowpwr_led 打印),但**用户态无人处理** —— 平时处理电源键的是 muos1.bin,它退出后没人接管(与合盖"白名单变暗"是同一类设计)。

**关键调研结论(2026-08-14,纠正早期假设)**:
1. **厂商超级待机的睡眠 = 标准内核 mem 挂起**(dmesg -w 实测捕获:`PM: Preparing system for sleep (mem)`,与 echo mem 完全相同),所谓 os_sleep 不是独立睡眠通路
2. `os_sleep` sysfs 节点是 **PMIC 配置接口**:每 1.1 秒写入值 1 = 厂商守护的"上膛"(内核打印 `os_sleep_type= 1` 即此);其他值(0/2/3/5/10)被静默拒绝;真正触发挂起的就是写 mem
3. **厂商守护的"白名单"行为**:合盖后只对自家启动器/游戏执行挂起,对陌生应用(ES-DE 等)只做变暗 —— 这就是"ES-DE 前台合盖无反应"的根因(守护身份未实锤,cexpert 无 hall 字符串)
4. 游戏中(RA 前台)合盖挂起由厂商守护原生处理(实测可用)→ standby-daemon 用 ES-DE 事件脚本标志(game-start/game-end 维护 /tmp/esde_game_running)**主动让位**,防双重挂起
5. 电源键在 ES-DE 前台无反应(evtest 实测事件到达内核但用户态无人接管),standby-daemon 一并补上(2026-08-14 增补)
5. WiFi/充电唤醒行为差异:短睡眠 WiFi 不断(厂商长睡眠断);充电是否唤醒待实测(axp2202-usb wakeup=enabled 但 wakeup_count=0)

**验收结果(2026-08-14 实测)**:菜单电源键→挂起→电源键→回 ES-DE(9s 周期,无二次挂起);菜单合盖→挂起→电源键→回 ES-DE(回归);游戏中让位正常;退出 ES-DE 后 daemon 被杀、原机待机不受影响。

**正常待机(只关屏)未实现**(用户决定不需要):候选背光点 fb0 blank / cexpert 的变暗动作,留档备查。

### 3.5 关键结论

- **待机逻辑全部内置在 muos1.bin 二进制内**,cexpert/brightCtrl 均无 hall/sleep 相关逻辑(strings 验证)
- → **ES-DE 前台时无盖屏待机能力**(ES-DE 只读 SDL 事件,不看 hallkey)—— 已实测确认
- → 给 ES-DE 补此能力:lid 守护方案见 3.4(超级待机配方实测零风险;正常待机背光控制点待验证)
- 游戏中暂停(厂商宣称)是否真实发生、如何实现,尚待实测验证

---

## 四、外部脚本调用清单(三个启动器二进制完全一致)

### 4.1 游戏启动

| 脚本 | 用途 |
|---|---|
| `/mnt/mod/ctrl/RA_launch.sh` | **RetroArch 统一启动入口**:fontconfig 1.12.0→1.10.1 软链修复(每次启动前)、按机种生成/更新 `/.config/retroarch/retroarch_<机种>.cfg`、着色器/边框/热键/自动读档;实际命令 `retroarch -c <RACONFIG> -L <core> <rom>`;调用格式实测:`RA_launch.sh <core名> "<rom路径>"`;自带 set -x 日志到 `/mnt/mod/ctrl/configs/RA_launch.log` |

**⚠️ fontconfig 版本争夺战(2026-08-14 实测,ES-DE 集成关键坑)**:32 位 RetroArch 需要 fontconfig **1.10.1**,而 64 位应用(ES-DE 的 libpangoft2)需要 `FcWeightFromOpenTypeDouble` —— 该符号**仅 1.12.0 有**(nm 实测 1.10.1=0、1.12.0=1)。RA_launch.sh 每次启动游戏把 `/lib/aarch64-linux-gnu/libfontconfig.so.1` 翻到 1.10.1 后**不回翻** → 之后启动 64 位应用会秒退(`symbol lookup error`)。ES-DE 的解法:ES-DE.sh 启动前翻回 1.12.0(见 plan 7.13)。

### 4.2 系统功能

| 脚本 | 用途 |
|---|---|
| `/mnt/vendor/ctrl/cpu_setting.sh` | CPU governor 三档切换 |
| `/mnt/vendor/ctrl/mmc_new.sh add` / `mmc.sh remove` | SD/TF 卡热插拔挂载(cexpert 调用) |
| `/mnt/vendor/ctrl/pwr_new.sh` | 电源键处理(锁 /tmp/.power_key) |
| `/mnt/vendor/ctrl/setBluetooth.sh` | 蓝牙 init |
| `/mnt/vendor/ctrl/setHostapd.sh` | WiFi 热点开关 |
| `/mnt/vendor/ctrl/setSSH.sh` | SSH 服务重启 |
| `/mnt/vendor/ctrl/setRA.sh`(adv/easy/language/rest/run) | RA 配置管理(写 /.config/retroarch) |
| `/mnt/vendor/ctrl/setNDS.sh`(recover/run/savedir) | drastic 配置/启动/存档 |
| `/mnt/vendor/ctrl/setPSP.sh`(language/recover) | PPSSPP 语言/配置恢复 |
| `/mnt/vendor/ctrl/setSaturn.sh`(BIOS/HLE) | 土星 BIOS/HLE + 存档位置 |

### 4.3 独立模拟器/应用

| 脚本 | 用途 |
|---|---|
| `/mnt/vendor/deep/drastic-modify/launch.sh`(+recovery.sh) | NDS 模拟器(SDL_VIDEODRIVER=anbernic,独立 HOME) |
| `/mnt/vendor/deep/emuJava/launch.sh` | Java 游戏(自带 jdk) |
| `/mnt/vendor/deep/openBOR/scripts/openbor.sh` | OpenBOR 引擎 |
| `/mnt/vendor/bin/pdf/launch.sh` | PDF 阅读器 |
| `/mnt/mmc/EXE/pico-8/launch.sh` | PICO-8(PortMaster 检测) |

---

## 五、对 ES-DE 集成的启示

1. **游戏启动必须走 `RA_launch.sh`**(或复刻其 fontconfig 修复 + `-c` 配置)—— 这是本机 RetroArch 唯一验证可用的启动路径
2. **替换启动器只替换 UI 二进制**:mmc_new.sh 由 cexpert 调用、brightCtrl/cexpert 由 launcher.sh 拉起,均不受替换影响;所有 4.2/4.3 脚本保留可用
3. **盖屏待机需要自建 lid 守护**(见 3.3),否则 ES-DE 下翻盖无效果
4. **muos1/muos2 ini 切换逻辑在 dmenu_ln 里**,替换 dmenu_ln 时(wrapper 方案)需保留或复刻该逻辑
5. **dmenu_attr.ini 是二进制格式**,直接编辑不可行;若需改官方设置项,通过启动器 UI 操作
