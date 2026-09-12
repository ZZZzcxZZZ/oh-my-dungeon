#!/usr/bin/env python3
"""Extract private Monster Manual stat blocks into content and character Markdown.

The source book remains user-provided under private-imports/. This script is
safe to commit because it contains parsing logic and no commercial text.
"""
from __future__ import annotations

import json
import hashlib
import base64
import re
import shutil
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from bs4 import BeautifulSoup, NavigableString, Tag

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_ROOT = REPO_ROOT / "private-imports" / "chm-extract" / "怪物图鉴2025"
OUT_DIR = REPO_ROOT / "private-imports" / "mm-2024-v1"
BUNDLE_PATH = REPO_ROOT / "private-imports" / "mm-2024-v1-bundle.json"
PACKAGE_ID = "private-mm"

ABILITY_KEYS = {
    "力量": "str",
    "敏捷": "dex",
    "体质": "con",
    "智力": "int",
    "感知": "wis",
    "魅力": "cha",
}
SIZE_KEYS = {
    "微型": "tiny",
    "小型": "small",
    "中型": "medium",
    "大型": "large",
    "巨型": "huge",
    "超巨型": "gargantuan",
    "tiny": "tiny",
    "small": "small",
    "medium": "medium",
    "large": "large",
    "huge": "huge",
    "gargantuan": "gargantuan",
}
SIZE_LABELS = {
    "tiny": "微型",
    "small": "小型",
    "medium": "中型",
    "large": "大型",
    "huge": "巨型",
    "gargantuan": "超巨型",
}
SPEED_LABELS = {
    "walk": "步行",
    "fly": "飞行",
    "swim": "游泳",
    "climb": "攀爬",
    "burrow": "掘穴",
}
CREATURE_TYPE_KEYS = {
    "异怪": "aberration",
    "野兽": "beast",
    "天族": "celestial",
    "构装": "construct",
    "构装体": "construct",
    "龙": "dragon",
    "元素": "elemental",
    "妖精": "fey",
    "邪魔": "fiend",
    "巨人": "giant",
    "人形": "humanoid",
    "类人": "humanoid",
    "怪兽": "monstrosity",
    "泥怪": "ooze",
    "植物": "plant",
    "亡灵": "undead",
}
MONSTER_SECTION_KEYS = {
    "特质": "traits",
    "特性": "traits",
    "动作": "actions",
    "附赠动作": "bonusActions",
    "反应": "reactions",
    "传奇动作": "legendaryActions",
    "施法": "spellcasting",
}
MONSTER_GROUP_LABELS = {
    "traits": "特性",
    "actions": "动作",
    "bonusActions": "附赠动作",
    "reactions": "反应",
    "legendaryActions": "传奇动作",
    "spellcasting": "施法",
}


@dataclass
class MonsterRecord:
    name: str
    english_name: str
    source_path: str
    size: str = ""
    creature_type: str = ""
    alignment: str = ""
    armor_class: int = 10
    initiative_bonus: int = 0
    hit_points: int = 0
    hit_point_formula: str = ""
    speed: dict[str, int] = field(default_factory=dict)
    abilities: dict[str, int] = field(default_factory=dict)
    challenge_rating: str = ""
    proficiency_bonus: int = 0
    senses: str = ""
    languages: str = ""
    defenses: dict[str, str] = field(default_factory=dict)
    description: str = ""
    sections: dict[str, str] = field(default_factory=dict)
    manual_review: list[dict[str, str]] = field(default_factory=list)


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


def extract_overview_description(html: str) -> str:
    """Read prose from a family overview page, excluding labels and quotes."""
    soup = BeautifulSoup(html, "html.parser")
    paragraphs: list[str] = []
    for paragraph in soup.find_all("p"):
        classes = set(paragraph.get("class") or [])
        if "sum" in classes:
            continue
        if any(
            "little-paper" in set(parent.get("class") or [])
            for parent in paragraph.parents
            if isinstance(parent, Tag)
        ):
            continue
        text = clean_text(paragraph.get_text(" ", strip=True))
        if text:
            paragraphs.append(text)
    return "\n\n".join(paragraphs)


