#!/usr/bin/env python3
"""
从已解包的 CHM 提取「玩家手册 2024」内容，生成 v2 资料包。

输出（位于 private-imports/phb-2024-v2/，被 .gitignore 排除）：
- manifest.json          v2 manifest
- entries/*.json         每条目独立文件
- assets/                二进制资源（当前为空）
- extraction-report.json 各类型计数、重复项、断链统计
- unresolved-links.json  无法解析到稳定 entryId 的 HTML 内部链接
- manual-review.json     不确定规则、需要人工复核的条目
- phb-2024-v2.bundle.json 单文件聚合包，供客户端导入测试使用

约束：
- 只处理 玩家手册2024/ 目录
- GB2312 解码 → UTF-8 输出
- HTML DOM 解析（BeautifulSoup），不用正则解析 HTML
- 不提交到 Git，不进入公开测试夹具
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

from bs4 import BeautifulSoup, NavigableString, Tag

# --------------------------------------------------------------------------- #
# 路径配置
# --------------------------------------------------------------------------- #
REPO_ROOT = Path(__file__).resolve().parent.parent
CHM_ROOT = REPO_ROOT / "private-imports" / "chm-extract"
PHB_ROOT = CHM_ROOT / "玩家手册2024"
OUT_DIR = REPO_ROOT / "private-imports" / "phb-2024-v2"
ENTRIES_DIR = OUT_DIR / "entries"
ASSETS_DIR = OUT_DIR / "assets"

PACKAGE_ID = "phb-2024"
PACKAGE_VERSION = "2024.1.1"
SYSTEM = "dnd5e-2024"
LOCALE = "zh-CN"
SOURCE_LABEL = "玩家手册 2024"

FEATURE_NAME_ALIASES = {
    # The class table and the feature heading use different Chinese
    # translations for the same English feature name.
    "奥术化神": "奥术登神",
}

PROGRESSION_PLACEHOLDERS = {"—", "―", "-", "子职特性"}

# 12 个基础职业
CLASS_DIRS = [
    "战士", "法师", "术士", "武僧", "游侠", "游荡者",
    "牧师", "野蛮人", "魔契师", "圣武士", "德鲁伊", "吟游诗人",
]

# 施法职业及其施法属性（写入 classRules.spellcasting.ability；法术位数值只在客户端内置档案）
CASTING_CLASSES = {
    "法师": "int",
    "术士": "cha",
    "牧师": "wis",
    "魔契师": "cha",
    "圣武士": "cha",
    "德鲁伊": "wis",
    "吟游诗人": "cha",
    "游侠": "wis",
}

# --------------------------------------------------------------------------- #
# 全局状态：收集条目、断链、人工复核项
# --------------------------------------------------------------------------- #
ALL_ENTRIES: list[dict[str, Any]] = []
UNRESOLVED_LINKS: list[dict[str, Any]] = []
MANUAL_REVIEW: list[dict[str, Any]] = []
SLUG_SEEN: dict[str, int] = {}  # slug 去重计数
CLASS_ENTRY_SLUGS: dict[str, str] = {}


# --------------------------------------------------------------------------- #
# HTML 读取与文本清洗
# --------------------------------------------------------------------------- #
def read_html(path: Path) -> str:
    raw = path.read_bytes()
    for enc in ("gb2312", "gbk", "gb18030", "utf-8"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("gb18030", errors="replace")


def clean_text(s: str) -> str:
    """去除 HTML 标签、合并空白、解码常见实体。"""
    s = re.sub(r"<[^>]+>", "", s)
    s = (s.replace("&nbsp;", " ")
           .replace("&amp;", "&")
           .replace("&lt;", "<")
           .replace("&gt;", ">")
           .replace("&quot;", '"')
           .replace("&#39;", "'"))
    s = re.sub(r"\s+", " ", s).strip()
    return s


def split_title(raw: str) -> tuple[str, str | None]:
    """分离中文与英文名。"""
    raw = raw.strip()
    for sep in ["｜", "|", "·"]:
        if sep in raw:
            parts = raw.split(sep, 1)
            return parts[0].strip(), parts[1].strip()
    m = re.match(
        r"^([\u4e00-\u9fff\u3000-\u303f·\s]+?)\s*"
        r"([A-Za-z][A-Za-z\s'\-]*?)(?=\s*[\u4e00-\u9fff]|$)",
        raw,
    )
    if m:
        return m.group(1).strip(), m.group(2).strip()
    return raw, None


def slugify(name: str, en_name: str | None = None) -> str:
    base = (en_name or name).lower().strip()
    base = re.sub(r"[^a-z0-9\u4e00-\u9fff\-]", "-", base)
    base = re.sub(r"-+", "-", base).strip("-")
    if not base:
        base = "entry"
    # 限制 slug 长度，防止文件名过长
    if len(base) > 60:
        base = base[:60].rstrip("-")
    # 去重：若 slug 已存在则追加数字后缀
    if base in SLUG_SEEN:
        SLUG_SEEN[base] += 1
        base = f"{base}-{SLUG_SEEN[base]}"
    else:
        SLUG_SEEN[base] = 0
    return base


def split_feature_name(rest: str) -> tuple[str, str]:
    """从 '中文名 EnglishName 描述...' 中分离特性名和英文名。

    支持以下格式：
      - "战斗风格 Fighting Style 描述..."
      - "额外攻击 Extra Attack描述..."（英文名后直接跟描述）
      - "额外攻击（二）Two Extra Attacks 描述..."（中文名含全角括号后缀）
      - "不屈 Indomitable描述..."
    """
    # 提取中文名：连续汉字 + 可选的全角/半角括号后缀
    name_match = re.match(
        r"^([\u4e00-\u9fff]+(?:[（(][^）)]*[）)])?)", rest,
    )
    if not name_match:
        return rest, ""
    feat_name = name_match.group(1)
    remaining = rest[name_match.end():].strip()
    if not remaining:
        return feat_name, ""
    # 从剩余文本提取英文名（以字母开头的词序列）
    en_match = re.match(r"^([A-Za-z][A-Za-z'\- ]*)", remaining)
    if en_match:
        feat_en = en_match.group(1).strip()
        return feat_name, feat_en
    # 无英文名
    return feat_name, ""


def entry_id(type_: str, slug: str) -> str:
    return f"{PACKAGE_ID}:{type_}/{slug}"


# --------------------------------------------------------------------------- #
# HTML → ContentBlock 转换
# --------------------------------------------------------------------------- #
BLOCK_KEYS_V1 = {
    "heading", "paragraph", "list", "table", "quote",
    "callout", "image", "statBlock", "entryLink", "diceExpression",
}


def html_to_blocks(node: Tag) -> list[dict[str, Any]]:
    """把 HTML 节点的子元素转换为安全 ContentBlock 数组。"""
    blocks: list[dict[str, Any]] = []
    for child in node.children:
        if isinstance(child, NavigableString):
            text = str(child).strip()
            if text:
                blocks.append({"type": "paragraph", "text": text})
            continue
        if not isinstance(child, Tag):
            continue
        name = child.name.lower()
        if name in ("script", "style", "meta", "link", "head"):
            continue
        if name in ("h1", "h2", "h3", "h4", "h5", "h6"):
            level = int(name[1])
            text = clean_text(child.get_text())
            if text:
                blocks.append({"type": "heading", "level": level, "text": text})
        elif name == "p":
            text = clean_text(child.get_text())
            if text:
                blocks.append({"type": "paragraph", "text": text})
        elif name in ("ul", "ol"):
            items = [clean_text(li.get_text()) for li in child.find_all("li", recursive=False)]
            items = [i for i in items if i]
            if items:
                blocks.append({
                    "type": "list",
                    "ordered": name == "ol",
                    "items": items,
                })
        elif name == "table":
            blocks.extend(table_to_blocks(child))
        elif name == "blockquote":
            text = clean_text(child.get_text())
            if text:
                blocks.append({"type": "quote", "text": text})
        elif name == "a":
            link_block = anchor_to_link_block(child)
            if link_block:
                blocks.append(link_block)
        elif name == "br":
            continue
        else:
            text = clean_text(child.get_text())
            if text:
                blocks.append({"type": "paragraph", "text": text})
    return blocks


def table_to_blocks(table: Tag) -> list[dict[str, Any]]:
    rows_raw = table.find_all("tr")
    if not rows_raw:
        return []
    headers: list[str] = []
    rows: list[list[str]] = []
    for tr in rows_raw:
        cells = tr.find_all(["td", "th"])
        cell_texts = [clean_text(c.get_text()) for c in cells]
        if not cell_texts:
            continue
        if not headers:
            headers = cell_texts
        else:
            rows.append(cell_texts)
    if not headers:
        return []
    # 确保所有行列数一致
    width = len(headers)
    rows = [r[:width] + [""] * (width - len(r)) for r in rows]
    return [{"type": "table", "headers": headers, "rows": rows}]


def anchor_to_link_block(a: Tag) -> dict[str, Any] | None:
    text = clean_text(a.get_text())
    if not text:
        return None
    href = a.get("href", "")
    if not href:
        return None
    # 尝试解析为包内 entryLink
    target_id = resolve_href_to_entry_id(href)
    if target_id:
        return {"type": "entryLink", "targetId": target_id, "text": text}
    # 无法解析的链接记录到报告
    UNRESOLVED_LINKS.append({
        "href": href,
        "text": text,
        "source": "anchor",
    })
    # 回退为普通段落
    return {"type": "paragraph", "text": text}


def resolve_href_to_entry_id(href: str) -> str | None:
    """把 HTML 内部链接解析为稳定 entryId。当前实现按文件名映射到 slug。"""
    if not href:
        return None
    # 去除锚点
    path = href.split("#")[0]
    if not path:
        return None
    # 外部链接不解析
    if path.startswith(("http://", "https://", "mailto:")):
        return None
    # 按文件名查找条目（简化实现：遍历已有条目匹配 sourcePath）
    fname = Path(path).name
    for entry in ALL_ENTRIES:
        src = entry.get("_sourcePath", "")
        if src and Path(src).name == fname:
            return entry["id"]
    return None


# --------------------------------------------------------------------------- #
# 条目构造工具
# --------------------------------------------------------------------------- #
def make_entry(
    type_: str,
    slug: str,
    name: str,
    body: list[dict[str, Any]],
    *,
    structured: dict[str, Any] | None = None,
    tags: list[str] | None = None,
    aliases: list[str] | None = None,
    summary: str = "",
    rules: dict[str, Any] | None = None,
    relations: list[dict[str, Any]] | None = None,
    source_path: str = "",
) -> dict[str, Any]:
    entry: dict[str, Any] = {
        "id": entry_id(type_, slug),
        "type": type_,
        "slug": slug,
        "name": name,
        "body": body,
        "revision": 1,
        "aliases": aliases or [],
        "summary": summary,
        "structured": structured or {},
        "tags": tags or [],
        "source": {"label": SOURCE_LABEL},
    }
    if rules:
        entry["rules"] = rules
    if relations:
        entry["relations"] = relations
    if source_path:
        entry["_sourcePath"] = source_path
    return entry


def parse_table_rows(soup: BeautifulSoup | Tag) -> list[list[str]]:
    rows: list[list[str]] = []
    for tr in soup.find_all("tr"):
        cells = [clean_text(td.get_text()) for td in tr.find_all(["td", "th"])]
        if cells:
            rows.append(cells)
    return rows


# --------------------------------------------------------------------------- #
# 职业核心特质表提取
# --------------------------------------------------------------------------- #
ABILITY_KEYS = {"力量": "str", "敏捷": "dex", "体质": "con",
                "智力": "int", "感知": "wis", "魅力": "cha"}

# 输出用的规范名清单：18 项技能，逐字采用内置档案
# `apps/client_flutter/assets/rules/dnd5e-2024.rules.json` 的 `skills[].name`
# （顺序仍保持书里第一章的顺序）。客户端角色卡按档案 skills 的名字渲染技能行
# 并据此判定熟练，输出源 PDF 的译名（如「特技」「游说」）会选不中角色卡技能行，
# 导致熟练静默丢失。来源译名与档案译名的差异由 SKILL_NAME_ALIASES 收敛。
ALL_SKILLS = ["杂技", "驯兽", "奥秘", "运动", "欺瞒", "历史", "洞悉", "威吓",
              "调查", "医药", "自然", "察觉", "表演", "说服", "宗教", "巧手",
              "隐匿", "求生"]

# 源文译名 → 档案规范名。只收敛同一技能的不同中文译名，不做模糊匹配。
# 「医疗」是源文里对 Medicine 的另一处译法（法师/圣武士/德鲁伊），档案统一叫
# 「医药」（牧师页源文也写「医药」），必须一并收敛，否则同样选不中角色卡技能行。
SKILL_NAME_ALIASES = {
    "特技": "杂技",
    "游说": "说服",
    "医疗": "医药",
}


def parse_saving_throws(value: str) -> list[str]:
    """'力量与体质' → ['str','con']；顺序按中文在原字符串里出现的先后。"""
    found: list[tuple[int, str]] = []
    for cn, key in ABILITY_KEYS.items():
        position = value.find(cn)
        if position >= 0:
            found.append((position, key))
    found.sort(key=lambda item: item[0])
    return [key for _, key in found]


def parse_skill_choice(value: str) -> dict[str, Any] | None:
    """'选择2项：驯兽、运动、威吓' → {'count':2,'options':[...]}
       '任选3项（见第一章）'      → {'count':3,'options':ALL_SKILLS}

    选项逐项过 SKILL_NAME_ALIASES 收敛到档案规范名；映射后仍不在 ALL_SKILLS
    里的名字不静默保留：记入 MANUAL_REVIEW 并原样输出（不丢数据）。"""
    match = re.search(r"(\d+)\s*项", value)
    if not match:
        return None
    count = int(match.group(1))
    if "见" in value:
        return {"count": count, "options": list(ALL_SKILLS)}
    after = value.split("：", 1)[1] if "：" in value else ""
    options: list[str] = []
    for raw in re.split(r"[、,，]|或", after):
        raw = raw.strip()
        if not raw:
            continue
        mapped = SKILL_NAME_ALIASES.get(raw, raw)
        if mapped not in ALL_SKILLS:
            MANUAL_REVIEW.append({
                "type": "unknown-skill-name",
                "raw": raw,
                "mapped": mapped,
                "reason": "skill name not in canonical archive skill list",
            })
            options.append(raw)
        else:
            options.append(mapped)
    if not options:
        return None
    return {"count": count, "options": options}


def parse_class_core_table(
    soup: BeautifulSoup,
) -> tuple[dict[str, Any], dict[str, str]]:
    """返回 (structured, raw_fields)。

    structured 只承载展示元数据 + classRules（数值事实）；raw_fields 是原始
    「标签 → 文本」字典，供 extract_class 读取技能选择原文。
    """
    raw_fields: dict[str, str] = {}
    for table in soup.find_all("table"):
        text = clean_text(table.get_text())
        if "主要属性" not in text and "生命值骰" not in text:
            continue
        for tr in table.find_all("tr"):
            cells = [clean_text(c.get_text()) for c in tr.find_all(["td", "th"])]
            if len(cells) < 2:
                continue
            label, value = cells[0], cells[1]
            for key, cn in [
                ("primaryAbility", "主要属性"),
                ("hitDie", "生命值骰"),
                ("savingThrows", "豁免熟练"),
                ("skills", "技能熟练"),
                ("weaponProficiency", "武器熟练"),
                ("armorProficiency", "护甲受训"),
                ("spellcasting", "施法属性"),
                ("startingEquipment", "起始装备"),
            ]:
                if cn in label and key not in raw_fields:
                    raw_fields[key] = value
        break

    structured: dict[str, Any] = {}
    for display_key in (
        "primaryAbility",
        "weaponProficiency",
        "armorProficiency",
        "startingEquipment",
    ):
        if display_key in raw_fields:
            structured[display_key] = raw_fields[display_key]

    class_rules: dict[str, Any] = {}
    # '每战士等级D10' → 10；抽不到就整键不写（客户端报 missingCoreField warning）。
    match = re.search(r"[Dd](\d+)", raw_fields.get("hitDie", ""))
    if match:
        class_rules["hitDie"] = int(match.group(1))
    saving_throws = parse_saving_throws(raw_fields.get("savingThrows", ""))
    if saving_throws:
        class_rules["savingThrowAbilities"] = saving_throws
    structured["classRules"] = class_rules
    return structured, raw_fields


SPELL_LEVEL_LABELS = {
    "戏法": 0,
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

# 施法原型（spellcasting.archetype）。值必须与内置档案
# `progressions` 的键完全一致（none/full-caster/half-caster/third-caster/pact）。
# 契约魔法的唯一信号是 archetype == "pact"，mode 仍写 "prepared"。
# 法术位数值只存在于客户端内置档案，提取器不再生成。
ARCHETYPE_BY_CLASS = {
    "bard": "full-caster",
    "cleric": "full-caster",
    "druid": "full-caster",
    "sorcerer": "full-caster",
    "wizard": "full-caster",
    "paladin": "half-caster",
    "ranger": "half-caster",
    "warlock": "pact",
}


def _sparse_table(
    progression: list[dict[str, Any]], key: str
) -> dict[str, int]:
    """把逐级行数组压成稀疏表 {'<等级>': 值}；未解析出的等级不写。"""
    return {
        str(row["level"]): row[key]
        for row in progression
        if row[key] is not None
    }


def parse_spell_selection_table(
    soup: BeautifulSoup,
    *,
    class_slug: str,
    ability: str,
) -> dict[str, Any] | None:
    """Extract the selectable spell limits declared by a class table."""
    for table in soup.find_all("table"):
        rows = parse_table_rows(table)
        if not rows:
            continue
        header = rows[0]
        if not any("等级" in cell for cell in header):
            continue
        maximum_column = next(
            (
                index
                for index, cell in enumerate(header)
                if "准备法术" in cell or "已知法术" in cell
            ),
            None,
        )
        if maximum_column is None:
            continue
        cantrip_column = next(
            (index for index, cell in enumerate(header) if "戏法" in cell),
            None,
        )
        explicit_level_column = next(
            (
                index
                for index, cell in enumerate(header)
                if "法术位环阶" in cell
            ),
            None,
        )
        slot_labels: list[int] = []
        if len(rows) > 1 and not rows[1][0].isdigit():
            slot_labels = [
                SPELL_LEVEL_LABELS[cell]
                for cell in rows[1]
                if cell in SPELL_LEVEL_LABELS and cell != "戏法"
            ]

        progression: list[dict[str, Any]] = []
        for row in rows[1:]:
            if not row or not row[0].isdigit():
                continue
            maximum = _parse_table_int(row, maximum_column)
            if maximum is None:
                continue
            maximum_spell_level = None
            if explicit_level_column is not None:
                maximum_spell_level = SPELL_LEVEL_LABELS.get(
                    row[explicit_level_column]
                    if explicit_level_column < len(row)
                    else ""
                )
            elif slot_labels:
                for offset, spell_level in enumerate(slot_labels):
                    slot_value = _parse_table_int(row, maximum_column + 1 + offset)
                    if slot_value:
                        maximum_spell_level = spell_level
            if maximum_spell_level is None:
                maximum_spell_level = 0

            progression.append({
                "level": int(row[0]),
                "maximumSpellLevel": maximum_spell_level,
                "maximumCantrips": _parse_table_int(row, cantrip_column),
                "maximumLeveledSpells": maximum,
            })

        if progression:
            # 圣武士/游侠的表没有「戏法」列：稀疏表声明 1 级为 0 并向上沿用，
            # 正好等价于 20 级全 0（内置档案写的就是 [0]*20）。
            cantrips = (
                _sparse_table(progression, "maximumCantrips")
                if cantrip_column is not None
                else {}
            )
            if not cantrips:
                cantrips = {"1": 0}
            return {
                "mode": (
                    "prepared"
                    if "准备法术" in header[maximum_column]
                    else "known"
                ),
                "ability": ability,
                "listTags": [f"spell-list:{class_slug}"],
                "archetype": ARCHETYPE_BY_CLASS[class_slug],
                "prepared": _sparse_table(progression, "maximumLeveledSpells"),
                "cantrips": cantrips,
                "maximumSpellLevel": _sparse_table(
                    progression, "maximumSpellLevel"
                ),
            }
    return None


def _parse_table_int(row: list[str], index: int | None) -> int | None:
    if index is None or index >= len(row):
        return None
    value = row[index].strip()
    return int(value) if value.isdigit() else None


# --------------------------------------------------------------------------- #
# 职业特性表 → progression（1-20 级）
# --------------------------------------------------------------------------- #
def parse_progression_table(soup: BeautifulSoup, class_slug: str,
                            feature_slug_map: dict[str, str]) -> list[dict[str, Any]]:
    """解析职业特性表，生成 1-20 级 progression。

    feature_slug_map: { 特性中文名: classFeature slug } 用于建立 grant.entryId。
    """
    progression: list[dict[str, Any]] = []
    for table in soup.find_all("table"):
        rows = parse_table_rows(table)
        if not rows:
            continue
        # 找到含 '等级' 和 '职业特性' 的表
        header_row = rows[0]
        if not any("等级" in h for h in header_row):
            continue
        if not any("特性" in h for h in header_row):
            continue
        # 找到 '职业特性' 列索引
        feat_col = 0
        for i, h in enumerate(header_row):
            if "职业特性" in h or "特性" in h:
                feat_col = i
                break
        for row in rows[1:]:
            if not row or len(row) <= feat_col:
                continue
            level_str = row[0].strip()
            if not level_str.isdigit():
                continue
            level = int(level_str)
            if level < 1 or level > 20:
                continue
            feat_text = row[feat_col] if feat_col < len(row) else ""
            grants: list[dict[str, Any]] = []
            # 拆分特性名（逗号、顿号分隔），匹配到 classFeature
            for feat_name in re.split(r"[，,、]", feat_text):
                feat_name = feat_name.strip()
                if not feat_name or feat_name in PROGRESSION_PLACEHOLDERS:
                    continue
                # 模糊匹配：特性名包含在 feature_slug_map 的键中
                slug = _match_feature_slug(feat_name, feature_slug_map)
                if slug:
                    grants.append({
                        "id": f"level-{level}-{slug}",
                        "kind": "feature",
                        "label": feat_name,
                        "entryId": entry_id("classFeature", slug),
                    })
                else:
                    # 未匹配的特性标记人工复核
                    MANUAL_REVIEW.append({
                        "type": "unmatched-feature",
                        "classSlug": class_slug,
                        "level": level,
                        "featureName": feat_name,
                        "reason": "feature name not found in classFeature slug map",
                    })
            prog_entry: dict[str, Any] = {"levels": [level]}
            if grants:
                prog_entry["grants"] = grants
            progression.append(prog_entry)
        break
    return progression


def _match_feature_slug(feat_name: str, slug_map: dict[str, str]) -> str | None:
    """模糊匹配特性名到 slug。"""
    feat_name = FEATURE_NAME_ALIASES.get(feat_name, feat_name)
    if feat_name in slug_map:
        return slug_map[feat_name]
    # 去除括号注释后匹配
    base = re.sub(r"[（(].*?[）)]", "", feat_name).strip()
    if base in slug_map:
        return slug_map[base]
    # 包含匹配
    for key, slug in slug_map.items():
        if base and (base in key or key in base):
            return slug
    return None


# --------------------------------------------------------------------------- #
# 职业提取
# --------------------------------------------------------------------------- #
def extract_class(cls_name: str) -> tuple[dict[str, Any] | None,
                                          list[dict[str, Any]],
                                          list[dict[str, Any]]]:
    """提取一个职业，返回 (class_entry, classFeature_entries, subclass_entries)。"""
    cls_path = PHB_ROOT / "角色职业" / cls_name / f"{cls_name}.htm"
    if not cls_path.exists():
        return None, [], []

    html = read_html(cls_path)
    soup = BeautifulSoup(html, "html.parser")

    h1 = soup.find("h1")
    if not h1:
        return None, [], []
    name, en_name = split_title(h1.get_text())
    if not name:
        return None, [], []

    slug = slugify(name, en_name)
    CLASS_ENTRY_SLUGS[cls_name] = slug
    structured, raw_fields = parse_class_core_table(soup)
    # 技能熟练原文转成 1 级步骤上的一条 optionType: "skill" choice（见下方 progression）。
    skill_choice = parse_skill_choice(raw_fields.get("skills", ""))
    casting_ability = CASTING_CLASSES.get(cls_name)
    if casting_ability:
        spellcasting = parse_spell_selection_table(
            soup,
            class_slug=slug,
            ability=casting_ability,
        )
        if spellcasting:
            structured.setdefault("classRules", {})["spellcasting"] = spellcasting

    # 提取职业特性段落 "N级：特性名 EnglishName"
    feature_paragraphs: list[tuple[int, str, str, str]] = []  # (level, cn_name, en_name, desc)
    feature_slug_map: dict[str, str] = {}

    for p in soup.find_all("p"):
        ptext = clean_text(p.get_text())
        m = re.match(r"^(\d+)级[：:](.+)", ptext)
        if m:
            level = int(m.group(1))
            rest = m.group(2).strip()
            # 特性名格式: "中文名 EnglishName 描述..."
            # 需要分离特性名和描述，避免 slug 过长
            feat_name, feat_en = split_feature_name(rest)
            desc = ptext
            feature_paragraphs.append((level, feat_name, feat_en, desc))
            # 生成 classFeature slug（同名特性只保留首个 slug，避免覆盖）
            if feat_name not in feature_slug_map:
                feat_slug = slugify(feat_name, feat_en)
                feature_slug_map[feat_name] = feat_slug

    # 生成 classFeature 条目（同名特性只生成一个条目）
    class_feature_entries: list[dict[str, Any]] = []
    seen_feature_names: set[str] = set()
    for level, feat_name, feat_en, desc in feature_paragraphs:
        if feat_name in seen_feature_names:
            continue
        seen_feature_names.add(feat_name)
        feat_slug = feature_slug_map[feat_name]
        body = [{"type": "paragraph", "text": desc}]
        cf_entry = make_entry(
            "classFeature", feat_slug, feat_name, body,
            structured={"level": level, "classSlug": slug},
            tags=[slug, f"level-{level}"],
            summary=f"{level}级 {name} 特性",
            source_path=str(cls_path),
        )
        # 建立 featureOf 关系
        cf_entry["structured"]["featureOf"] = entry_id("class", slug)
        class_feature_entries.append(cf_entry)

    # 生成 progression
    progression = parse_progression_table(soup, slug, feature_slug_map)

    # 技能选择作为一条 choice 挂到 1 级步骤上
    if skill_choice:
        level1 = next((p for p in progression if 1 in p["levels"]), None)
        if level1 is None:
            level1 = {"levels": [1]}
            progression.append(level1)
            progression.sort(key=lambda p: p["levels"][0])
        level1.setdefault("choices", []).append({
            "id": "skill-choice",
            "label": "技能熟练",
            "optionType": "skill",
            "minimum": skill_choice["count"],
            "maximum": skill_choice["count"],
            "options": skill_choice["options"],
        })

    # 3 级子职业选择
    subclass_dir = PHB_ROOT / "角色职业" / cls_name
    subclass_slugs: list[str] = []
    for sub_path in sorted(subclass_dir.glob("*.htm")):
        if sub_path.stem == cls_name:
            continue
        if _is_non_subclass_reference_page(sub_path.stem):
            continue
        subclass_slugs.append(sub_path.stem)

    if subclass_slugs and progression:
        # 找到 level 3 的 progression 项（或创建）
        level3 = next((p for p in progression if 3 in p["levels"]), None)
        if level3 is None:
            level3 = {"levels": [3]}
            progression.append(level3)
            progression.sort(key=lambda p: p["levels"][0])
        level3.setdefault("choices", []).append({
            "id": "subclass-choice",
            "label": f"选择{name}子职业",
            "optionType": "subclass",
            "minimum": 1,
            "maximum": 1,
        })

    # 法术位数值只存在于客户端内置档案；条目只声明类规则与 progression。
    rules: dict[str, Any] = {}
    if progression:
        rules["progression"] = progression

    # 背景描述
    desc_text = ""
    for p in soup.find_all("p"):
        ptext = clean_text(p.get_text())
        if len(ptext) > 80 and "核心特质" not in ptext and "特性表" not in ptext:
            desc_text = ptext
            break

    # 构造 body：核心特质表 + 背景描述 + 特性表
    body_blocks: list[dict[str, Any]] = []
    if desc_text:
        body_blocks.append({"type": "paragraph", "text": desc_text})
    # 把核心特质表加入 body
    for table in soup.find_all("table"):
        ttext = clean_text(table.get_text())
        if "主要属性" in ttext or "生命值骰" in ttext:
            body_blocks.extend(table_to_blocks(table))
            break
    # 特性表
    for table in soup.find_all("table"):
        ttext = clean_text(table.get_text())
        if "等级" in ttext and "职业特性" in ttext:
            body_blocks.extend(table_to_blocks(table))
            break

    class_entry = make_entry(
        "class", slug, name, body_blocks,
        structured=structured,
        tags=[slug],
        aliases=[en_name] if en_name else [],
        summary=f"{name}（{en_name}）" if en_name else name,
        rules=rules if rules else None,
        source_path=str(cls_path),
    )

    # 提取子职业
    subclass_entries: list[dict[str, Any]] = []
    for sub_path in sorted(subclass_dir.glob("*.htm")):
        if sub_path.stem == cls_name:
            continue
        if _is_non_subclass_reference_page(sub_path.stem):
            continue
        sub_result = extract_subclass(sub_path, slug, name)
        if sub_result is None:
            continue
        sub_entry, sub_feature_entries = sub_result
        subclass_entries.append(sub_entry)
        # 子职业特性并入 classFeature 列表，统一写入资料包
        class_feature_entries.extend(sub_feature_entries)

    return class_entry, class_feature_entries, subclass_entries


def _is_non_subclass_reference_page(file_stem: str) -> bool:
    """Skip class-directory reference pages that are not subclasses."""
    return "法术列表" in file_stem or "选项" in file_stem


def extract_subclass(sub_path: Path, parent_class_slug: str,
                     parent_class_name: str
                     ) -> tuple[dict[str, Any], list[dict[str, Any]]] | None:
    """提取子职业，返回 (subclass_entry, subclass_feature_entries)。

    生成的子职业条目具备：
    - relations: [{type: "subclassOf", targetId: <parent class entryId>}]
    - structured.parentClass: 父职业显示名（仅用于 UI 展示，非关系引用）
    - rules.progression: 仅包含子职业实际解锁特性的等级（3/7/10/15/18 等），
      每个等级的 grants 指向 subclass classFeature 条目。

    子职业特性段落格式与父职业一致："N级：特性名 EnglishName 描述..."。
    每个特性生成一条 classFeature 条目，structured.featureOf 指向子职业 entryId，
    与父职业 classFeature 保持一致的结构。
    """
    html = read_html(sub_path)
    soup = BeautifulSoup(html, "html.parser")
    # 子职业标题可能是 h1 或 h2
    h = soup.find(["h1", "h2"])
    if not h:
        return None
    title_text = clean_text(h.get_text())
    name, en_name = split_title(title_text)
    # Some CHM pages put the complete article inside the first heading. The
    # filename is the stable title in that layout; never use page prose as a
    # selectable subclass name.
    if len(name) > 100:
        name = sub_path.stem
        _, en_name = split_title(title_text)
    if not name:
        return None
    slug = slugify(name, en_name)
    subclass_entry_id = entry_id("subclass", slug)

    # 提取子职业特性段落 "N级：特性名 EnglishName"
    feature_paragraphs: list[tuple[int, str, str, str]] = []
    feature_slug_map: dict[str, str] = {}
    for p in soup.find_all("p"):
        ptext = clean_text(p.get_text())
        m = re.match(r"^(\d+)级[：:](.+)", ptext)
        if m:
            level = int(m.group(1))
            rest = m.group(2).strip()
            feat_name, feat_en = split_feature_name(rest)
            desc = ptext
            feature_paragraphs.append((level, feat_name, feat_en, desc))
            if feat_name not in feature_slug_map:
                feat_slug = slugify(feat_name, feat_en)
                feature_slug_map[feat_name] = feat_slug

    # 生成 subclass classFeature 条目（同名特性只生成一个条目）
    subclass_feature_entries: list[dict[str, Any]] = []
    seen_feature_names: set[str] = set()
    for level, feat_name, feat_en, desc in feature_paragraphs:
        if feat_name in seen_feature_names:
            continue
        seen_feature_names.add(feat_name)
        feat_slug = feature_slug_map[feat_name]
        body = [{"type": "paragraph", "text": desc}]
        cf_entry = make_entry(
            "classFeature", feat_slug, feat_name, body,
            structured={
                "level": level,
                "classSlug": parent_class_slug,
                "subclassName": name,
                "featureOf": subclass_entry_id,
            },
            tags=[parent_class_slug, slug, f"level-{level}", "subclass"],
            aliases=[feat_en] if feat_en else [],
            summary=f"{level}级 {name} 特性",
            source_path=str(sub_path),
        )
        subclass_feature_entries.append(cf_entry)

    # 生成 progression：仅包含子职业实际解锁特性的等级
    progression: list[dict[str, Any]] = []
    # 按等级聚合 grants
    level_to_features: dict[int, list[tuple[str, str]]] = {}
    for level, feat_name, _feat_en, _desc in feature_paragraphs:
        level_to_features.setdefault(level, []).append(
            (feat_name, feature_slug_map[feat_name])
        )
    for level in sorted(level_to_features.keys()):
        grants: list[dict[str, Any]] = []
        for feat_name, feat_slug in level_to_features[level]:
            grants.append({
                "id": f"level-{level}-{feat_slug}",
                "kind": "feature",
                "label": feat_name,
                "entryId": entry_id("classFeature", feat_slug),
            })
        prog_entry: dict[str, Any] = {"levels": [level]}
        if grants:
            prog_entry["grants"] = grants
        progression.append(prog_entry)

    # 提取背景描述（跳过特性段落和摘要）
    desc_text = ""
    for p in soup.find_all("p"):
        ptext = clean_text(p.get_text())
        if not ptext or re.match(r"^\d+级[：:]", ptext):
            continue
        if len(ptext) > 50 and "核心特质" not in ptext and "特性表" not in ptext:
            desc_text = ptext
            break

    # 构造 body：背景描述 + 非特性段落/列表/表格
    body_blocks: list[dict[str, Any]] = []
    if desc_text:
        body_blocks.append({"type": "paragraph", "text": desc_text})
    for el in soup.find_all(["p", "ul", "table"]):
        text = clean_text(el.get_text())
        if not text or text == desc_text:
            continue
        # 跳过特性段落（已转为 classFeature 条目）
        if el.name == "p" and re.match(r"^\d+级[：:]", text):
            continue
        if el.name == "ul":
            items = [clean_text(li.get_text()) for li in el.find_all("li", recursive=False)]
            items = [i for i in items if i]
            if items:
                body_blocks.append({"type": "list", "ordered": False, "items": items})
        elif el.name == "table":
            body_blocks.extend(table_to_blocks(el))
        else:
            body_blocks.append({"type": "paragraph", "text": text})

    structured: dict[str, Any] = {
        "parentClass": parent_class_name,
    }
    relations: list[dict[str, Any]] = [
        {"type": "subclassOf", "targetId": entry_id("class", parent_class_slug)},
    ]
    rules: dict[str, Any] = {}
    if progression:
        rules["progression"] = progression

    subclass_entry = make_entry(
        "subclass", slug, name, body_blocks,
        structured=structured,
        tags=[parent_class_slug, "subclass"],
        aliases=[en_name] if en_name else [],
        summary=f"{parent_class_name}子职业：{name}",
        rules=rules if rules else None,
        relations=relations,
        source_path=str(sub_path),
    )
    return subclass_entry, subclass_feature_entries


# --------------------------------------------------------------------------- #
# 法术提取
# --------------------------------------------------------------------------- #
SPELL_FILE_MAP = {
    0: "0环.htm", 1: "1环.htm", 2: "2环.htm", 3: "3环.htm", 4: "4环.htm",
    5: "5环.htm", 6: "6环.htm", 7: "7环.htm", 8: "8环.htm", 9: "9环.htm",
}
SCHOOL_LABELS = {"防护", "塑能", "变化", "死灵", "幻术", "预言", "咒法", "转化", "惑控"}
LEVEL_LABELS = {"戏法", "一环", "二环", "三环", "四环", "五环",
                "六环", "七环", "八环", "九环"}


def extract_spells() -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    schools_pat = "|".join(SCHOOL_LABELS)
    levels_pat = "|".join(LEVEL_LABELS)
    for level, fname in SPELL_FILE_MAP.items():
        path = PHB_ROOT / "法术详述" / fname
        if not path.exists():
            continue
        html = read_html(path)
        soup = BeautifulSoup(html, "html.parser")

        current_h4 = None
        current_p = None
        for el in soup.descendants:
            if not getattr(el, "name", None):
                continue
            if el.name == "h4":
                current_h4 = el
                current_p = None
                continue
            if el.name == "p" and current_h4 is not None and current_p is None:
                if clean_text(el.get_text()):
                    current_p = el
                    _process_spell(current_h4, current_p, level,
                                   schools_pat, levels_pat, items, path)
                    current_h4 = None
    return items


def _process_spell(h4: Tag, p: Tag, level: int, schools_pat: str,
                   levels_pat: str, items: list, source_path: Path) -> None:
    title_raw = h4.get_text()
    name, en_name = split_title(title_raw)
    if not name:
        return
    slug = slugify(name, en_name)
    structured: dict[str, Any] = {"level": level}
    structured["levelLabel"] = "戏法" if level == 0 else f"{level}环"

    em = p.find("em")
    em_text = clean_text(em.get_text()) if em else ""
    # 学派在前：group(1)=学派, group(2)=环阶, group(3)=职业
    m1 = re.search(rf"({schools_pat})\s+({levels_pat})\s*[（(]([^）)]*)[）)]", em_text)
    # 环阶在前：group(1)=环阶, group(2)=学派, group(3)=职业
    m2 = re.search(rf"({levels_pat})\s+({schools_pat})\s*[（(]([^）)]*)[）)]", em_text)
    if m1:
        structured["school"] = m1.group(1)
        structured["classes"] = [c.strip() for c in m1.group(3).split("、") if c.strip()]
    elif m2:
        structured["school"] = m2.group(2)
        structured["classes"] = [c.strip() for c in m2.group(3).split("、") if c.strip()]

    # 用 <BR> 分段提取字段
    raw_html = str(p)
    raw_html = re.sub(r"<em\b[^>]*>.*?</em>", "", raw_html, flags=re.IGNORECASE | re.DOTALL)
    raw_html = re.sub(
        r"<(?:strong|b)\b[^>]*>.*?</(?:strong|b)>",
        lambda m: f"【{clean_text(re.sub(r'<[^>]+>', '', m.group(0)))}】",
        raw_html, flags=re.IGNORECASE | re.DOTALL,
    )
    raw_html = re.sub(r"</?p[^>]*>", "", raw_html)
    segments = re.split(r"<br\s*/?>", raw_html, flags=re.IGNORECASE)
    segments = [clean_text(re.sub(r"<[^>]+>", "", s)) for s in segments]
    segments = [s for s in segments if s]

    field_map = {
        "施法时间": "castingTime",
        "施法距离": "range",
        "法术成分": "components",
        "持续时间": "duration",
    }
    desc_parts: list[str] = []
    for seg in segments:
        matched = False
        for label, field in field_map.items():
            if seg.startswith(f"【{label}：】") or seg.startswith(f"【{label}:】"):
                value = seg[len(f"【{label}：】"):].strip()
                if value:
                    structured[field] = value
                matched = True
                break
            if seg.startswith(f"【{label}】"):
                value = seg[len(f"【{label}】"):].strip().lstrip("：:").strip()
                if value:
                    structured[field] = value
                matched = True
                break
        if not matched:
            seg_clean = re.sub(r"【[^】]*】", "", seg).strip()
            if seg_clean:
                desc_parts.append(seg_clean)

    desc = " ".join(desc_parts).strip()
    comps = structured.get("components", "")
    if "(仪式)" in comps or "（仪式）" in comps:
        structured["ritual"] = True

    if not desc:
        desc = f"{name}：{em_text}"

    body = [{"type": "paragraph", "text": desc}]
    # 添加 statBlock 块
    stat_fields: dict[str, str] = {}
    for k, v in [
        ("环阶", structured.get("levelLabel", "")),
        ("学派", structured.get("school", "")),
        ("施法时间", structured.get("castingTime", "")),
        ("施法距离", structured.get("range", "")),
        ("法术成分", structured.get("components", "")),
        ("持续时间", structured.get("duration", "")),
    ]:
        if v:
            stat_fields[k] = str(v)
    if stat_fields:
        body.insert(0, {"type": "statBlock", "fields": stat_fields})

    tags = [structured["school"].lower()] if structured.get("school") else []
    tags.extend(_spell_list_tags(structured.get("classes", [])))
    entry = make_entry(
        "spell", slug, name, body,
        structured=structured,
        tags=tags,
        aliases=[en_name] if en_name else [],
        summary=f"{structured.get('levelLabel', '')} {structured.get('school', '')} · {name}",
        source_path=str(source_path),
    )
    items.append(entry)


def _spell_list_tags(class_names: list[str]) -> list[str]:
    return sorted({
        f"spell-list:{CLASS_ENTRY_SLUGS[name]}"
        for name in class_names
        if name in CLASS_ENTRY_SLUGS
    })


# --------------------------------------------------------------------------- #
# 专长提取
# --------------------------------------------------------------------------- #
def extract_feats() -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    feat_files = [
        ("通用专长.htm", "通用"),
        ("起源专长.htm", "起源"),
        ("战斗风格专长.htm", "战斗风格"),
        ("传奇恩惠专长.htm", "传奇恩惠"),
    ]
    for fname, category in feat_files:
        path = PHB_ROOT / "专长" / fname
        if not path.exists():
            continue
        html = read_html(path)
        soup = BeautifulSoup(html, "html.parser")
        for p in soup.find_all("p"):
            text = clean_text(p.get_text())
            m = re.match(
                r"^(.+?)\s+(?:通用专长|起源专长|战斗风格专长|传奇恩惠专长)[（(]([^）)]*)[）)]",
                text,
            )
            if not m:
                continue
            name_raw = m.group(1).strip()
            prereq = m.group(2).strip().replace("先决：", "").replace("先决:", "")
            name, en_name = split_title(name_raw)
            slug = slugify(name, en_name)
            desc_head = text[m.end():].strip()
            ul = p.find_next_sibling("ul")
            benefits: list[str] = []
            if ul:
                divs = ul.find_all("div")
                if divs:
                    for div in divs:
                        t = clean_text(div.get_text())
                        if t:
                            benefits.append(t)
                else:
                    for li in ul.find_all("li", recursive=False):
                        t = clean_text(li.get_text())
                        if t:
                            benefits.append(t)
            body: list[dict[str, Any]] = []
            if desc_head:
                body.append({"type": "paragraph", "text": desc_head})
            if benefits:
                body.append({"type": "list", "ordered": False, "items": benefits})
            if not body:
                body.append({"type": "paragraph", "text": f"{name} 是一个{category}专长。"})

            structured: dict[str, Any] = {"category": category}
            if prereq:
                structured["prerequisite"] = prereq
            if benefits:
                structured["benefits"] = benefits

            entry = make_entry(
                "feat", slug, name, body,
                structured=structured,
                tags=[category],
                aliases=[en_name] if en_name else [],
                summary=f"{category}专长 · {name}",
                source_path=str(path),
            )
            items.append(entry)
    return items


# --------------------------------------------------------------------------- #
# 种族提取
# --------------------------------------------------------------------------- #
def extract_species() -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    race_dir = PHB_ROOT / "角色起源" / "种族"
    if not race_dir.exists():
        return items
    for path in sorted(race_dir.glob("*.htm")):
        html = read_html(path)
        soup = BeautifulSoup(html, "html.parser")
        h2 = soup.find("h2")
        if not h2:
            continue
        name, en_name = split_title(h2.get_text())
        if not name:
            continue
        slug = slugify(name, en_name)

        structured: dict[str, Any] = {}
        desc = ""
        traits_started = False
        extra_blocks: list[str] = []

        for el in soup.find_all(["p", "blockquote", "ul", "table"]):
            text = clean_text(el.get_text())
            if not text:
                continue
            if "生物类型" in text and "特质" in text[:20]:
                m = re.search(r"生物类型[：:]\s*(.+?)(?=体型[：:]|$)", text)
                if m:
                    structured["creatureType"] = m.group(1).strip()
                m = re.search(r"体型[：:]\s*(.+?)(?=速度[：:]|$)", text)
                if m:
                    structured["size"] = m.group(1).strip()
                m = re.search(r"速度[：:]\s*(\d+\s*(?:尺|英尺))", text)
                if m:
                    structured["speed"] = m.group(1).strip()
                continue
            if re.match(r"^作为.+，你有以下特殊特质", text):
                traits_started = True
                extra_blocks.append(text)
                continue
            if traits_started:
                extra_blocks.append(text)
                continue
            if not desc and len(text) > 80 and "特质" not in text[:15]:
                desc = text

        if not desc:
            desc = f"{name} 是 D&D 中的一个可玩种族。"
        if extra_blocks:
            desc = desc + "\n\n" + "\n\n".join(extra_blocks)

        body: list[dict[str, Any]] = []
        for part in desc.split("\n\n"):
            part = part.strip()
            if part:
                body.append({"type": "paragraph", "text": part})

        # 添加 statBlock
        stat_fields: dict[str, str] = {}
        for k, v in [
            ("生物类型", structured.get("creatureType", "")),
            ("体型", structured.get("size", "")),
            ("速度", structured.get("speed", "")),
        ]:
            if v:
                stat_fields[k] = str(v)
        if stat_fields:
            body.insert(0, {"type": "statBlock", "fields": stat_fields})

        entry = make_entry(
            "species", slug, name, body,
            structured=structured,
            tags=[],
            aliases=[en_name] if en_name else [],
            summary=f"种族 · {name}",
            source_path=str(path),
        )
        items.append(entry)
    return items


# --------------------------------------------------------------------------- #
# 背景提取
# --------------------------------------------------------------------------- #
def extract_backgrounds() -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    bg_dir = PHB_ROOT / "角色起源" / "背景"
    if not bg_dir.exists():
        return items
    for path in sorted(bg_dir.glob("*.htm")):
        html = read_html(path)
        soup = BeautifulSoup(html, "html.parser")
        h3 = soup.find("h3")
        if not h3:
            continue
        name, en_name = split_title(h3.get_text())
        if not name:
            continue
        slug = slugify(name, en_name)
        text = clean_text(soup.get_text())
        structured: dict[str, Any] = {}
        m = re.search(r"属性值[：:]\s*([^Bb\s][^\n]*?)(?=\s*专长|$)", text)
        if m:
            structured["abilityScoreHint"] = m.group(1).strip()
        m = re.search(r"专长[：:]\s*([^\n]*?)(?=\s*技能熟练|$)", text)
        if m:
            structured["recommendedFeat"] = m.group(1).strip()
        m = re.search(r"技能熟练[：:]\s*([^\n]*?)(?=\s*工具熟练|$)", text)
        if m:
            structured["skills"] = m.group(1).strip()
        m = re.search(r"工具熟练[：:]\s*([^\n]*?)(?=\s*装备|$)", text)
        if m:
            structured["toolProficiency"] = m.group(1).strip()
        m = re.search(r"装备[：:]\s*(.+?)(?=\s*(?:你在|你曾|作为|$))", text)
        if m:
            structured["startingEquipment"] = m.group(1).strip()

        desc = ""
        for p in soup.find_all("p"):
            ptext = clean_text(p.get_text())
            if "属性值" not in ptext and len(ptext) > 30:
                desc = ptext
                break
        if not desc:
            desc = f"{name} 是 D&D 中的一个角色背景。"

        body: list[dict[str, Any]] = []
        # 收集所有段落
        for p in soup.find_all("p"):
            ptext = clean_text(p.get_text())
            if ptext and not (
                "属性值" in ptext
                and "专长" in ptext
                and "技能熟练" in ptext
                and "装备" in ptext
            ):
                body.append({"type": "paragraph", "text": ptext})
        for ul in soup.find_all("ul"):
            items_list = [clean_text(li.get_text()) for li in ul.find_all("li", recursive=False)]
            items_list = [i for i in items_list if i]
            if items_list:
                body.append({"type": "list", "ordered": False, "items": items_list})

        stat_fields: dict[str, str] = {}
        for k, v in [
            ("属性值", structured.get("abilityScoreHint", "")),
            ("专长", structured.get("recommendedFeat", "")),
            ("技能熟练", structured.get("skills", "")),
            ("工具熟练", structured.get("toolProficiency", "")),
            ("装备", structured.get("startingEquipment", "")),
        ]:
            if v:
                stat_fields[k] = str(v)
        if stat_fields:
            body.insert(0, {"type": "statBlock", "fields": stat_fields})

        entry = make_entry(
            "background", slug, name, body,
            structured=structured,
            tags=[],
            aliases=[en_name] if en_name else [],
            summary=f"背景 · {name}",
            source_path=str(path),
        )
        items.append(entry)
    return items


# --------------------------------------------------------------------------- #
# 装备提取
# --------------------------------------------------------------------------- #
def extract_equipment() -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []

    # 武器
    wep_path = PHB_ROOT / "装备" / "武器.htm"
    if wep_path.exists():
        html = read_html(wep_path)
        soup = BeautifulSoup(html, "html.parser")
        rows = parse_table_rows(soup)
        current_category = None
        for row in rows:
            if not row:
                continue
            if len(row) == 1:
                cat_text = row[0]
                if "简易" in cat_text:
                    current_category = "简易武器"
                elif "军用" in cat_text:
                    current_category = "军用武器"
                elif "火器" in cat_text:
                    current_category = "火器"
                continue
            if len(row) >= 6 and row[0] not in ("名称", ""):
                name, damage, props, mastery, weight, price = row[:6]
                name_zh, name_en = split_title(name)
                slug = slugify(name_zh, name_en)
                structured = {
                    "category": current_category or "武器",
                    "damage": damage,
                    "properties": props,
                    "mastery": mastery,
                    "weight": weight,
                    "price": price,
                }
                # 武器攻击属性：客户端 weaponAbility 的判据真源。远程/弹药武器
                # 显式写死 dex；灵巧武器写 finesse: true，由客户端取 STR/DEX 较优。
                if "弹药" in props or "远程" in props:
                    structured["ability"] = "dex"
                if "灵巧" in props:
                    structured["finesse"] = True
                stat_fields = {
                    "类别": current_category or "武器",
                    "伤害": damage,
                    "词条": props,
                    "精通": mastery,
                    "重量": weight,
                    "价格": price,
                }
                body = [
                    {"type": "statBlock", "fields": stat_fields},
                    {"type": "paragraph", "text": f"{name_zh}，{current_category or '武器'}。伤害 {damage}，词条 {props}，精通 {mastery}，{weight}，{price}。"},
                ]
                entry = make_entry(
                    "equipment", slug, name_zh, body,
                    structured=structured,
                    tags=["武器", current_category or "武器"],
                    aliases=[name_en] if name_en else [],
                    summary=f"{current_category or '武器'} · {name_zh}",
                    source_path=str(wep_path),
                )
                items.append(entry)

    # 护甲
    arm_path = PHB_ROOT / "装备" / "护甲.htm"
    if arm_path.exists():
        html = read_html(arm_path)
        soup = BeautifulSoup(html, "html.parser")
        rows = parse_table_rows(soup)
        current_category = None
        for row in rows:
            if not row:
                continue
            if len(row) == 1:
                cat_text = row[0]
                if "轻甲" in cat_text:
                    current_category = "轻甲"
                elif "中甲" in cat_text:
                    current_category = "中甲"
                elif "重甲" in cat_text:
                    current_category = "重甲"
                elif "盾" in cat_text:
                    current_category = "盾牌"
                continue
            if len(row) >= 6 and row[0] not in ("护甲", "名称", ""):
                name = row[0]
                ac = row[1]
                strength = row[2] if len(row) > 2 else ""
                stealth = row[3] if len(row) > 3 else ""
                weight = row[4] if len(row) > 4 else ""
                price = row[5] if len(row) > 5 else ""
                name_zh, name_en = split_title(name)
                slug = slugify(name_zh, name_en)
                structured: dict[str, Any] = {
                    "category": current_category or "护甲",
                    "ac": ac,
                    "weight": weight,
                    "price": price,
                }
                if strength and strength != "―":
                    structured["strength"] = strength
                if stealth and stealth != "―":
                    structured["stealth"] = stealth
                stat_fields = {
                    "类别": current_category or "护甲",
                    "AC": ac,
                    "重量": weight,
                    "价格": price,
                }
                if strength and strength != "―":
                    stat_fields["力量"] = strength
                if stealth and stealth != "―":
                    stat_fields["隐匿"] = stealth
                body = [
                    {"type": "statBlock", "fields": stat_fields},
                    {"type": "paragraph", "text": f"{name_zh}，{current_category or '护甲'}。AC {ac}，{weight}，{price}。"},
                ]
                entry = make_entry(
                    "equipment", slug, name_zh, body,
                    structured=structured,
                    tags=["护甲", current_category or "护甲"],
                    aliases=[name_en] if name_en else [],
                    summary=f"{current_category or '护甲'} · {name_zh}",
                    source_path=str(arm_path),
                )
                items.append(entry)

    # 冒险装备
    adv_path = PHB_ROOT / "装备" / "冒险装备.htm"
    if adv_path.exists():
        html = read_html(adv_path)
        soup = BeautifulSoup(html, "html.parser")
        rows = parse_table_rows(soup)
        for row in rows:
            if len(row) < 3:
                continue
            for start in (0, 4):
                if start + 2 >= len(row):
                    continue
                name = row[start]
                if not name or name in ("物品", "名称"):
                    continue
                weight = row[start + 1]
                price = row[start + 2]
                name_zh, name_en = split_title(name)
                slug = slugify(name_zh, name_en)
                structured = {"category": "冒险装备", "weight": weight, "price": price}
                stat_fields = {"类别": "冒险装备", "重量": weight, "价格": price}
                body = [
                    {"type": "statBlock", "fields": stat_fields},
                    {"type": "paragraph", "text": f"{name_zh}，冒险装备。{weight}，{price}。"},
                ]
                entry = make_entry(
                    "item", slug, name_zh, body,
                    structured=structured,
                    tags=["冒险装备"],
                    aliases=[name_en] if name_en else [],
                    summary=f"冒险装备 · {name_zh}",
                    source_path=str(adv_path),
                )
                items.append(entry)

    return items


# --------------------------------------------------------------------------- #
# 主流程
# --------------------------------------------------------------------------- #
def main() -> int:
    if not PHB_ROOT.exists():
        print(f"ERROR: PHB 2024 root not found: {PHB_ROOT}", file=sys.stderr)
        return 1

    # 清空输出目录
    if OUT_DIR.exists():
        import shutil
        shutil.rmtree(OUT_DIR)
    ENTRIES_DIR.mkdir(parents=True, exist_ok=True)
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    print("Extracting classes...")
    class_count = 0
    feature_count = 0
    subclass_count = 0
    for cls_name in CLASS_DIRS:
        cls_entry, features, subclasses = extract_class(cls_name)
        if cls_entry:
            ALL_ENTRIES.append(cls_entry)
            class_count += 1
        ALL_ENTRIES.extend(features)
        feature_count += len(features)
        ALL_ENTRIES.extend(subclasses)
        subclass_count += len(subclasses)
    print(f"  classes: {class_count}, classFeatures: {feature_count}, subclasses: {subclass_count}")

    print("Extracting spells...")
    spells = extract_spells()
    ALL_ENTRIES.extend(spells)
    print(f"  spells: {len(spells)}")

    print("Extracting feats...")
    feats = extract_feats()
    ALL_ENTRIES.extend(feats)
    print(f"  feats: {len(feats)}")

    print("Extracting species...")
    species = extract_species()
    ALL_ENTRIES.extend(species)
    print(f"  species: {len(species)}")

    print("Extracting backgrounds...")
    backgrounds = extract_backgrounds()
    ALL_ENTRIES.extend(backgrounds)
    print(f"  backgrounds: {len(backgrounds)}")

    print("Extracting equipment...")
    equipment = extract_equipment()
    ALL_ENTRIES.extend(equipment)
    print(f"  equipment+items: {len(equipment)}")

    # 写入条目文件
    print(f"\nWriting {len(ALL_ENTRIES)} entry files...")
    for entry in ALL_ENTRIES:
        slug = entry["slug"]
        type_ = entry["type"]
        fname = f"{type_}-{slug}.json"
        # 去除内部字段 _sourcePath（只用于链接解析）
        out_entry = {k: v for k, v in entry.items() if not k.startswith("_")}
        (ENTRIES_DIR / fname).write_text(
            json.dumps(out_entry, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    # 写入 manifest
    manifest = {
        "formatVersion": 3,
        "id": PACKAGE_ID,
        "name": "玩家手册 2024 私有资料包",
        "version": PACKAGE_VERSION,
        "locale": LOCALE,
        "system": SYSTEM,
        "entryCount": len(ALL_ENTRIES),
    }
    (OUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # 写入聚合 bundle（供客户端导入测试）
    bundle = {**manifest, "entries": [
        {k: v for k, v in e.items() if not k.startswith("_")} for e in ALL_ENTRIES
    ]}
    bundle_path = REPO_ROOT / "private-imports" / "phb-2024-v2-bundle.json"
    bundle_path.write_text(
        json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # 统计报告
    by_type: dict[str, int] = {}
    for e in ALL_ENTRIES:
        by_type[e["type"]] = by_type.get(e["type"], 0) + 1

    # 重复 slug 检测
    slug_counts: dict[str, int] = {}
    for e in ALL_ENTRIES:
        key = f"{e['type']}/{e['slug']}"
        slug_counts[key] = slug_counts.get(key, 0) + 1
    duplicates = {k: v for k, v in slug_counts.items() if v > 1}

    # 断链统计
    unresolved_summary: dict[str, int] = {}
    for link in UNRESOLVED_LINKS:
        key = link.get("href", "unknown")
        unresolved_summary[key] = unresolved_summary.get(key, 0) + 1

    report = {
        "packageId": PACKAGE_ID,
        "version": PACKAGE_VERSION,
        "totalEntries": len(ALL_ENTRIES),
        "byType": dict(sorted(by_type.items())),
        "duplicates": duplicates,
        "unresolvedLinksCount": len(UNRESOLVED_LINKS),
        "unresolvedLinksSummary": unresolved_summary,
        "manualReviewCount": len(MANUAL_REVIEW),
    }
    (OUT_DIR / "extraction-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # 断链详情
    (OUT_DIR / "unresolved-links.json").write_text(
        json.dumps(UNRESOLVED_LINKS, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # 人工复核项
    (OUT_DIR / "manual-review.json").write_text(
        json.dumps(MANUAL_REVIEW, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    # 打印摘要
    print("\n" + "=" * 60)
    print(f"Extraction complete: {len(ALL_ENTRIES)} entries")
    print(f"Output: {OUT_DIR}")
    print(f"Bundle: {bundle_path}")
    print(f"\nBy type:")
    for t, c in sorted(by_type.items()):
        print(f"  {t}: {c}")
    if duplicates:
        print(f"\nDuplicates: {len(duplicates)}")
        for k, v in duplicates.items():
            print(f"  {k}: {v}")
    print(f"\nUnresolved links: {len(UNRESOLVED_LINKS)}")
    print(f"Manual review items: {len(MANUAL_REVIEW)}")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
