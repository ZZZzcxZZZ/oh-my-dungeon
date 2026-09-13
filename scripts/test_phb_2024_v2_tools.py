from __future__ import annotations

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import extract_phb_2024_v2 as extractor


REPO_ROOT = Path(__file__).resolve().parent.parent
ARCHIVE_PATH = (
    REPO_ROOT
    / "apps"
    / "client_flutter"
    / "assets"
    / "rules"
    / "dnd5e-2024.rules.json"
)

ABILITY_KEYS = {"str", "dex", "con", "int", "wis", "cha"}
STANDARD_HIT_DIE_FACES = {4, 6, 8, 10, 12}


def _sparse_at(table: dict[str, int], level: int) -> int | None:
    """稀疏表取值语义：低于最早声明等级 → None；否则沿用不高于 [level] 的最后声明值。"""
    keys = sorted(int(key) for key in table)
    if not keys or level < keys[0]:
        return None
    found = keys[0]
    for key in keys:
        if key > level:
            break
        found = key
    return table[str(found)]

# 12 条实测技能选择原文（PHB 2024 中文版核心特质表）。
SKILL_CHOICE_TEXTS = {
    "战士": "选择2项：特技、驯兽、运动、历史、洞悉、威吓、游说、察觉、求生",
    "法师": "选择2项：奥秘、历史、洞悉、调查、医疗、自然、宗教",
    "魔契师": "选择2项：奥秘、欺瞒、历史、威吓、调查、自然或宗教",
    "游侠": "选择3项：驯兽、运动、洞悉、调查、自然、察觉、隐匿、求生",
    "圣武士": "选择2项：运动、洞悉、威吓、医疗、游说、宗教",
    "术士": "选择2项：奥秘、欺瞒、洞悉、威吓、游说、宗教",
    "吟游诗人": "任选3项（见第一章）",
    "德鲁伊": "选择2项：奥秘、驯兽、洞悉、医疗、自然、察觉、宗教、求生",
    "牧师": "选择2项：历史、洞悉、医药、游说、宗教",
    "游荡者": "选择4项：特技、运动、欺瞒、洞悉、威吓、调查、察觉、游说、巧手、隐匿",
    "野蛮人": "选择2项：驯兽、运动、威吓、自然、察觉、求生",
    "武僧": "选择2项：特技、运动、历史、洞悉、宗教、隐匿",
}

# 期望值是**档案规范名**（不是源文译名）：解析结果必须已过 SKILL_NAME_ALIASES。
EXPECTED_SKILL_CHOICES = {
    "战士": (2, ["杂技", "驯兽", "运动", "历史", "洞悉", "威吓", "说服", "察觉", "求生"]),
    "法师": (2, ["奥秘", "历史", "洞悉", "调查", "医药", "自然", "宗教"]),
    "魔契师": (2, ["奥秘", "欺瞒", "历史", "威吓", "调查", "自然", "宗教"]),
    "游侠": (3, ["驯兽", "运动", "洞悉", "调查", "自然", "察觉", "隐匿", "求生"]),
    "圣武士": (2, ["运动", "洞悉", "威吓", "医药", "说服", "宗教"]),
    "术士": (2, ["奥秘", "欺瞒", "洞悉", "威吓", "说服", "宗教"]),
    "吟游诗人": (
        3,
        [
            "杂技",
            "驯兽",
            "奥秘",
            "运动",
            "欺瞒",
            "历史",
            "洞悉",
            "威吓",
            "调查",
            "医药",
            "自然",
            "察觉",
            "表演",
            "说服",
            "宗教",
            "巧手",
            "隐匿",
            "求生",
        ],
    ),
    "德鲁伊": (2, ["奥秘", "驯兽", "洞悉", "医药", "自然", "察觉", "宗教", "求生"]),
    "牧师": (2, ["历史", "洞悉", "医药", "说服", "宗教"]),
    "游荡者": (4, ["杂技", "运动", "欺瞒", "洞悉", "威吓", "调查", "察觉", "说服", "巧手", "隐匿"]),
    "野蛮人": (2, ["驯兽", "运动", "威吓", "自然", "察觉", "求生"]),
    "武僧": (2, ["杂技", "运动", "历史", "洞悉", "宗教", "隐匿"]),
}


