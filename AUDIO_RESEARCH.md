# ES-DE 音频方案调研(2026-08-14)

> 结论:**保持 `SDL_AUDIODRIVER=dummy` 静音运行**。ES-DE UI 无声音,游戏内声音完全正常。
> 本文记录全部调研证据与方案权衡,供未来重启音频工作参考。

---

## 一、音频栈现状

| 层 | 事实 |
|---|---|
| 声卡 | audiocodec(codec 直连),另有 ahubdam/ahubhdmi(HDMI 输出) |
| ALSA 配置 | `/etc/asound.conf`:default PCM = `type hooks → slave hw:audiocodec`,**无 dmix,设备独占** |
| hooks 副作用 | default PCM **每次打开时**:把 "digital volume" 设为 **63** 并 **lock**(preserve true / lock true / value 63);关闭时恢复原值 |
| RetroArch(32 位) | `audio_driver=alsathread` → default PCM,游戏声音正常;音量由 RA 自己的 `audio_volume`(软件增益)控制 |
| ES-DE(64 位) | SDL2 音频 → 默认驱动选 ALSA;当前 `SDL_AUDIODRIVER=dummy` 静音 |
| 音量键 | ANBERNIC-keys 的 KEY_VOLUMEUP/DOWN 键盘事件;ES-DE 源码**无任何 SDLK_VOLUME 处理** |

## 二、实测证据(2026-08-14)

1. **ES-DE 用 ALSA 时 UI 声音正常**(移除 dummy 实测,`Audio driver: alsa`,设备 audiocodec)
2. **但进入游戏后游戏无声**:ES-DE 启动游戏后仅 `SDL_PauseAudioDevice(1)`(AudioManager::stop,ViewController.cpp 游戏启动路径),**设备句柄不释放**;default PCM 独占 → 32 位 RA 抢不到声卡
3. **锁实验**:ES-DE 运行时(PCM state: RUNNING,常驻),`amixer cset name='digital volume' 50` → **"Operation not permitted"** —— hooks 的 lock 是真锁,ES-DE 音频设备打开期间**任何进程都改不动硬件音量**(muos 能调是因为它只在播声音瞬间开设备)

## 三、ES-DE 声音设置三个滑条的真实含义(源码核实)

| 设置 | 实际作用 | 本机状态 |
|---|---|---|
| SYSTEM VOLUME(系统音量) | `VolumeControl.cpp`:snd_mixer 找 **"Master"** 控制并读写 | **失效** —— 本机控制名是 "digital volume",没有 Master → 滑条显示 0%、改了无效果 |
| NAVIGATION SOUNDS VOLUME | ES-DE 内部软件增益(UI 导航音) | 正常(硬件无关) |
| VIDEO PLAYER VOLUME | ES-DE 内部软件增益(视频预览音) | 正常(硬件无关) |

## 四、厂商机制

- **muos1.bin 音量**:内置 `tinymixer_get/set_value`(直接 ALSA 控制),PCM 关闭期间写 digital volume;音量条是其自绘 UI
- **volumeCtrl.dge**(APPS 模式音量守护):SDL 1.2 程序(带 SDL_ttf/SDL_gfx,自绘 OSD),读 event0/event1,调 mixer 的 digital volume。厂商 APPS 脚本模式:启动前拉起、退出 `kill -9`
- **RA_launch.sh**:管 RA 的 `audio_volume` 软件音量(按机种配置、音量记忆),不碰硬件 mixer

## 五、方案权衡(全部评估过)

| 方案 | 内容 | 否决/保留原因 |
|---|---|---|
| A 接入 volumeCtrl.dge | ES-DE.sh 拉起守护 + 32 位环境 | ❌ 它写 digital volume,ES-DE 常驻 PCM 时被 lock 拒绝(EPERM);OSD 是 SDL1.2 直画 fb,与 ES-DE 60fps EGL 渲染冲突 |
| B dmix 混音 | 改 asound.conf default 加 dmix | ❌ 用户不接受动系统文件 |
| C 源码补丁:音量键→硬件音量+弹窗 | InputManager 绑键 + VolumeControl + mixerName 改 "digital volume" | ❌ 被 lock 拒绝,写不进去 |
| C' 源码补丁:音量键→ES-DE 软件增益+弹窗 | 只调 ES-DE 内部音量,游戏内由 RA 热键接管 | 可选,但与"UI/游戏音量联动"期望不符,用户放弃 |
| B' 解锁 asound.conf | 去掉 hooks 的 lock/value → 写硬件音量全局生效(UI+游戏同源,与原机一致) | 唯一能实现"系统音量应用到游戏"的路线;但动厂商系统文件,用户放弃 |
| **F 保持 dummy** | `SDL_AUDIODRIVER=dummy` | ✅ **最终决定**(2026-08-14):UI 无声音,游戏声音正常,零风险零改动 |

**另发现的一个源码 bug(记录备用,未修)**:游戏无声的直接原因是 ES-DE 启动游戏时只 `stop()`(pause)不 `deinit()`,在独占 ALSA 设备上设备不释放。若未来启用 ALSA,需在 game->launchGame() 前 `AudioManager::deinit()`、返回后 `init()`(补丁思路已验证可行,因用户决定保持 dummy 已回退)。

## 六、附:音量键当前行为

- ES-DE 前台:音量键无反应(ES-DE 不认,守护未接入)
- 游戏内:RA 按自身配置处理(热键音量,与原机一致)
- 硬件数字音量被 hooks 钉在 63(原机 muos 设置的值在 ES-DE 打开音频期间会被暂时覆盖为 63,关闭后恢复 —— 因我们已用 dummy,ES-DE 不再打开 PCM,此项无影响)

## 七、未来重启音频的可选路径(按风险排序)

1. C' 软件音量(只 UI 声音,改动 ES-DE 源码,~50 行)
2. B' 解锁 asound.conf + C(全局音量,动系统文件 + 源码补丁)
3. 装 PulseAudio(重量级,不推荐)
