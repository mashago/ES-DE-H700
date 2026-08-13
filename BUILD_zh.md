# 构建配方(在 H700 / DeepPlayOS 设备上本机编译)

> 记录本发行版二进制(`esde/es-de`)的确切构建方法。上游源码:v3.4.1,https://gitlab.com/es-de/emulationstation-de
> [English version](BUILD.md)

## 前置条件

- 原厂 DeepPlayOS(Ubuntu 22.04 aarch64,内核 4.9.170,root SSH)
- 磁盘:`/` 剩余 ≥1.5G(apt 依赖),编译目录放 `/mnt/data`(≥1G)
- 内存 1.9G:**必须先建 swapfile** —— `GuiScraperMenu.cpp` 单文件编译峰值超 1.9G(`-j1` 也扛不住,实测 OOM)

## 步骤

```bash
# 1. swapfile
dd if=/dev/zero of=/mnt/data/swapfile bs=1M count=1536
mkswap /mnt/data/swapfile && swapon /mnt/data/swapfile

# 2. 依赖(清华源;注意:故意不装 libsdl2-dev,apt 的 mesa 版会污染厂商 mali 版 SDL2)
apt-get install -y --no-install-recommends build-essential clang-format git cmake gettext \
  libharfbuzz-dev libicu-dev libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev \
  libfreeimage-dev libfreetype6-dev libgit2-dev libcurl4-openssl-dev libpugixml-dev \
  libasound2-dev libbluetooth-dev libpoppler-cpp-dev libgles2-mesa-dev

# 3. SDL2 头:ES-DE 需要 SDL_locale.h(2.0.14+),厂商自带头是 2.0.12
#    下载 SDL2-2.28.5 源码包(libsdl.org),把 include/*.h 覆盖到 /usr/include/SDL2/
#    注意:SDL_config.h 也会被替换(2.28.5 源码包自带);头仅编译期使用,不影响运行
#    运行时库用厂商 BSP 自带的 /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.2800.5(自带 mali 驱动)

# 4. cmake 配置(构建目录 /mnt/data/build)
mkdir -p /mnt/data/build && cd /mnt/data/build
cmake -DGLES=on -DHINT_GLES_LIBNAME=mali -DHINT_GLES_LIBDIR=/usr/lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DSDL2_INCLUDE_DIR=/usr/include/SDL2 \
  -DSDL2_LIBRARY=/usr/lib/aarch64-linux-gnu/libSDL2.so \
  <源码目录>

# 5. 编译
make -j1
# 产物:源码根目录下的 es-de(ES-DE 的 CMake 输出路径惯例,不在 build 目录)
```

## 运行环境要求(install.sh 会检查)

- 32 位 RetroArch `/mnt/vendor/deep/retro/retroarch`(v1.22,armhf)+ 32 位 cores
- `/mnt/mod/ctrl/RA_launch.sh`(muOS 风格原厂启动器自带)
- `/usr/lib/libmali.so`(64 位)+ `/usr/lib32/` 下的 32 位库环境
- 厂商 SDL2 2.28.x 带 mali 驱动
- `/mnt/data/mali-lib/`:libEGL/libGLESv2/libGLESv1_CM/libGLES_CM → libmali.so;libSDL2-2.0.so.0 → 2.28.x

## 已知环境坑(构建/运行都会踩)

1. **fontconfig 争夺战**:厂商 RA_launch.sh 启动 32 位 RetroArch 前把 `libfontconfig.so.1` 翻到 1.10.1(RA 需要);64 位应用(ES-DE 的 libpangoft2)需要 `FcWeightFromOpenTypeDouble` —— 该符号仅 1.12.0 有(nm 实测)→ ES-DE.sh 启动前翻回 1.12.0,否则 es-de 秒退
2. **32 位环境隔离**:ES-DE 的 LD_LIBRARY_PATH(64 位 mali-lib)会继承给游戏进程 → wrapper 必须重建 `/usr/lib32:/usr/lib:/mnt/vendor/lib`,否则 32 位 RA 报 `wrong ELF class`
3. **libmali 直链**:链接报 `.dynsym` 裁剪警告,属厂商 blob 正常现象,不影响