def split_name(value: str) -> tuple[str, str]:
    text = clean_text(value).rstrip("。")
    boundary = re.search(r"(?<=[\u3400-\u9fff）)])\s*(?=[A-Za-z])", text)
    if not boundary:
        return text, ""
    return text[:boundary.start()].strip(), text[boundary.end():].strip()


def slugify(name: str, english_name: str = "") -> str:
    value = (english_name or name).lower().strip()
    value = re.sub(r"[^a-z0-9\u4e00-\u9fff]+", "-", value).strip("-")
    return value[:80] or "monster"


def parse_monsters(html: str, *, source_path: str) -> list[MonsterRecord]:
    soup = BeautifulSoup(html, "html.parser")
    records: list[MonsterRecord] = []
    for heading in soup.find_all("h5"):
        container = heading.parent
        if not isinstance(container, Tag):
            continue
        tables = _siblings_until_next_h5(heading, "table")
        if len(tables) < 2:
            continue
        name, english_name = split_name(heading.get_text(" ", strip=True))
        descriptor = heading.find_next_sibling(
            lambda tag: isinstance(tag, Tag)
            and tag.name == "div"
            and "sub-line" in (tag.get("class") or [])
        )
        record = MonsterRecord(
            name=name,
            english_name=english_name,
            source_path=source_path,
        )
        if descriptor is not None:
            _parse_descriptor(record, clean_text(descriptor.get_text(" ")))
        _parse_primary_stats(record, tables[0])
        ability_table = next(
            (
                table
                for table in tables
                if "stat-abilities" in (table.get("class") or [])
            ),
            None,
        )
        if ability_table is not None:
            _parse_abilities(record, ability_table)
        for table in tables:
            if table is tables[0] or table is ability_table:
                continue
            _parse_secondary_stats(record, table)
        record.sections = _parse_sections(heading, record)
        if record.senses or record.languages:
            lines = []
            if record.senses:
                lines.append(f"- 感官：{record.senses}")
            if record.languages:
                lines.append(f"- 语言：{record.languages}")
            record.sections = {
                "感官与语言": "\n".join(lines),
                **record.sections,
            }
        records.append(record)
    return records


def _siblings_until_next_h5(heading: Tag, name: str) -> list[Tag]:
    result: list[Tag] = []
    for sibling in heading.next_siblings:
        if isinstance(sibling, Tag) and sibling.name == "h5":
            break
        if isinstance(sibling, Tag) and sibling.name == name:
            result.append(sibling)
    return result


def _parse_descriptor(record: MonsterRecord, descriptor: str) -> None:
    identity, _, alignment = descriptor.partition("，")
    for label, value in SIZE_KEYS.items():
        if identity.lower().startswith(label.lower()):
            record.size = value
            record.creature_type = identity[len(label):].strip()
            break
    if not record.creature_type:
        record.creature_type = identity
    record.alignment = alignment.strip()


def _parse_primary_stats(record: MonsterRecord, table: Tag) -> None:
    for strong in table.find_all("strong"):
        label = clean_text(strong.get_text())
        value = clean_text(strong.parent.get_text(" ", strip=True))
        value = value[len(label):].strip() if value.startswith(label) else value
        if label == "AC":
            record.armor_class = _first_int(value, 10)
        elif label == "先攻":
            record.initiative_bonus = _signed_int(value, 0)
        elif label == "HP":
            record.hit_points = _first_int(value, 0)
            formula = re.search(r"[（(]([^）)]+)[）)]", value)
            if formula:
                record.hit_point_formula = formula.group(1).strip()
        elif label == "速度":
            record.speed = _parse_speed(value)


