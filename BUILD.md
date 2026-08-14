# Build Recipe (native build on H700 / the stock Anbernic firmware)

> Documents exactly how the `esde/es-de` binary in this repo was produced. Upstream source: v3.4.1, https://gitlab.com/es-de/emulationstation-de
> [中文版](BUILD_zh.md)

## Prerequisites

- Stock Firmware (Ubuntu 22.04 aarch64, kernel 4.9.170, root SSH access)
- Disk: `/` needs ≥1.5 GB free (apt dependencies); build directory on `/mnt/data` (≥1 GB)
- RAM 1.9 GB: **a swapfile is mandatory** — `GuiScraperMenu.cpp` alone exceeds 1.9 GB during compilation (OOM even with `-j1`)

## Steps

```bash
# 1. Swapfile
dd if=/dev/zero of=/mnt/data/swapfile bs=1M count=1536
mkswap /mnt/data/swapfile && swapon /mnt/data/swapfile

# 2. Dependencies (Tsinghua mirror; note: deliberately NO libsdl2-dev —
#    the apt/mesa SDL2 would pollute the vendor's mali-enabled SDL2)
apt-get install -y --no-install-recommends build-essential clang-format git cmake gettext \
  libharfbuzz-dev libicu-dev libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev \
  libfreeimage-dev libfreetype6-dev libgit2-dev libcurl4-openssl-dev libpugixml-dev \
  libasound2-dev libbluetooth-dev libpoppler-cpp-dev libgles2-mesa-dev

# 3. SDL2 headers: ES-DE needs SDL_locale.h (SDL 2.0.14+), vendor headers are 2.0.12.
#    Download the SDL2-2.28.5 source tarball (libsdl.org) and overwrite /usr/include/SDL2/
#    with include/*.h. Note: SDL_config.h is also replaced (the tarball ships its own);
#    headers are compile-time only, so this does not affect the runtime.
#    Runtime library: the vendor BSP already ships /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.2800.5
#    (with the mali video driver).

# 4. CMake configuration (build dir on /mnt/data)
mkdir -p /mnt/data/build && cd /mnt/data/build
cmake -DGLES=on -DHINT_GLES_LIBNAME=mali -DHINT_GLES_LIBDIR=/usr/lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DSDL2_INCLUDE_DIR=/usr/include/SDL2 \
  -DSDL2_LIBRARY=/usr/lib/aarch64-linux-gnu/libSDL2.so \
  <source dir>

# 5. Compile
make -j1
# Output: es-de in the SOURCE ROOT (ES-DE's CMake output convention, not in the build dir)
```

## Runtime environment requirements (checked by install.sh)

- 32-bit RetroArch `/mnt/vendor/deep/retro/retroarch` (v1.22, armhf) + 32-bit cores
- `/mnt/mod/ctrl/RA_launch.sh` (ships with the muOS-style stock launcher)
- `/usr/lib/libmali.so` (64-bit) + the 32-bit lib environment under `/usr/lib32/`
- Vendor SDL2 2.28.x with the mali driver
- `/mnt/data/mali-lib/`: libEGL/libGLESv2/libGLESv1_CM/libGLES_CM → libmali.so; libSDL2-2.0.so.0 → 2.28.x

## Known pitfalls (build & run)

1. **fontconfig tug-of-war**: `RA_launch.sh` flips `libfontconfig.so.1` to 1.10.1 before launching the 32-bit RetroArch (which needs it); 64-bit apps (ES-DE's libpangoft2) need `FcWeightFromOpenTypeDouble`, which only exists in 1.12.0 → ES-DE.sh flips it back to 1.12.0 at launch
2. **32-bit environment isolation**: ES-DE's LD_LIBRARY_PATH (64-bit mali-lib) is inherited by game processes → the wrapper must rebuild `/usr/lib32:/usr/lib:/mnt/vendor/lib`
3. **libmali direct linking**: the linker emits `.dynsym` truncation warnings — a known quirk of the vendor blob, harmless
