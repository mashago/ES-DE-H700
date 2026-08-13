# ES-DE for Anbernic H700 (Stock DeepPlayOS)

Run **ES-DE 3.4.1** (OpenGL ES renderer, hardware accelerated) on **Anbernic H700 handhelds** (RG34XXSP / RG35XX Plus / RG35XX H / RG35XX SP / RG35XX 2024 / RG40XX H / RG40XX V / RG28XX / RG CUBEXX / RG34XX) **while keeping the stock system** — delivered as a dmenu APPS application.

No reflash, no system replacement, no boot-chain changes. Launch ES-DE from dmenu, exit back to the stock launcher. Zero risk.

[中文版](README_zh.md) | Build recipe: [BUILD.md](BUILD.md) (中文: [BUILD_zh.md](BUILD_zh.md))

> **Binary source**: the `es-de` binary in this repo is compiled from the official **ES-DE v3.4.1** source (https://gitlab.com/es-de/emulationstation-de) with the OpenGL ES renderer for the H700's Mali-G31 GPU (GLES 3.2). See [BUILD.md](BUILD.md) for the exact build procedure.

## Features

- ES-DE 3.4.1 self-built **OpenGL ES edition** (Mali-G31 hardware rendering, GLES 3.2, full speed at 720x480)
- Games launch via the **vendor's own path** (`RA_launch.sh`): bezels, shaders, per-system RetroArch configs, savestate auto-load/save — identical behavior to the stock launcher
- Precise built-in gamepad mapping (D-pad/A/B/X/Y/L1/L2/R1/R2/SELECT/START; ROMs auto-scanned from `/mnt/mmc/Roms`)
- Full ES-DE features: themes, scraping, collections, favorites

## Installation

Copy this repo to any directory on the handheld (suggested: under `/mnt/mmc/`), then over SSH:

```bash
cd ES-DE-H700
sh install.sh
```

After installation, "ES-DE" appears in the **APPS** category of dmenu. Just launch it.

### Uninstall

```bash
rm -rf /mnt/mmc/Roms/APPS/esde /mnt/mmc/Roms/APPS/ES-DE.sh
rm -rf /mnt/data/es-de-home /mnt/data/mali-lib /mnt/data/retroarch-wrapper.sh
```

## Usage notes

| Item | Note |
|---|---|
| Buttons | START opens the menu; **the MENU button does nothing** (ES-DE has no guide action, by design) |
| ROMs | Standard layout `/mnt/mmc/Roms/<lowercase system>` (e.g. gba, sfc, fc). vfat is case-insensitive, so uppercase dirs work too |
| Volume | In-game volume uses the original RetroArch config (same as the stock launcher) |

## Themes

Recommended on this device: **art-book-next** by Anthony Caccese — https://github.com/anthonycaccese/art-book-next-es-de — verified to display correctly at 720x480.

Installation steps:
1. Download the zip from the repo above (Code → Download ZIP)
2. Extract the `art-book-next-es-de-main/` folder
3. Place it in `/mnt/data/es-de-home/ES-DE/themes/` (this directory is auto-created by ES-DE on first launch)
4. Restart ES-DE and select the theme in the UI

## Known limitations

1. **No UI sounds** (`SDL_AUDIODRIVER=dummy`): ES-DE 3.x needs PulseAudio/PipeWire, which this system doesn't ship. In-game sound is unaffected.
2. **Lid-close standby not implemented**: the stock launcher's lid-close screen-off / super standby logic is built into muos1.bin itself. A lid daemon is planned for the future (the super-standby mechanism has been fully reverse-engineered and documented in the project notes).
3. USB gamepads: standard SDL controllers are auto-supported. The built-in pad mapping targets `ANBERNIC-keys` (GUID `19002cb4...`); if a different firmware version exposes a different device name, the key mapping needs reconfiguration.

## Troubleshooting

| Symptom | Cause & fix |
|---|---|
| ES-DE exits instantly, log shows `FcWeightFromOpenTypeDouble` | fontconfig was flipped to 1.10.1 by the vendor's game launch script; launching via ES-DE.sh flips it back to 1.12.0 (just restart ES-DE) |
| Game flash-crashes, RA_launch.log shows `wrong ELF class` | Missing wrapper environment; make sure `/mnt/data/retroarch-wrapper.sh` exists and sets the 32-bit library path |
| No games found | Check ROMs are under `/mnt/mmc/Roms/<system>/`, or edit `ROMDirectory` in `es_settings.xml` |
| Wrong key mapping | Reconfigure: delete `/mnt/data/es-de-home/ES-DE/settings/es_input.xml`, then remap in ES-DE |

Log locations: ES-DE internal `/mnt/data/es-de-home/ES-DE/logs/es_log.txt`; launcher stdout `/mnt/mmc/Roms/APPS/esde/log.txt`; game launch trace `/mnt/mod/ctrl/configs/RA_launch.log`.

## Build

This repo is a port/distribution of ES-DE v3.4.1 for H700/DeepPlayOS; the exact build recipe is in [BUILD.md](BUILD.md). ES-DE itself is MIT-licensed (see LICENSE); upstream source: https://gitlab.com/es-de/emulationstation-de

## Credits

ES-DE authors: Leon Styhre / Northwestern Software AB. The Anbernic H700 community.
