#!/usr/bin/env python3
"""
从 CHM 解压的 HTML 中提取玩家手册 2024 的详细内容。

输出 private-imports/phb-2024-index.content.private.json，包含：
- 法术：学派、环阶、施法时间、射程、成分、持续时间、描述
- 专长：类别、先决条件、效果
- 装备：类别、伤害、词条、精通、重量、价格
- 种族：体型、速度、特性、描述
- 职业：主属性、生命骰、熟练、描述
- 背景：属性值、专长、技能熟练、工具熟练、装备、描述
"""
import json
import os
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

try:
    from bs4 import BeautifulSoup
except ImportError:
    print("ERROR: pip install beautifulsoup4", file=sys.stderr)
    sys.exit(1)

CHM_ROOT = Path("private-imports/chm-extract")
PHB_ROOT = CHM_ROOT / "玩家手册2024"

# 读取 GB2312 文件
def read_html(path: Path) -> str:
    raw = path.read_bytes()
    for enc in ("gb2312", "gbk", "gb18030", "utf-8"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("gb18030", errors="replace")


def clean_text(s: str) -> str:
    s = re.sub(r"<[^>]+>", "", s)
    s = re.sub(r"&nbsp;", " ", s)
    s = re.sub(r"&amp;", "&", s)
    s = re.sub(r"&lt;", "<", s)
    s = re.sub(r"&gt;", ">", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def parse_table_rows(soup) -> list:
    rows = []
    for tr in soup.find_all("tr"):
        cells = [clean_text(td.get_text()) for td in tr.find_all(["td", "th"])]
        if cells:
            rows.append(cells)
    return rows


# ============================ 法术提取 ============================
SPELL_FILE_MAP = {0: "0环.htm", 1: "1环.htm", 2: "2环.htm", 3: "3环.htm", 4: "4环.htm",
                  5: "5环.htm", 6: "6环.htm", 7: "7环.htm", 8: "8环.htm", 9: "9环.htm"}

SCHOOL_LABELS = {"防护": "防护", "塑能": "塑能", "变化": "变化", "死灵": "死灵",
                 "幻术": "幻术", "预言": "预言", "咒法": "咒法", "转化": "转化"}


def extract_spells() -> list:
    items = []
    schools = "防护|塑能|变化|死灵|幻术|预言|咒法|转化|惑控"
    levels_pat = "戏法|一环|二环|三环|四环|五环|六环|七环|八环|九环"
    for level, fname in SPELL_FILE_MAP.items():
        path = PHB_ROOT / "法术详述" / fname
        if not path.exists():
            continue
        html = read_html(path)
        soup = BeautifulSoup(html, "html.parser")

        # 按文档顺序遍历所有 h4 / p，避免嵌套 <p>（HTML 畸形）导致的 sibling 失效。
        # 每遇到 h4，就开始一个新法术；后续遇到的 p 都属于这个法术，直到下一个 h4。
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
                # 跳过空 p
                if clean_text(el.get_text()):
                    current_p = el
                    _process_spell(current_h4, current_p, level, schools,
                                   levels_pat, items)
                    current_h4 = None  # 防止重复处理
    return items


def _process_spell(h4, p, level, schools, levels_pat, items):
    title_raw = h4.get_text()
    name, en_name = split_title(title_raw)
    if not name:
        return
    structured = {"level": level}
    if level == 0:
        structured["levelLabel"] = "戏法"
    else:
        structured["levelLabel"] = f"{level}环"

    # 解析 <em>学派 环阶（职业列表）</em>
    # 0环格式：塑能 戏法（...）— 学派在前
    # 1-9环格式：一环 防护（...）— 环阶在前
    em = p.find("em")
    em_text = clean_text(em.get_text()) if em else ""
    # 学派在前：group(1)=学派, group(2)=环阶, group(3)=职业
    m1 = re.search(
        rf"({schools})\s+({levels_pat})\s*[（(]([^）)]*)[）)]",
        em_text)
    # 环阶在前：group(1)=环阶, group(2)=学派, group(3)=职业
    m2 = re.search(
        rf"({levels_pat})\s+({schools})\s*[（(]([^）)]*)[）)]",
        em_text)
    if m1:
        structured["school"] = m1.group(1)
        classes = m1.group(3)
        structured["classes"] = [c.strip() for c in classes.split("、") if c.strip()]
    elif m2:
        structured["school"] = m2.group(2)  # group(2) 是学派
        classes = m2.group(3)
        structured["classes"] = [c.strip() for c in classes.split("、") if c.strip()]

    # 用 <BR> 分段提取：复制 p 的 HTML，避免修改 soup 树（嵌套 p 会让 decompose 误删后续法术的 em）
    raw_html = str(p)
    # 去掉 <em>...</em>
    raw_html = re.sub(r"<em\b[^>]*>.*?</em>", "", raw_html, flags=re.IGNORECASE | re.DOTALL)
    # 把 <strong>/<b> 替换为"【字段名】"标记
    def _strong_repl(m):
        inner = clean_text(re.sub(r"<[^>]+>", "", m.group(0)))
        return f"【{inner}】"
    raw_html = re.sub(r"<(?:strong|b)\b[^>]*>.*?</(?:strong|b)>", _strong_repl,
                      raw_html, flags=re.IGNORECASE | re.DOTALL)
    # 去掉 <p> 和 </p>
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
    desc_parts = []
    for seg in segments:
        matched = False
        for label, field in field_map.items():
            if seg.startswith(f"【{label}：】") or seg.startswith(f"【{label}:】"):
                value = seg[len(f"【{label}：】"):].strip()
                if not value:
                    matched = True
                    break
                structured[field] = value
                matched = True
                break
            if seg.startswith(f"【{label}】"):
                value = seg[len(f"【{label}】"):].strip().lstrip("：:").strip()
                structured[field] = value
                matched = True
                break
        if not matched:
            seg = re.sub(r"【[^】]*】", "", seg).strip()
            if seg:
                desc_parts.append(seg)

    desc = " ".join(desc_parts).strip()
    comps = structured.get("components", "")
    if "(仪式)" in comps or "（仪式）" in comps:
        structured["ritual"] = True

    if not desc:
        desc = f"{name}：{em_text}"

    slug = (en_name or name).lower().replace(" ", "-").replace("'", "")
    items.append({
        "type": "spell",
        "slug": slug,
        "name": name,
        "description": desc,
        "structured": structured,
        "tags": [structured["school"].lower()] if structured.get("school") else [],
        "sourceLabel": "玩家手册 2024",
        "schemaVersion": 2,
    })


def split_title(raw: str):
    """分离中文与英文名。
    '酸液飞溅｜Acid Splash' -> ('酸液飞溅', 'Acid Splash')
    '短棒Club'              -> ('短棒', 'Club')
    '长剑Longsword'         -> ('长剑', 'Longsword')
    """
    raw = raw.strip()
    # 1) 显式分隔符
    for sep in ["｜", "|", "·"]:
        if sep in raw:
            parts = raw.split(sep, 1)
            return parts[0].strip(), parts[1].strip()
    # 2) 中英连写：在中文/全角符号段与 ASCII 字母段之间切分
    m = re.match(r"^([\u4e00-\u9fff\u3000-\u303f·\s]+)\s*([A-Za-z][A-Za-z\s'\-]*)$", raw)
    if m:
        return m.group(1).strip(), m.group(2).strip()
    return raw, None


# ============================ 专长提取 ============================
def extract_feats() -> list:
    items = []
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
        # 每个专长条目：<p> 标题行（含名称+类别+先决），紧跟一个 <ul> 增益列表
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
            # 描述：标题行剩余文字 + 紧跟的 <ul> 增益列表
            desc_head = text[m.end():].strip()
            # 找下一个兄弟元素中的 <ul>
            ul = p.find_next_sibling("ul")
            benefits: list[str] = []
            if ul:
                # CHM 的 <li> 未闭合导致嵌套，每个增益实际包在 <div> 里
                divs = ul.find_all("div")
                if divs:
                    for div in divs:
                        t = clean_text(div.get_text())
                        if t:
                            benefits.append(t)
                else:
                    # 回退：直接按 <li> 提取（仅取直接子级避免嵌套重复）
                    for li in ul.find_all("li", recursive=False):
                        t = clean_text(li.get_text())
                        if t:
                            benefits.append(t)
            desc_parts = []
            if desc_head:
                desc_parts.append(desc_head)
            if benefits:
                desc_parts.append("\n".join(f"• {b}" for b in benefits))
            desc = "\n".join(desc_parts) if desc_parts else f"{name} 是一个{category}专长。"

            structured = {"category": category}
            if prereq:
                structured["prerequisite"] = prereq
            if benefits:
                structured["benefits"] = benefits

            slug = (en_name or name).lower().replace(" ", "-").replace("'", "")
            items.append({
                "type": "feat",
                "slug": slug,
                "name": name,
                "description": desc,
                "structured": structured,
                "tags": [category.lower()],
                "sourceLabel": "玩家手册 2024",
                "schemaVersion": 2,
            })
    return items


# ============================ 装备提取 ============================
def extract_equipment() -> list:
    items = []
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
            # 表头：名称 伤害 词条 精通 重量 价格
            if len(row) >= 6 and row[0] not in ("名称", ""):
                name, damage, props, mastery, weight, price = row[:6]
                name_zh, name_en = split_title(name)
                structured = {
                    "category": current_category or "武器",
                    "damage": damage,
                    "properties": props,
                    "mastery": mastery,
                    "weight": weight,
                    "price": price,
                }
                desc = f"伤害 {damage} · 词条 {props} · 精通 {mastery} · {weight} · {price}"
                slug = (name_en or name_zh).lower().replace(" ", "-")
                items.append({
                    "type": "equipment",
                    "slug": slug,
                    "name": name_zh,
                    "description": desc,
                    "structured": structured,
                    "tags": ["武器", (current_category or "武器")],
                    "sourceLabel": "玩家手册 2024",
                    "schemaVersion": 2,
                })

    # 护甲：列顺序 名称 AC 力量 隐匿 重量 价格
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
                structured = {
                    "category": current_category or "护甲",
                    "ac": ac,
                    "weight": weight,
                    "price": price,
                }
                if strength and strength != "―":
                    structured["strength"] = strength
                if stealth and stealth != "―":
                    structured["stealth"] = stealth
                desc = f"AC {ac} · {weight} · {price}"
                if stealth and stealth != "―":
                    desc += f" · 隐匿{stealth}"
                slug = (name_en or name_zh).lower().replace(" ", "-")
                items.append({
                    "type": "equipment",
                    "slug": slug,
                    "name": name_zh,
                    "description": desc,
                    "structured": structured,
                    "tags": ["护甲", (current_category or "护甲")],
                    "sourceLabel": "玩家手册 2024",
                    "schemaVersion": 2,
                })

    # 冒险装备：双栏布局 物品|重量|价格|空|物品|重量|价格
    adv_path = PHB_ROOT / "装备" / "冒险装备.htm"
    if adv_path.exists():
        html = read_html(adv_path)
        soup = BeautifulSoup(html, "html.parser")
        rows = parse_table_rows(soup)
        for row in rows:
            if len(row) < 3:
                continue
            # 双栏：左栏 row[0..2]，右栏 row[4..6]（row[3] 为空分隔）
            for start in (0, 4):
                if start + 2 >= len(row):
                    continue
                name = row[start]
                if not name or name in ("物品", "名称"):
                    continue
                weight = row[start + 1]
                price = row[start + 2]
                name_zh, name_en = split_title(name)
                structured = {"category": "冒险装备", "weight": weight, "price": price}
                desc = f"{weight} · {price}"
                slug = (name_en or name_zh).lower().replace(" ", "-")
                items.append({
                    "type": "item",
                    "slug": slug,
                    "name": name_zh,
                    "description": desc,
                    "structured": structured,
                    "tags": ["冒险装备"],
                    "sourceLabel": "玩家手册 2024",
                    "schemaVersion": 2,
                })
    return items


# ============================ 种族提取 ============================
def extract_species() -> list:
    items = []
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

        structured: dict = {}
        desc = ""
        traits_started = False
        extra_blocks: list[str] = []

        # 按文档顺序遍历所有元素
        for el in soup.find_all(["p", "blockquote", "ul", "table"]):
            text = clean_text(el.get_text())
            if not text:
                continue
            # 特质摘要行：必须同时含"生物类型"和"特质"（精确匹配，避免误判）
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
            # 详细特质段：以"作为XX"开头
            if re.match(r"^作为.+，你有以下特殊特质", text):
                traits_started = True
                extra_blocks.append(text)
                continue
            # 特质段开始后，所有后续内容（blockquote/ul/table/补充 p）都属于特质
            if traits_started:
                if el.name == "p" and re.match(r"^作为.+，你有以下特殊特质", text):
                    extra_blocks.append(text)
                else:
                    extra_blocks.append(text)
                continue
            # 背景描述：第一个长段落
            if not desc and len(text) > 80 and "特质" not in text[:15]:
                desc = text

        if not desc:
            desc = f"{name} 是 D&D 中的一个可玩种族。"

        # 把详细特质 + 表格/blockquote 内容全部拼到描述里
        if extra_blocks:
            desc = desc + "\n\n" + "\n\n".join(extra_blocks)

        slug = (en_name or name).lower().replace(" ", "-")
        items.append({
            "type": "species",
            "slug": slug,
            "name": name,
            "description": desc,
            "structured": structured,
            "tags": [],
            "sourceLabel": "玩家手册 2024",
            "schemaVersion": 2,
        })
    return items


# ============================ 职业提取 ============================
CLASS_DIRS = ["战士", "法师", "术士", "武僧", "游侠", "游荡者", "牧师", "野蛮人", "魔契师", "圣武士", "德鲁伊", "吟游诗人"]


def _parse_class_core_table(soup) -> dict:
    """从职业核心特质 <table> 中按字段标签提取。"""
    structured: dict = {}
    for table in soup.find_all("table"):
        text = clean_text(table.get_text())
        if "主要属性" not in text and "生命值骰" not in text:
            continue
        # 逐行逐单元格扫描
        for tr in table.find_all("tr"):
            cells = [clean_text(c.get_text()) for c in tr.find_all(["td", "th"])]
            row_text = " ".join(cells)
            # 匹配"标签 + 值"对，标签可能是中文+英文
            for label, key in [
                ("主要属性", "primaryAbility"),
                ("生命值骰", "hitDie"),
                ("豁免熟练", "savingThrows"),
                ("技能熟练", "skills"),
                ("武器熟练", "weaponProficiency"),
                ("护甲受训", "armorProficiency"),
                ("施法属性", "spellcasting"),
            ]:
                m = re.search(
                    rf"{label}[A-Za-z\s]*\s+(?:(?!{label})(?!生命值骰)(?!豁免熟练)(?!技能熟练)(?!武器熟练)(?!护甲受训)(?!施法属性).)+",
                    row_text,
                )
                if m:
                    val = m.group(0).replace(label, "", 1)
                    # 去掉英文标签残留
                    val = re.sub(r"^[A-Za-z\s]+", "", val).strip()
                    if val and key not in structured:
                        structured[key] = val
        break
    return structured


def extract_classes() -> list:
    items = []
    base = PHB_ROOT / "角色职业"
    for cls in CLASS_DIRS:
        path = base / cls / f"{cls}.htm"
        if not path.exists():
            continue
        html = read_html(path)
        soup = BeautifulSoup(html, "html.parser")
        h1 = soup.find("h1")
        if not h1:
            continue
        name, en_name = split_title(h1.get_text())
        if not name:
            continue

        # 从核心特质表提取结构化字段
        structured = _parse_class_core_table(soup)

        # 收集职业特性（以"1级："/"2级："等开头的段落）
        features: list[str] = []
        desc = ""
        for p in soup.find_all("p"):
            ptext = clean_text(p.get_text())
            if not ptext:
                continue
            # 职业特性段落："N级：特性名 EnglishName 描述..."
            if re.match(r"^\d+级[：:]", ptext):
                features.append(ptext)
                continue
            # 背景描述：第一个长段落（不含核心特质表内容）
            if not desc and len(ptext) > 80 and "核心特质" not in ptext and "特性表" not in ptext:
                desc = ptext

        if not desc:
            desc = f"{name} 是 D&D 中的一个可玩职业。"

        # 职业特性拼到描述里
        if features:
            desc = desc + "\n\n【职业特性】\n" + "\n".join(features)
            structured["features"] = features

        slug = (en_name or name).lower().replace(" ", "-")
        items.append({
            "type": "class",
            "slug": slug,
            "name": name,
            "description": desc,
            "structured": structured,
            "tags": [],
            "sourceLabel": "玩家手册 2024",
            "schemaVersion": 2,
        })
    return items


# ============================ 背景提取 ============================
def extract_backgrounds() -> list:
    items = []
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
        text = clean_text(soup.get_text())
        structured = {}
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

        desc = ""
        for p in soup.find_all("p"):
            ptext = clean_text(p.get_text())
            if "属性值" not in ptext and len(ptext) > 30:
                desc = ptext
                break
        if not desc:
            desc = f"{name} 是 D&D 中的一个角色背景。"

        slug = (en_name or name).lower().replace(" ", "-")
        items.append({
            "type": "background",
            "slug": slug,
            "name": name,
            "description": desc,
            "structured": structured,
            "tags": [],
            "sourceLabel": "玩家手册 2024",
            "schemaVersion": 2,
        })
    return items


def main():
    out_dir = Path("private-imports")
    out_dir.mkdir(exist_ok=True)
    out_path = out_dir / "phb-2024-index.content.private.json"

    spells = extract_spells()
    feats = extract_feats()
    equipment = extract_equipment()
    species = extract_species()
    classes = extract_classes()
    backgrounds = extract_backgrounds()

    all_items = spells + feats + equipment + species + classes + backgrounds
    # 去重 slug
    seen = set()
    deduped = []
    for it in all_items:
        key = (it["type"], it["slug"])
        if key in seen:
            it["slug"] = it["slug"] + "-" + str(len(seen))
        seen.add((it["type"], it["slug"]))
        deduped.append(it)

    package = {
        "name": "玩家手册 2024 内置资料",
        "version": "2024.1.0",
        "schemaVersion": 2,
        "locale": "zh-CN",
        "items": deduped,
    }
    out_path.write_text(json.dumps(package, ensure_ascii=False, indent=2), encoding="utf-8")

    # 统计
    by_type = {}
    for it in deduped:
        by_type[it["type"]] = by_type.get(it["type"], 0) + 1
    summary = ", ".join(f"{k}: {v}" for k, v in sorted(by_type.items()))
    print(f"Extracted {len(deduped)} items ({summary})")
    print(f"Written to {out_path}")

    # 抽样打印前 3 个法术验证
    print("\n=== Sample spells ===")
    for s in spells[:3]:
        st = s["structured"]
        print(f"- {s['name']} ({st.get('levelLabel', '?')} · {st.get('school', '?')})")
        print(f"  施法时间: {st.get('castingTime', '?')}")
        print(f"  射程: {st.get('range', '?')}")
        print(f"  成分: {st.get('components', '?')}")
        print(f"  持续: {st.get('duration', '?')}")
        print(f"  desc: {s['description'][:80]}...")


if __name__ == "__main__":
    main()