def _parse_abilities(record: MonsterRecord, table: Tag) -> None:
    for strong in table.find_all("strong"):
        key = ABILITY_KEYS.get(clean_text(strong.get_text()))
        if key is None:
            continue
        cell = strong.find_parent("td")
        score_cell = cell.find_next_sibling("td") if cell is not None else None
        if score_cell is not None:
            record.abilities[key] = _first_int(score_cell.get_text(), 10)


def _parse_secondary_stats(record: MonsterRecord, table: Tag) -> None:
    for strong in table.find_all("strong"):
        label = clean_text(strong.get_text())
        value = clean_text(strong.parent.get_text(" ", strip=True))
        value = value[len(label):].strip() if value.startswith(label) else value
        if label == "CR":
            record.challenge_rating = value.split("（", 1)[0].split("(", 1)[0].strip()
            pb = re.search(r"PB\s*\+?(\d+)", value, re.IGNORECASE)
            if pb:
                record.proficiency_bonus = int(pb.group(1))
        elif label == "感官":
            record.senses = value
        elif label == "语言":
            record.languages = value
        elif value:
            record.defenses[label] = value


def _parse_sections(heading: Tag, record: MonsterRecord) -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    description: list[str] = []
    current = ""
    for sibling in heading.next_siblings:
        if not isinstance(sibling, Tag):
            continue
        if sibling.name == "h5":
            break
        if sibling.name == "h6":
            current = _section_name(sibling.get_text(" ", strip=True))
            sections.setdefault(current, [])
            continue
        if sibling.name == "p":
            text = clean_text(sibling.get_text(" ", strip=True))
            if not text:
                continue
            if not current:
                if sibling.find("strong") is None:
                    description.append(text)
                continue
            titled_blocks = _parse_titled_blocks(sibling)
            if titled_blocks:
                for title, entry_description in titled_blocks:
                    sections[current].append(
                        (
                            f"### {title}\n\n{entry_description}"
                            if entry_description
                            else f"### {title}"
                        )
                    )
            else:
                sections[current].append(text)
    record.description = "\n\n".join(description).strip()
    parsed = {
        title: "\n\n".join(blocks)
        for title, blocks in sections.items()
        if title and blocks
    }
    for title, text in parsed.items():
        if title not in MONSTER_SECTION_KEYS and title != "感官与语言":
            record.manual_review.append(
                {
                    "reason": "unclassified-section",
                    "section": title,
                    "excerpt": text[:240],
                }
            )
    return parsed


def _parse_titled_blocks(paragraph: Tag) -> list[tuple[str, str]]:
    """Split compact stat-block paragraphs that contain multiple bold entries."""
    blocks: list[tuple[str, str]] = []
    for strong in paragraph.find_all("strong"):
        title, _ = split_name(
            clean_text(strong.get_text(" ", strip=True)).rstrip("。")
        )
        if not title:
            continue
        description_parts: list[str] = []
        for node in strong.next_elements:
            if isinstance(node, Tag) and node.name == "strong":
                break
            if isinstance(node, NavigableString):
                if paragraph not in node.parents:
                    break
                if strong in node.parents:
                    continue
                description_parts.append(str(node))
        blocks.append((title, clean_text(" ".join(description_parts))))
    return blocks


def _section_name(value: str) -> str:
    chinese = re.match(r"^([\u4e00-\u9fff]+)", clean_text(value))
    return chinese.group(1) if chinese else clean_text(value)


def _parse_speed(value: str) -> dict[str, int]:
    result: dict[str, int] = {}
    labels = {
        "飞行": "fly",
        "游泳": "swim",
        "攀爬": "climb",
        "掘穴": "burrow",
    }
    for label, key in labels.items():
        match = re.search(rf"{label}(?:速度)?\s*(\d+)", value)
        if match:
            result[key] = int(match.group(1))
    walk = re.match(r"\s*(\d+)", value)
    if walk:
        result["walk"] = int(walk.group(1))
    return result


def _first_int(value: str, fallback: int) -> int:
    match = re.search(r"\d+", value)
    return int(match.group()) if match else fallback