def _read_archive() -> dict:
    """读内置档案。

    档案资产被 git 跟踪、也在 `pubspec.yaml` 的 assets 里，**不存在**"裸检出无资产"
    的正常场景，因此这里不返回 None、调用方也不 skip：文件缺失就是要报的真实失败
    （此前 `skipTest` 会把提取器与档案的漂移静默掩盖成"跳过"）。
    """
    return json.loads(ARCHIVE_PATH.read_text(encoding="utf-8"))


def _archive_skill_names(archive: dict) -> list[str]:
    return [str(skill["name"]) for skill in archive["skills"]]


PHB_BUNDLE_PATH = REPO_ROOT / "private-imports" / "phb-2024-v2-bundle.json"


def _require_private_phb_source() -> None:
    """私有 PHB 源（`private-imports/`，被 gitignore）缺失时跳过提取测试。

    公开 CI 不携带商业规则书内容，所以提取类测试在 CI 上**跳过**而不是失败；
    本地有私有源时必须照常运行并照常报错——跳过条件只看目录是否存在，
    不看任何"能否跑通"的迹象，避免把真实故障掩盖成跳过。
    """
    if not extractor.PHB_ROOT.exists():
        raise unittest.SkipTest(
            f"私有 PHB 2024 源不存在，跳过提取测试：{extractor.PHB_ROOT}"
        )


