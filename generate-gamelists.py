#!/usr/bin/env python3
# generate-gamelists.py — 为所有有游戏的系统批量生成 gamelist.xml
#
# 可选高级工具(install.sh 不自动运行,发行默认关闭 ParseGamelistOnly):
# 配合 ES-DE 的 "Only Parse Gamelist.xml Files"(ParseGamelistOnly)设置,
# 让启动时跳过目录扫描、只读 gamelist,大幅缩短启动时间。
# 代价:新增 ROM 需重跑本脚本(或 ES-DE 内重扫 + 手动处理 gamelist)。
#
# 行为:
#   - 解析 es_systems.xml,取每个系统的 目录名 + 扩展名列表
#   - 扫描 /mnt/mmc/Roms/<目录> 中匹配的文件
#   - 生成 /mnt/data/es-de-home/ES-DE/gamelists/<系统名>/gamelist.xml
#     (仅 path + name,无刮削元数据;name = 文件名去扩展名)
#   - 已存在的 gamelist.xml **合并更新**:保留已有条目(含刮削元数据),
#     仅追加目录里新增的游戏 —— 可安全重复运行
#
# 用法: python3 generate-gamelists.py [es_systems.xml 路径]
# 默认路径: /mnt/mmc/Roms/APPS/esde/resources/systems/linuxarm/es_systems.xml
#
# 注意:生成后新增的 ROM 不会自动出现 —— 需在 ES-DE 界面"重新扫描 ROM 目录",
#      或删除对应 gamelist.xml 后重跑本脚本。

import os
import re
import sys
import xml.etree.ElementTree as ET

ROMROOT = "/mnt/mmc/Roms"
OUTROOT = "/mnt/data/es-de-home/ES-DE/gamelists"


def parse_systems(xml_path):
    text = open(xml_path, encoding="utf-8").read()
    systems = []
    for m in re.finditer(r"<system>(.*?)</system>", text, re.S):
        blk = m.group(1)
        name = re.search(r"<name>\s*([^<\s]+)\s*</name>", blk)
        path = re.search(r"<path>%ROMPATH%/([^<]+)</path>", blk)
        ext = re.search(r"<extension>(.*?)</extension>", blk, re.S)
        if name and path and ext:
            exts = [e.strip().lower() for e in ext.group(1).split() if e.strip()]
            systems.append((name.group(1), path.group(1), exts))
    return systems


def main():
    sys_xml = sys.argv[1] if len(sys.argv) > 1 else (
        "/mnt/mmc/Roms/APPS/esde/resources/systems/linuxarm/es_systems.xml")

    created = []
    merged = []
    empty = 0
    for name, folder, exts in parse_systems(sys_xml):
        romdir = os.path.join(ROMROOT, folder)
        if not os.path.isdir(romdir):
            continue
        outfile = os.path.join(OUTROOT, name, "gamelist.xml")

        # 已有 gamelist:读入现有条目(path → 整条保留)
        existing_paths = set()
        root = ET.Element("gameList")
        if os.path.exists(outfile):
            try:
                old = ET.parse(outfile).getroot()
                for g in old.findall("game"):
                    p = g.find("path")
                    if p is not None and p.text:
                        existing_paths.add(p.text)
                        root.append(g)
            except ET.ParseError:
                pass  # 损坏的 gamelist 视为不存在,重建

        games = []
        for fn in sorted(os.listdir(romdir)):
            full = os.path.join(romdir, fn)
            if not os.path.isfile(full):
                continue
            if os.path.splitext(fn)[1].lower() in exts:
                rel = "./" + fn
                if rel not in existing_paths:
                    games.append((rel, fn))

        if not games:
            if not existing_paths:
                empty += 1
                continue
            else:
                merged.append((name, 0))
                continue

        for rel, fn in games:
            g = ET.SubElement(root, "game")
            ET.SubElement(g, "path").text = rel
            ET.SubElement(g, "name").text = os.path.splitext(fn)[0]

        os.makedirs(os.path.dirname(outfile), exist_ok=True)
        ET.ElementTree(root).write(outfile, encoding="utf-8",
                                   xml_declaration=True)
        if existing_paths:
            merged.append((name, len(games)))
        else:
            created.append((name, len(games)))

    print(f"新建: {len(created)} 个系统")
    for name, n in created:
        print(f"  {name}: {n} 个游戏")
    if merged:
        print(f"合并(保留元数据,追加新游戏): {len(merged)} 个系统")
        for name, n in merged:
            print(f"  {name}: +{n}")
    print(f"无匹配游戏: {empty} 个系统")


if __name__ == "__main__":
    main()