def _signed_int(value: str, fallback: int) -> int:
    match = re.search(r"[+-]?\d+", value)
    return int(match.group()) if match else fallback


def content_entry(record: MonsterRecord, slug: str) -> dict[str, Any]:
    fields = {
        "AC": str(record.armor_class),
        "HP": (
            f"{record.hit_points} ({record.hit_point_formula})"
            if record.hit_point_formula
            else str(record.hit_points)
        ),
        "速度": ", ".join(
            f"{SPEED_LABELS.get(key, key)} {value}"
            for key, value in record.speed.items()
        ),
        "CR": record.challenge_rating,
    }
    body: list[dict[str, Any]] = [
        {"type": "statBlock", "fields": {k: v for k, v in fields.items() if v}},
    ]
    if record.description:
        body.append({"type": "paragraph", "text": record.description})
    for title, text in record.sections.items():
        body.append({"type": "heading", "level": 2, "text": title})
        body.extend(_content_blocks(text))
    groups = _structured_groups(record.sections)
    creature_type = _canonical_creature_type(record.creature_type)
    senses = _split_list(record.senses)
    languages = _split_list(record.languages)
    challenge = {
        "rating": record.challenge_rating,
        "proficiencyBonus": record.proficiency_bonus,
    }
    character = {
        "kind": "monster",
        "templateRef": f"{PACKAGE_ID}:monster/{slug}",
        "size": record.size,
        "creatureType": creature_type,
        "alignment": record.alignment,
        "armorClass": record.armor_class,
        "initiativeBonus": record.initiative_bonus,
        "hitPoints": {
            "maximum": record.hit_points,
            "formula": record.hit_point_formula,
        },
        "speed": record.speed,
        "abilities": record.abilities,
        "challengeRating": record.challenge_rating,
        "proficiencyBonus": record.proficiency_bonus,
        "sections": record.sections,
        "description": record.description,
        "senses": senses,
        "languages": languages,
        "challenge": challenge,
        **groups,
    }
    return {
        "id": f"{PACKAGE_ID}:monster/{slug}",
        "type": "monster",
        "slug": slug,
        "name": record.name,
        "aliases": [record.english_name] if record.english_name else [],
        "summary": _descriptor(record),
        "body": body,
        "structured": {
            "challengeRating": record.challenge_rating,
            "type": creature_type,
            "size": record.size,
            "alignment": record.alignment,
            "classification": {
                "creatureType": creature_type,
                "subtypes": [],
                "tags": [record.creature_type] if record.creature_type else [],
            },
            "characterTemplate": character,
        },
        "tags": [
            value
            for value in (
                "monster",
                f"cr:{record.challenge_rating}" if record.challenge_rating else "",
                f"type:{creature_type}" if creature_type != "unknown" else "",
            )
            if value
        ],
        "source": {"label": "私有怪物图鉴"},
        "revision": 1,
    }


def _canonical_creature_type(value: str) -> str:
    normalized = clean_text(value)
    for label, creature_type in CREATURE_TYPE_KEYS.items():
        if label in normalized:
            return creature_type
    return "unknown"


def _structured_groups(
    sections: dict[str, str],
) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = {
        key: [] for key in MONSTER_GROUP_LABELS
    }
    for section, group in MONSTER_SECTION_KEYS.items():
        text = sections.get(section, "")
        chunks = re.split(r"(?m)^###\s+", text)
        for chunk in chunks[1:]:
            name, _, description = chunk.partition("\n")
            name = name.strip()
            description = description.strip()
            if not name:
                continue
            action: dict[str, Any] = {
                "id": slugify(name),
                "name": name,
                "description": description,
            }
            attack = re.search(r"命中\s*[：:]\s*([+-]?\d+)", description)
            if attack:
                action["attack"] = {"bonus": int(attack.group(1))}
            damage = re.search(r"(\d+d\d+(?:\s*[+-]\s*\d+)?)", description)
            if damage:
                action["damage"] = {
                    "expression": re.sub(r"\s+", "", damage.group(1)),
                }
            result[group].append(action)
    return result