class Phb2024V2ToolsTest(unittest.TestCase):
    def setUp(self) -> None:
        extractor.MANUAL_REVIEW.clear()

    def _extract_all_classes(self) -> dict[str, dict]:
        _require_private_phb_source()
        # extract_class 用全局 SLUG_SEEN 做 slug 去重，逐职业提取前必须清空。
        extractor.SLUG_SEEN.clear()
        extractor.CLASS_ENTRY_SLUGS.clear()
        classes: dict[str, dict] = {}
        for cls_name in extractor.CLASS_DIRS:
            entry, _, _ = extractor.extract_class(cls_name)
            self.assertIsNotNone(entry, cls_name)
            classes[cls_name] = entry
        return classes

    def test_background_skills_are_parsed_into_proficiency_grants(self) -> None:
        """背景技能由 `rules.grants` 承载（决策 D10），不再依赖客户端的中文名预设。

        源文的技能串用 `与` / `和` / `、`，且含译名差异（特技→杂技、游说→说服、
        医疗→医药）。未知名字必须**记入 MANUAL_REVIEW 并跳过**：放行未知名字会变成
        运行期永不生效的静默 no-op（客户端的 `skill:<名>` 只认档案规范名）。
        """
        self.assertEqual(
            extractor.parse_fixed_skills("洞悉与宗教"), ["洞悉", "宗教"]
        )
        self.assertEqual(
            extractor.parse_fixed_skills("驯兽和自然"), ["驯兽", "自然"]
        )
        self.assertEqual(
            extractor.parse_fixed_skills("特技和察觉"), ["杂技", "察觉"]
        )
        self.assertEqual(
            extractor.parse_fixed_skills("游说、医疗"), ["说服", "医药"]
        )
        # 去重：同一个技能写两次只授一次。
        self.assertEqual(
            extractor.parse_fixed_skills("隐匿和隐匿"), ["隐匿"]
        )
        # 未知名字：跳过 + 记账，不静默。
        self.assertEqual(
            extractor.parse_fixed_skills("未知技能和察觉"), ["察觉"]
        )
        self.assertEqual(
            [item["type"] for item in extractor.MANUAL_REVIEW],
            ["unknown-background-skill-name"],
        )
        self.assertEqual(extractor.MANUAL_REVIEW[0]["raw"], "未知技能")

    def test_spell_level_bands_track_unlock_levels(self) -> None:
        """`maximumSpellLevel` → 环阶解锁点（决策 D8 的"环阶带"）。"""
        self.assertEqual(
            extractor.spell_level_bands({"1": 1, "3": 2, "5": 3}),
            [(1, 1), (2, 3), (3, 5)],
        )
        # 0 / 缺失 = 未解锁；取值重复的等级不重复生成。
        self.assertEqual(
            extractor.spell_level_bands({"1": 0, "2": 1, "3": 1, "5": 2}),
            [(1, 2), (2, 5)],
        )
        self.assertEqual(extractor.spell_level_bands({}), [])
        self.assertEqual(extractor.spell_level_bands([1, 2, 3]), [])

    def test_extracted_spellcasters_emit_spell_choices(self) -> None:
        """8 个施法职业都产出 `optionType: "spell"` 的选择（决策 D8）。

        - 每个施法者一条戏法选择（`maximumOptionLevel: 0` + `countsToward: "cantrips"`）；
        - 每个"环阶解锁点"一条（`maximumOptionLevel` = 该环阶，`countsToward: "prepared"`）；
        - `optionTags` 必须等于 `spellcasting.listTags`（否则运行期选不到任何法术）。
        """
        _require_private_phb_source()
        extractor.SLUG_SEEN.clear()
        extractor.CLASS_ENTRY_SLUGS.clear()
        checked = 0
        for cls_name in extractor.CLASS_DIRS:
            entry, _, _ = extractor.extract_class(cls_name)
            self.assertIsNotNone(entry, cls_name)
            structured = entry.get("structured") or {}
            spellcasting = (structured.get("classRules") or {}).get("spellcasting")
            choices = [
                choice
                for step in (entry.get("rules") or {}).get("progression", [])
                for choice in step.get("choices", [])
                if choice.get("optionType") == "spell"
            ]
            if not spellcasting:
                self.assertEqual(choices, [], cls_name)
                continue
            checked += 1
            list_tags = spellcasting.get("listTags")
            cantrips = [c for c in choices if c.get("maximumOptionLevel") == 0]
            self.assertEqual(len(cantrips), 1, cls_name)
            self.assertEqual(cantrips[0]["countsToward"], "cantrips", cls_name)
            self.assertEqual(cantrips[0]["optionTags"], list_tags, cls_name)
            bands = extractor.spell_level_bands(spellcasting.get("maximumSpellLevel"))
            levelled = [c for c in choices if c.get("maximumOptionLevel") != 0]
            self.assertEqual(
                [c["maximumOptionLevel"] for c in levelled],
                [band[0] for band in bands],
                cls_name,
            )
            for choice in levelled:
                self.assertEqual(choice["countsToward"], "prepared", cls_name)
                self.assertEqual(choice["optionTags"], list_tags, cls_name)
        self.assertEqual(checked, 8, "8 个施法职业都应产出法术选择")

    def test_extracted_backgrounds_declare_skill_grants(self) -> None:
        """真实源文里 16 个背景都必须产出 `skill:<档案规范名>` 的熟练 grant。"""
        _require_private_phb_source()
        backgrounds = extractor.extract_backgrounds()
        self.assertGreaterEqual(len(backgrounds), 16)
        checked = 0
        for entry in backgrounds:
            skills = extractor.parse_fixed_skills(
                str((entry.get("structured") or {}).get("skills", ""))
            )
            if not skills:
                continue
            checked += 1
            grants = (entry.get("rules") or {}).get("grants") or []
            self.assertEqual(
                [grant["target"] for grant in grants],
                [f"skill:{name}" for name in skills],
                entry["id"],
            )
            for grant in grants:
                self.assertEqual(grant["kind"], "proficiency", entry["id"])
                self.assertIn(
                    grant["target"].removeprefix("skill:"),
                    extractor.ALL_SKILLS,
                    entry["id"],
                )
        self.assertGreaterEqual(checked, 16, "至少 16 个背景带技能熟练")
        self.assertEqual(
            [item for item in extractor.MANUAL_REVIEW],
            [],
            "真实源文的背景技能名必须全部收敛到档案规范名",
        )

    def test_feature_alias_matches_translation_variant(self) -> None:
        self.assertEqual(
            extractor._match_feature_slug(
                "奥术化神",
                {"奥术登神": "arcane-apotheosis"},
            ),
            "arcane-apotheosis",
        )

    def test_parse_skill_choice_reads_all_twelve_classes(self) -> None:
        archive = _read_archive()
        canonical = _archive_skill_names(archive)
        self.assertEqual(len(canonical), 18)
        canonical_set = set(canonical)

        self.assertEqual(set(SKILL_CHOICE_TEXTS), set(EXPECTED_SKILL_CHOICES))
        for cls_name, text in SKILL_CHOICE_TEXTS.items():
            with self.subTest(cls=cls_name):
                expected_count, expected_options = EXPECTED_SKILL_CHOICES[cls_name]
                parsed = extractor.parse_skill_choice(text)
                self.assertIsNotNone(parsed, text)
                self.assertEqual(parsed["count"], expected_count)
                self.assertEqual(parsed["options"], expected_options)
                # 逐条对齐档案规范名集合（集合从资产文件读出，不写死副本）。
                for option in parsed["options"]:
                    self.assertIn(option, canonical_set, f"{cls_name}: {option}")
        # 吟游诗人「任选3项（见第一章）」= 恰好 18 个档案规范名。
        bard = extractor.parse_skill_choice(SKILL_CHOICE_TEXTS["吟游诗人"])
        self.assertEqual(len(bard["options"]), 18)
        self.assertEqual(sorted(bard["options"]), sorted(canonical))
        # 源文译名必须收敛到档案规范名。
        self.assertEqual(
            extractor.parse_skill_choice("选择1项：特技")["options"], ["杂技"]
        )
        self.assertEqual(
            extractor.parse_skill_choice("选择1项：游说")["options"], ["说服"]
        )
        self.assertEqual(
            extractor.parse_skill_choice("选择1项：医疗")["options"], ["医药"]
        )
        # 魔契师「自然或宗教」必须切成两项，不得残留原文。
        warlock = extractor.parse_skill_choice(SKILL_CHOICE_TEXTS["魔契师"])
        self.assertIn("宗教", warlock["options"])
        self.assertNotIn("自然或宗教", warlock["options"])
        # 解析不出 N 项时返回 None，不造占位。
        self.assertIsNone(extractor.parse_skill_choice("任意技能"))

    def test_unknown_skill_name_is_recorded_and_preserved(self) -> None:
        """映射后仍不在规范清单里的名字不静默保留：记 MANUAL_REVIEW 且原样输出。"""
        parsed = extractor.parse_skill_choice("选择2项：杂技、不存在技能")
        self.assertEqual(parsed["options"], ["杂技", "不存在技能"])
        self.assertEqual(len(extractor.MANUAL_REVIEW), 1)
        self.assertEqual(extractor.MANUAL_REVIEW[0]["raw"], "不存在技能")

    def test_class_core_rules_match_builtin_archive(self) -> None:
        """12 职业的 hitDie / 豁免熟练必须与内置档案逐项一致。

        档案是 tier 0 规范值；提取器与档案任一侧改错（例如武僧豁免曾是
        dex/wis，源文与 SRD 5.2 都是 str/dex）都必须被这条检查发现。
        """
        archive = _read_archive()
        classes = self._extract_all_classes()
        self.assertEqual(len(classes), len(extractor.CLASS_DIRS))
        for cls_name, entry in classes.items():
            slug = entry["slug"]
            with self.subTest(cls=cls_name):
                archive_class = archive["classes"][slug]
                class_rules = entry["structured"]["classRules"]
                self.assertEqual(class_rules["hitDie"], archive_class["hitDie"], slug)
                # §3.2 未定义 `savingThrowAbilities` 的顺序：Dart 侧按集合比，
                # 这里也必须按集合比，否则提取器换个书写顺序就会被误判成失败。
                self.assertEqual(
                    set(class_rules["savingThrowAbilities"]),
                    set(archive_class["savingThrowAbilities"]),
                    slug,
                )

    def test_real_corpus_leaves_manual_review_empty(self) -> None:
        """真实语料跑完 12 职业后 `MANUAL_REVIEW` 必须为空。

        这是「未映射技能名不静默保留」的出口：`parse_skill_choice` 对不在规范清单里
        的名字既记 MANUAL_REVIEW 又原样输出，如果只断言"记录了"而不检查真实语料跑完
        之后的清单，译名漂移会一直留在 MANUAL_REVIEW 里没人处理。
        """
        classes = self._extract_all_classes()
        self.assertEqual(len(classes), len(extractor.CLASS_DIRS))
        for cls_name, text in SKILL_CHOICE_TEXTS.items():
            with self.subTest(cls=cls_name):
                extractor.parse_skill_choice(text)
        self.assertEqual(
            extractor.MANUAL_REVIEW,
            [],
            f"真实语料仍有未映射技能名：{extractor.MANUAL_REVIEW}",
        )

    def test_parse_saving_throws_keeps_source_order(self) -> None:
        self.assertEqual(extractor.parse_saving_throws("力量与体质"), ["str", "con"])
        self.assertEqual(extractor.parse_saving_throws("感知与魅力"), ["wis", "cha"])
        self.assertEqual(extractor.parse_saving_throws("力量与敏捷"), ["str", "dex"])
        # 顺序按中文在原字符串里出现的先后，而非属性表顺序。
        self.assertEqual(extractor.parse_saving_throws("魅力与力量"), ["cha", "str"])

    def test_weapon_entries_declare_ability_and_finesse(self) -> None:
        _require_private_phb_source()
        weapons = {
            entry["name"]: entry["structured"]
            for entry in extractor.extract_equipment()
            if "damage" in entry["structured"]
        }
        self.assertEqual(weapons["长弓"]["ability"], "dex")
        self.assertNotIn("finesse", weapons["长弓"])
        self.assertIs(weapons["匕首"]["finesse"], True)
        self.assertNotIn("ability", weapons["匕首"])
        self.assertNotIn("ability", weapons["手斧"])
        self.assertNotIn("finesse", weapons["手斧"])

    def test_real_wizard_entry_declares_spell_selection_progression(self) -> None:
        _require_private_phb_source()
        extractor.SLUG_SEEN.clear()
        extractor.CLASS_ENTRY_SLUGS.clear()

        class_entry, _, _ = extractor.extract_class("法师")

        spellcasting = class_entry["structured"]["classRules"]["spellcasting"]
        self.assertEqual(spellcasting["ability"], "int")
        self.assertEqual(spellcasting["listTags"], ["spell-list:wizard"])
        self.assertEqual(spellcasting["archetype"], "full-caster")
        self.assertEqual(spellcasting["prepared"]["1"], 4)
        self.assertEqual(spellcasting["cantrips"]["1"], 3)
        self.assertEqual(spellcasting["maximumSpellLevel"]["1"], 1)

    def test_class_entries_use_structured_rules(self) -> None:
        """职业条目只允许新契约形状，不得残留散文与逐级 grant。"""
        classes = self._extract_all_classes()
        self.assertEqual(len(classes), len(extractor.CLASS_DIRS))

        for cls_name, entry in classes.items():
            with self.subTest(cls=cls_name):
                structured = entry["structured"]
                for forbidden in (
                    "hitDie",
                    "savingThrows",
                    "skills",
                    "preparedSpellcasting",
                    "spellcastingAbility",
                    "spellcasting",
                ):
                    self.assertNotIn(forbidden, structured)

                class_rules = structured["classRules"]
                self.assertIsInstance(class_rules["hitDie"], int)
                self.assertIn(class_rules["hitDie"], STANDARD_HIT_DIE_FACES)

                saving_throws = class_rules["savingThrowAbilities"]
                self.assertIsInstance(saving_throws, list)
                self.assertEqual(len(saving_throws), 2)
                for ability in saving_throws:
                    self.assertIsInstance(ability, str)
                    self.assertIn(ability, ABILITY_KEYS)

                rules_text = json.dumps(entry.get("rules") or {}, ensure_ascii=False)
                self.assertNotIn("spellSlot:", rules_text)
                self.assertNotIn("classResource:", rules_text)
                self.assertNotIn('"level":', rules_text)

                progression = entry["rules"]["progression"]
                self.assertTrue(progression)
                for step in progression:
                    self.assertIn("levels", step)
                    self.assertNotIn("level", step)
                    self.assertTrue(step["levels"])

                skill_choices = [
                    choice
                    for step in progression
                    for choice in step.get("choices", [])
                    if choice.get("optionType") == "skill"
                ]
                self.assertEqual(len(skill_choices), 1)
                skill = skill_choices[0]
                self.assertGreater(skill["minimum"], 0)
                self.assertEqual(skill["minimum"], skill["maximum"])
                self.assertTrue(skill["options"])

    def test_spellcasting_tables_match_builtin_archive(self) -> None:
        """12 职业的施法表与原型的派生数值必须与内置档案逐级一致。

        这是「法术位数值只存在于客户端内置档案」的回归保护，也是 archetype
        取值（pact/half-caster/full-caster）的独立判据：原型名一改，
        `maximumSpellLevel` 就会与档案对不上。
        """
        archive = json.loads(ARCHIVE_PATH.read_text(encoding="utf-8"))
        classes = self._extract_all_classes()
        casting = 0
        for cls_name, entry in classes.items():
            slug = entry["slug"]
            spellcasting = entry["structured"]["classRules"].get("spellcasting")
            if spellcasting is None:
                continue
            casting += 1
            archive_class = archive["classes"][slug]
            with self.subTest(cls=cls_name):
                self.assertEqual(
                    spellcasting["archetype"],
                    archive_class["spellcasting"]["archetype"],
                )
                references = {
                    "prepared": archive_class["spellcasting"]["prepared"],
                    "cantrips": archive_class["spellcasting"]["cantrips"],
                    "maximumSpellLevel": archive["progressions"][
                        spellcasting["archetype"]
                    ]["maximumSpellLevel"],
                }
                for field, reference in references.items():
                    for level in range(1, 21):
                        self.assertEqual(
                            _sparse_at(spellcasting[field], level),
                            reference[level - 1],
                            f"{slug}.{field} L{level}",
                        )
        self.assertEqual(casting, 8)

    def test_spell_list_tags_use_extracted_class_slugs(self) -> None:
        extractor.CLASS_ENTRY_SLUGS.clear()
        extractor.CLASS_ENTRY_SLUGS.update({"法师": "wizard", "牧师": "cleric"})

        self.assertEqual(
            extractor._spell_list_tags(["牧师", "法师", "不存在"]),
            ["spell-list:cleric", "spell-list:wizard"],
        )

    def test_sorcerer_subclass_titles_are_not_extracted_from_whole_page_text(self) -> None:
        _require_private_phb_source()
        extractor.SLUG_SEEN.clear()
        _, _, subclasses = extractor.extract_class("术士")

        self.assertGreaterEqual(len(subclasses), 2)
        for subclass in subclasses:
            self.assertLess(
                len(subclass["name"]),
                100,
                f"subclass title is implausibly long: {subclass['id']}",
            )
            self.assertLessEqual(len(subclass["slug"]), 60)

    def test_class_features_link_to_their_owner_by_relation(self) -> None:
        """职业特性必须用 `featureOf` **关系**挂回宿主，不能只写 structured 元数据。

        客户端 `content_detail_page` 按 `relations[].type == 'featureOf'` 过滤职业特性列表；
        `structured.featureOf` / `classSlug` / `subclassName` / `levelLabel` 在客户端
        没有任何读者，属"同一概念的第二种形状"，提取器不得再输出。
        """
        _require_private_phb_source()
        dead_keys = {"featureOf", "classSlug", "subclassName", "levelLabel"}
        # extract_class 用全局 SLUG_SEEN 做 slug 去重，逐职业提取前必须清空。
        extractor.SLUG_SEEN.clear()
        extractor.CLASS_ENTRY_SLUGS.clear()

        entries: list[dict] = []
        features: list[dict] = []
        for cls_name in extractor.CLASS_DIRS:
            entry, class_features, subclasses = extractor.extract_class(cls_name)
            self.assertIsNotNone(entry, cls_name)
            entries.append(entry)
            entries.extend(subclasses)
            features.extend(class_features)
            entries.extend(class_features)

        entry_ids = {entry["id"] for entry in entries}
        self.assertEqual(len(entry_ids), len(entries), "条目 id 必须唯一")
        self.assertTrue(features, "至少应提取出职业特性")

        for entry in entries:
            with self.subTest(entry=entry["id"]):
                structured = entry.get("structured") or {}
                self.assertFalse(
                    dead_keys & set(structured),
                    f"{entry['id']} 仍输出死元数据：{sorted(dead_keys & set(structured))}",
                )

        linked_classes: set[str] = set()
        for feature in features:
            with self.subTest(feature=feature["id"]):
                relations = feature.get("relations") or []
                targets = [
                    relation["targetId"]
                    for relation in relations
                    if relation.get("type") == "featureOf"
                ]
                self.assertEqual(
                    len(targets),
                    1,
                    f"{feature['id']} 必须恰好有一条 featureOf 关系，实际 {targets}",
                )
                self.assertIn(
                    targets[0],
                    entry_ids,
                    f"{feature['id']} 的 featureOf 目标不存在：{targets[0]}",
                )
                linked_classes.add(targets[0])

        # 12 个核心职业都必须能通过关系找到自己的特性（否则资料库职业页特性列表为空）。
        class_ids = {entry["id"] for entry in entries if entry["type"] == "class"}
        self.assertEqual(len(class_ids), 12)
        self.assertEqual(
            class_ids - linked_classes,
            set(),
            "下列职业没有任何特性挂在它下面",
        )

    def test_validator_passes_with_gbk_console_encoding(self) -> None:
        if not PHB_BUNDLE_PATH.exists():
            self.skipTest(f"私有 bundle 不存在，跳过校验器端到端测试：{PHB_BUNDLE_PATH}")
        environment = os.environ.copy()
        environment["PYTHONIOENCODING"] = "gbk"
        result = subprocess.run(
            [sys.executable, "scripts/validate_phb_2024_v2.py"],
            cwd=REPO_ROOT,
            env=environment,
            capture_output=True,
            text=True,
            encoding="gbk",
            errors="replace",
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("RESULT: PASS", result.stdout)


if __name__ == "__main__":
    unittest.main()
