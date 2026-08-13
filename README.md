# ES-DE for Anbernic H700(原厂 DeepPlayOS)

在 **Anbernic H700 系列掌机**(RG34XXSP / RG35XX Plus / RG35XX H / RG35XX SP / RG35XX 2024 / RG40XX H / RG40XX V / RG28XX / RG CUBEXX / RG34XX)**保留原厂系统**的情况下,以 **dmenu APPS 应用形态**运行 ES-DE 3.4.1(OpenGL ES 渲染,硬件加速)。

不刷机、不换系统、不动启动链 —— 从 dmenu 进入 ES-DE,退出即回原启动器,零风险。

## 特性

- ES-DE 3.4.1 自编译 **OpenGL ES 版**(Mali-G31 硬件渲染,GLES 3.2,720x480 满帧)
- 游戏启动走**厂商原路**(`RA_launch.sh`):边框、着色器、按机种配置、自动读档/存盘全部与官方启动器一致
- 内置手柄精确映射(A/B/X/Y/L1/L2/R1/R2/方向/SELECT/START;ROM 目录自动扫描 `/mnt/mmc/Roms`)
- 主题、刮削、收藏等 ES-DE 完整功能

## 安装

把本仓库拷贝到掌机任意目录(建议 `/mnt/mmc/` 下),SSH 进去:

```bash
cd ES-DE-H700
sh install.sh
```

安装完成后,dmenu 的 **APPS** 分类里出现「ES-DE」,直接启动。

### 卸载

```bash
rm -rf /mnt/mmc/Roms/APPS/esde /mnt/mmc/Roms/APPS/ES-DE.sh
rm -rf /mnt/data/es-de-home /mnt/data/mali-lib /mnt/data/retroarch-wrapper.sh
```

## 使用提示

| 事项 | 说明 |
|---|---|
| 键位 | START 打开菜单;**MENU 键无动作**(ES-DE 无 guide 动作,属设计如此) |
| 主题 | 解压主题文件夹到 `/mnt/data/es-de-home/ES-DE/themes/`;本机实测 `art-book-next` 在 720x480 显示正常 |
| ROM | 标准布局 `/mnt/mmc/Roms/<机种小写>`(如 gba、sfc、fc),vfat 大小写不敏感,大写目录同样识别 |
| 音量 | 游戏内音量走 RetroArch 原配置(与官方启动器一致) |

## 已知限制

1. **ES-DE 界面无声音**(`SDL_AUDIODRIVER=dummy`):ES-DE 3.x 需 PulseAudio/PipeWire,本机未装。游戏内声音不受影响
2. **盖屏待机未实现**:官方启动器的翻盖关屏/超级待机逻辑内置在 muos1.bin 中,ES-DE 不自带。未来计划以 lid 守护脚本补上(超级待机实测机制已摸清,见项目文档 `OFFICIAL_LAUNCHER.md`)
3. USB 手柄:标准 SDL 手柄自动支持;内置手柄映射文件针对 `ANBERNIC-keys`(GUID `19002cb4...`),不同固件版本若识别名不同,需重新配置键位

## 故障排查

| 现象 | 原因与处理 |
|---|---|
| ES-DE 秒退,log 报 `FcWeightFromOpenTypeDouble` | fontconfig 被厂商游戏启动脚本翻到 1.10.1;用 ES-DE.sh 启动会自动翻回 1.12.0(重启 ES-DE 即可) |
| 启动游戏闪退,RA_launch.log 报 `wrong ELF class` | wrapper 环境缺失;确认 `/mnt/data/retroarch-wrapper.sh` 存在且含 32 位库路径 |
| 找不到游戏 | 确认 ROM 在 `/mnt/mmc/Roms/<机种>/`;或改 `es_settings.xml` 的 `ROMDirectory` |
| 键位不对 | 重新校准:删除 `/mnt/data/es-de-home/ES-DE/settings/es_input.xml` 后进 ES-DE 重配 |

日志位置:ES-DE 内部 `/mnt/data/es-de-home/ES-DE/logs/es_log.txt`;启动脚本 stdout `/mnt/mmc/Roms/APPS/esde/log.txt`;游戏启动 trace `/mnt/mod/ctrl/configs/RA_launch.log`。

## 构建

本项目是 ES-DE 3.4.1 在 H700/DeepPlayOS 上的移植发行版,构建配方见 [BUILD.md](BUILD.md)。ES-DE 本体为 MIT 许可(见 LICENSE),上游源码:https://gitlab.com/es-de/emulationstation-de

## 致谢

ES-DE 作者 Leon Styhre / Northwestern Software AB;Anbernic H700 社区。
