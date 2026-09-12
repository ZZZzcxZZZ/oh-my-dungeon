#!/usr/bin/env python3
"""Extract private DMG 2024 magic-item templates into a v2 content package."""
from __future__ import annotations

import json
import re
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from bs4 import BeautifulSoup, Tag

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_ROOT = (
    REPO_ROOT
    / "private-imports"
    / "chm-extract"
    / "城主指南2024"
    / "7.宝藏"
    / "魔法物品详述"
)
OUT_DIR = REPO_ROOT / "private-imports" / "dmg-2024-items-v1"
BUNDLE_PATH = REPO_ROOT / "private-imports" / "dmg-2024-items-v1-bundle.json"
PACKAGE_ID = "private-dmg-2024"


@dataclass
class MagicItemRecord:
    name: str
    english_name: str
    category: str
    rarity: str
    attunement: bool
    description: str
    source_path: str


def read_html(path: Path) -> str:
    raw = path.read_bytes()
    for encoding in ("gb2312", "gbk", "gb18030", "utf-8"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("gb18030", errors="replace")


def clean_text(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def split_name(value: str) -> tuple[str, str]:
    text = clean_text(value)
    match = re.match(r"^(.+?)([A-Za-z][A-Za-z '\-]+)$", text)
    return (
        (match.group(1).strip(), match.group(2).strip())
        if match
        else (text, "")
    )


def slugify(name: str, english_name: str = "") -> str:
    value = (english_name or name).lower().strip()
    value = re.sub(r"[^a-z0-9\u4e00-\u9fff]+", "-", value).strip("-")
    return value[:80] or "item"


def parse_magic_items(html: str, *, source_path: str) -> list[MagicItemRecord]:
    soup = BeautifulSoup(html, "html.parser")
    records: list[MagicItemRecord] = []
    for heading in soup.find_all("h6"):
        paragraph = heading.find_next_sibling("p")
        if paragraph is None:
            continue
        name, english_name = split_name(heading.get_text(" ", strip=True))
        em = paragraph.find("em")
        metadata = clean_text(em.get_text(" ", strip=True)) if em else ""
        category, rarity, attunement = _parse_item_metadata(metadata)
        if not category or not rarity:
            continue
        description = clean_text(paragraph.get_text(" ", strip=True))
        if metadata and description.startswith(metadata):
            description = description[len(metadata):].strip()
        records.append(
            MagicItemRecord(
                name=name,
                english_name=english_name,
                category=category,
                rarity=rarity,
                attunement=attunement,
                description=description,
                source_path=source_path,
            )
        )
    return records


def _parse_item_metadata(value: str) -> tuple[str, str, bool]:
    normalized = value.replace("（", "(").replace("）", ")")
    base = normalized.split("(", 1)[0]
    parts = [part.strip() for part in re.split(r"[,，]", base) if part.strip()]
    if len(parts) < 2:
        return "", "", False
    return parts[0], parts[1], "同调" in normalized


def content_entry(record: MagicItemRecord, slug: str) -> dict[str, Any]:
    entry_id = f"{PACKAGE_ID}:item/{slug}"
    return {
        "id": entry_id,
        "type": "item",
        "slug": slug,
        "name": record.name,
        "aliases": [record.english_name] if record.english_name else [],
        "summary": f"{record.category} · {record.rarity}",
        "body": [{"type": "paragraph", "text": record.description}],
        "structured": {
            "category": record.category,
            "rarity": record.rarity,
            "attunement": record.attunement,
            "itemTemplate": {
                "kind": "item",
                "templateRef": entry_id,
                "quantity": 1,
                "equipped": False,
                "attuned": False,
            },
        },
        "tags": [
            "magic-item",
            f"category:{record.category}",
            f"rarity:{record.rarity}",
        ],
        "source": {"label": "城主指南 2024 私有资料"},
        "revision": 1,
    }


def extract_all() -> list[MagicItemRecord]:
    records: list[MagicItemRecord] = []
    for path in sorted(SOURCE_ROOT.rglob("*.htm")):
        records.extend(
            parse_magic_items(read_html(path), source_path=str(path))
        )
    return records


def write_outputs(records: list[MagicItemRecord]) -> None:
    resolved = OUT_DIR.resolve()
    private_root = (REPO_ROOT / "private-imports").resolve()
    if private_root not in resolved.parents:
        raise RuntimeError(f"refusing to replace output outside private imports: {resolved}")
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    entries_dir = OUT_DIR / "entries"
    entries_dir.mkdir(parents=True)
    seen: dict[str, int] = {}
    entries = []
    for record in records:
        base = slugify(record.name, record.english_name)
        count = seen.get(base, 0)
        seen[base] = count + 1
        slug = base if count == 0 else f"{base}-{count + 1}"
        entry = content_entry(record, slug)
        entries.append(entry)
        (entries_dir / f"{slug}.json").write_text(
            json.dumps(entry, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    manifest = {
        "formatVersion": 3,
        "id": PACKAGE_ID,
        "name": "城主指南 2024 私有魔法物品",
        "version": "1.0.0",
        "locale": "zh-CN",
        "system": "dnd5e-2024",
        "entryCount": len(entries),
    }
    (OUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    BUNDLE_PATH.write_text(
        json.dumps({**manifest, "entries": entries}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (OUT_DIR / "extraction-report.json").write_text(
        json.dumps(
            {
                "entryCount": len(entries),
                "attunementCount": sum(item.attunement for item in records),
                "rarities": sorted({item.rarity for item in records}),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def main() -> None:
    if not SOURCE_ROOT.exists():
        raise SystemExit(f"source not found: {SOURCE_ROOT}")
    records = extract_all()
    write_outputs(records)
    print(f"Extracted {len(records)} magic-item templates to {OUT_DIR}")


if __name__ == "__main__":
    main()
