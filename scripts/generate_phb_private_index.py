#!/usr/bin/env python3
"""Generate a private, local-only PHB 2024 content index package.

The generated file is meant for the user's own server import flow. It stores
outline titles, page numbers, paths, and lightweight structured metadata only.
It deliberately does not extract or redistribute rules text.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

try:
    from pypdf import PdfReader
except ModuleNotFoundError as exc:
    raise SystemExit(
        "Missing dependency: pypdf. Install it with `python -m pip install pypdf`."
    ) from exc


CLASS_EN_NAMES = {
    "Barbarian",
    "Bard",
    "Cleric",
    "Druid",
    "Fighter",
    "Monk",
    "Paladin",
    "Ranger",
    "Rogue",
    "Sorcerer",
    "Warlock",
    "Wizard",
}

SPELL_LEVELS = {
    "戏法（零环）": 0,
    "一环": 1,
    "二环": 2,
    "三环": 3,
    "四环": 4,
    "五环": 5,
    "六环": 6,
    "七环": 7,
    "八环": 8,
    "九环": 9,
}

FEAT_CATEGORIES = {
    "起源专长Origin Feats": "origin",
    "通用专长General Feats": "general",
    "战斗风格专长Fighting Style Feats": "fighting-style",
    "传奇恩惠专长Epic Boon Feats": "epic-boon",
}

EQUIPMENT_INDEX_TITLES = {
    "钱币Coins",
    "武器Weapons",
    "武器表Weapons",
    "护甲Armor",
    "护甲表Armor",
    "工具Tools",
    "工匠工具Artisan's Tools",
    "其他工具Other Tools",
    "冒险装备Adventuring Gear",
    "坐骑与载具Mounts and Vehicles",
    "服务Services",
    "魔法物品Magic Items",
    "制作装备Crafting Equipment",
}


@dataclass(frozen=True)
class OutlineEntry:
    title: str
    page: int | None
    path: tuple[str, ...]
    depth: int


def flatten_outline(reader: PdfReader) -> list[OutlineEntry]:
    entries: list[OutlineEntry] = []

    def walk(items: Iterable[object], path: tuple[str, ...], depth: int) -> None:
        last_title: str | None = None
        for item in items:
            if isinstance(item, list):
                child_path = path + ((last_title,) if last_title else ())
                walk(item, child_path, depth + 1)
                continue

            title = getattr(item, "title", str(item)).strip()
            try:
                page = reader.get_destination_page_number(item) + 1
            except Exception:
                page = None
            entries.append(OutlineEntry(title=title, page=page, path=path, depth=depth))
            last_title = title

    walk(reader.outline, (), 0)
    return entries


def split_bilingual_title(title: str) -> tuple[str, str | None]:
    match = re.match(r"^(.+?)([A-Za-z][A-Za-z0-9'’:/.,() -]+)$", title)
    if not match:
        return title.strip(), None
    zh_name = match.group(1).strip()
    en_name = match.group(2).strip()
    return zh_name, en_name


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or "phb-index-item"


def entry_name(zh_name: str, en_name: str | None) -> str:
    return f"{zh_name} / {en_name}" if en_name else zh_name


def has_parent(entry: OutlineEntry, parent_title: str) -> bool:
    return parent_title in entry.path


def nearest_parent(entry: OutlineEntry, candidates: dict[str, object]) -> str | None:
    for title in reversed(entry.path):
        if title in candidates:
            return title
    return None


def classify(entry: OutlineEntry) -> tuple[str, dict[str, object], list[str]] | None:
    zh_name, en_name = split_bilingual_title(entry.title)
    base_structured: dict[str, object] = {
        "page": entry.page,
        "outlinePath": list(entry.path),
        "zhName": zh_name,
    }
    if en_name:
        base_structured["enName"] = en_name

    if has_parent(entry, "第三章：角色职业") and en_name in CLASS_EN_NAMES:
        return "class", base_structured, ["private-phb-2024-index", "class"]

    if has_parent(entry, "背景详述Background Descriptions") and en_name:
        return "background", base_structured, ["private-phb-2024-index", "background"]

    if has_parent(entry, "种族详述Species Descriptions") and en_name:
        return "species", base_structured, ["private-phb-2024-index", "species"]

    feat_parent = nearest_parent(entry, FEAT_CATEGORIES)
    if feat_parent and en_name:
        base_structured["category"] = FEAT_CATEGORIES[feat_parent]
        return "feat", base_structured, ["private-phb-2024-index", "feat"]

    spell_level_parent = nearest_parent(entry, SPELL_LEVELS)
    if spell_level_parent and en_name:
        base_structured["level"] = SPELL_LEVELS[spell_level_parent]
        return "spell", base_structured, ["private-phb-2024-index", "spell"]

    if has_parent(entry, "第六章：装备") and entry.title in EQUIPMENT_INDEX_TITLES:
        base_structured["indexKind"] = "equipment-section"
        return "equipment", base_structured, ["private-phb-2024-index", "equipment-index"]

    return None


def build_package(pdf_path: Path) -> dict[str, object]:
    reader = PdfReader(str(pdf_path))
    items: list[dict[str, object]] = []
    seen_slugs: set[str] = set()

    for entry in flatten_outline(reader):
        classified = classify(entry)
        if classified is None:
            continue

        item_type, structured, tags = classified
        zh_name = str(structured["zhName"])
        en_name = structured.get("enName")
        display_name = entry_name(zh_name, str(en_name) if en_name else None)
        slug_source = str(en_name or zh_name)
        slug = slugify(f"{item_type}-{slug_source}")
        if slug in seen_slugs:
            suffix = 2
            next_slug = f"{slug}-{suffix}"
            while next_slug in seen_slugs:
                suffix += 1
                next_slug = f"{slug}-{suffix}"
            slug = next_slug
        seen_slugs.add(slug)

        items.append(
            {
                "type": item_type,
                "slug": slug,
                "name": display_name,
                "description": "",
                "structured": structured,
                "tags": tags,
                "sourceLabel": "Private PHB 2024 PDF Index",
            }
        )

    return {
        "name": "Private PHB 2024 Index Draft",
        "version": "0.1.0-private",
        "schemaVersion": 1,
        "locale": "zh-CN",
        "copyrightNotice": (
            "Private local index generated from a user-supplied PDF. "
            "Do not commit or redistribute."
        ),
        "sourcePdf": str(pdf_path),
        "items": items,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf", type=Path, help="Path to the local PHB 2024 PDF")
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("private-imports/phb-2024-index-draft.content.private.json"),
        help="Private content package output path",
    )
    args = parser.parse_args()

    if not args.pdf.exists():
        raise SystemExit(f"PDF not found: {args.pdf}")

    package = build_package(args.pdf)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(package, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    counts: dict[str, int] = {}
    for item in package["items"]:
        item_type = str(item["type"])
        counts[item_type] = counts.get(item_type, 0) + 1

    print(f"Wrote {len(package['items'])} private index items to {args.out}")
    print(json.dumps(counts, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