def build_manual_review(records: list[MonsterRecord]) -> list[dict[str, str]]:
    review: list[dict[str, str]] = []
    for record in records:
        identity = {
            "name": record.name,
            "sourcePath": record.source_path,
        }
        if _canonical_creature_type(record.creature_type) == "unknown":
            review.append(
                {
                    **identity,
                    "reason": "unknown-creature-type",
                    "value": record.creature_type,
                }
            )
        review.extend({**identity, **item} for item in record.manual_review)
    return review


def _split_list(value: str) -> list[str]:
    return [
        item.strip()
        for item in re.split(r"[；;]", value)
        if item.strip()
    ]


def _content_blocks(text: str) -> list[dict[str, Any]]:
    chunks = re.split(r"(?m)^###\s+", text)
    blocks: list[dict[str, Any]] = []
    intro = chunks[0].strip()
    if intro:
        blocks.append({"type": "paragraph", "text": intro})
    for chunk in chunks[1:]:
        heading, _, description = chunk.partition("\n")
        blocks.append({"type": "heading", "level": 3, "text": heading.strip()})
        description = description.strip()
        if description:
            blocks.append({"type": "paragraph", "text": description})
    return blocks


def character_markdown(record: MonsterRecord, slug: str | None = None) -> str:
    slug = slug or slugify(record.name, record.english_name)
    content_hash = hashlib.sha256(
        json.dumps(
            {
                "name": record.name,
                "kind": "monster",
                "templateRef": f"{PACKAGE_ID}:monster/{slug}",
                "armorClass": record.armor_class,
                "hitPoints": record.hit_points,
                "abilities": record.abilities,
                "sections": record.sections,
            },
            ensure_ascii=False,
            sort_keys=True,
        ).encode("utf-8")
    ).hexdigest()
    lines = [
        "---",
        "format: dnd-table-character/v2",
        "kind: monster",
        f"name: {_yaml(record.name)}",
        "system: dnd5e-2024",
        f"templateRef: {_yaml(f'{PACKAGE_ID}:monster/{slug}')}",
        "revision: 1",
        f"contentHash: sha256:{content_hash}",
        f"generatedAt: {datetime.now(timezone.utc).isoformat()}",
        f"size: {_yaml(record.size)}",
        f"creatureType: {_yaml(record.creature_type)}",
        f"alignment: {_yaml(record.alignment)}",
        f"armorClass: {record.armor_class}",
        "hitPoints:",
        f"  current: {record.hit_points}",
        f"  maximum: {record.hit_points}",
        f"  formula: {_yaml(record.hit_point_formula)}",
        "speed:",
        f"  walk: {record.speed.get('walk', 0)}",
        "abilities:",
        *[
            f"  {key}: {record.abilities.get(key, 10)}"
            for key in ("str", "dex", "con", "int", "wis", "cha")
        ],
        f"initiativeBonus: {record.initiative_bonus}",
        f"challengeRating: {_yaml(record.challenge_rating)}",
        f"proficiencyBonus: {record.proficiency_bonus}",
        "---",
        "",
        f"# {record.name}",
        "",
        _descriptor(record),
        "",
    ]
    if record.description:
        lines.extend(["## 描述", "", record.description, ""])
    groups = _structured_groups(record.sections)
    for group, title in MONSTER_GROUP_LABELS.items():
        entries = groups[group]
        if not entries:
            continue
        lines.extend([f"## {title}", ""])
        for entry in entries:
            lines.extend(_monster_markdown_entry(entry))
    for title, text in record.sections.items():
        if title in MONSTER_SECTION_KEYS or title == "感官与语言":
            continue
        lines.extend([f"## {title}", "", text, ""])
    monster_metadata = {
        "senses": _split_list(record.senses),
        "languages": _split_list(record.languages),
        "challenge": {
            "rating": record.challenge_rating,
            "proficiencyBonus": record.proficiency_bonus,
        },
    }
    lines.extend(["## 怪物资料", ""])
    if monster_metadata["senses"]:
        lines.append(f"- **感官：** {'、'.join(monster_metadata['senses'])}")
    if monster_metadata["languages"]:
        lines.append(f"- **语言：** {'、'.join(monster_metadata['languages'])}")
    if record.challenge_rating:
        lines.append(
            f"- **挑战等级：** {record.challenge_rating}"
            f"（熟练加值 +{record.proficiency_bonus}）"
        )
    metadata = base64.urlsafe_b64encode(
        json.dumps(
            monster_metadata,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
    ).decode("ascii")
    lines.extend(["", f"<!-- dnd:monster-data={metadata} -->", ""])
    return "\n".join(lines).rstrip() + "\n"


def _monster_markdown_entry(entry: dict[str, Any]) -> list[str]:
    lines = [f"### {entry['name']}", "", entry.get("description", ""), ""]
    attack = entry.get("attack", {})
    damage = entry.get("damage", {})
    if "bonus" in attack:
        bonus = attack["bonus"]
        lines.append(f"**命中加值：** {'+' if bonus >= 0 else ''}{bonus}")
    if damage.get("expression"):
        damage_type = f" {damage['type']}" if damage.get("type") else ""
        lines.append(f"**伤害：** `{damage['expression']}`{damage_type}")
    metadata = base64.urlsafe_b64encode(
        json.dumps(entry, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    ).decode("ascii")
    lines.extend(["", f"<!-- dnd:monster-entry={metadata} -->", ""])
    return lines


def _descriptor(record: MonsterRecord) -> str:
    size = SIZE_LABELS.get(record.size, record.size)
    identity = " ".join(value for value in (size, record.creature_type) if value)
    return "，".join(value for value in (identity, record.alignment) if value)


def _yaml(value: object) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def extract_all() -> list[MonsterRecord]:
    records: list[MonsterRecord] = []
    overview_by_directory: dict[Path, str] = {}
    for path in sorted(SOURCE_ROOT.rglob("*.htm")):
        html = read_html(path)
        parsed = parse_monsters(html, source_path=str(path))
        records.extend(parsed)
        if not parsed and path.stem.endswith("总"):
            description = extract_overview_description(html)
            if description:
                overview_by_directory[path.parent.resolve()] = description
    for record in records:
        if record.description:
            continue
        source_directory = Path(record.source_path).parent.resolve()
        record.description = overview_by_directory.get(source_directory, "")
    return records


def write_outputs(records: list[MonsterRecord]) -> None:
    resolved = OUT_DIR.resolve()
    private_root = (REPO_ROOT / "private-imports").resolve()
    if private_root not in resolved.parents:
        raise RuntimeError(f"refusing to replace output outside private imports: {resolved}")
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    entries_dir = OUT_DIR / "entries"
    characters_dir = OUT_DIR / "characters"
    entries_dir.mkdir(parents=True)
    characters_dir.mkdir(parents=True)

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
        (characters_dir / f"{slug}.md").write_text(
            character_markdown(record, slug),
            encoding="utf-8",
        )
    manifest = {
        "formatVersion": 3,
        "id": PACKAGE_ID,
        "name": "私有怪物图鉴模板",
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
                "withChallengeRating": sum(bool(item.challenge_rating) for item in records),
                "withCompleteAbilities": sum(len(item.abilities) == 6 for item in records),
                "manualReviewCount": len(build_manual_review(records)),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    (OUT_DIR / "manual-review.json").write_text(
        json.dumps(build_manual_review(records), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    if not SOURCE_ROOT.exists():
        raise SystemExit(f"source not found: {SOURCE_ROOT}")
    records = extract_all()
    write_outputs(records)
    print(f"Extracted {len(records)} monster stat blocks to {OUT_DIR}")


if __name__ == "__main__":
    main()
