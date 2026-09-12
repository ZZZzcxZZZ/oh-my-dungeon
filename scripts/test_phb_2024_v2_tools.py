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

EXPECTED_SKILL_CHOICES = {
    "战士": (2, ["特技", "驯兽", "运动", "历史", "洞悉", "威吓", "游说", "察觉", "求生"]),
    "法师": (2, ["奥秘", "历史", "洞悉", "调查", "医疗", "自然", "宗教"]),
    "魔契师": (2, ["奥秘", "欺瞒", "历史", "威吓", "调查", "自然", "宗教"]),
    "游侠": (3, ["驯兽", "运动", "洞悉", "调查", "自然", "察觉", "隐匿", "求生"]),
    "圣武士": (2, ["运动", "洞悉", "威吓", "医疗", "游说", "宗教"]),
    "术士": (2, ["奥秘", "欺瞒", "洞悉", "威吓", "游说", "宗教"]),
    "吟游诗人": (3, list(extractor.ALL_SKILLS)),
    "德鲁伊": (2, ["奥秘", "驯兽", "洞悉", "医疗", "自然", "察觉", "宗教", "求生"]),
    "牧师": (2, ["历史", "洞悉", "医药", "游说", "宗教"]),
    "游荡者": (4, ["特技", "运动", "欺瞒", "洞悉", "威吓", "调查", "察觉", "游说", "巧手", "隐匿"]),
    "野蛮人": (2, ["驯兽", "运动", "威吓", "自然", "察觉", "求生"]),
    "武僧": (2, ["特技", "运动", "历史", "洞悉", "宗教", "隐匿"]),
}


class Phb2024V2ToolsTest(unittest.TestCase):
    def setUp(self) -> None:
        extractor.MANUAL_REVIEW.clear()

    def _extract_all_classes(self) -> dict[str, dict]:
        # extract_class 用全局 SLUG_SEEN 做 slug 去重，逐职业提取前必须清空。
        extractor.SLUG_SEEN.clear()
        extractor.CLASS_ENTRY_SLUGS.clear()
        classes: dict[str, dict] = {}
        for cls_name in extractor.CLASS_DIRS:
            entry, _, _ = extractor.extract_class(cls_name)
            self.assertIsNotNone(entry, cls_name)
            classes[cls_name] = entry
        return classes

    def test_feature_alias_matches_translation_variant(self) -> None:
        self.assertEqual(
            extractor._match_feature_slug(
                "奥术化神",
                {"奥术登神": "arcane-apotheosis"},
            ),
            "arcane-apotheosis",
        )

    def test_parse_skill_choice_reads_all_twelve_classes(self) -> None:
        self.assertEqual(set(SKILL_CHOICE_TEXTS), set(EXPECTED_SKILL_CHOICES))
        for cls_name, text in SKILL_CHOICE_TEXTS.items():
            with self.subTest(cls=cls_name):
                expected_count, expected_options = EXPECTED_SKILL_CHOICES[cls_name]
                parsed = extractor.parse_skill_choice(text)
                self.assertIsNotNone(parsed, text)
                self.assertEqual(parsed["count"], expected_count)
                self.assertEqual(parsed["options"], expected_options)
        # 吟游诗人「任选3项（见第一章）」= 任意 3 项技能。
        bard = extractor.parse_skill_choice(SKILL_CHOICE_TEXTS["吟游诗人"])
        self.assertEqual(bard["options"], extractor.ALL_SKILLS)
        # 魔契师「自然或宗教」必须切成两项，不得残留原文。
        warlock = extractor.parse_skill_choice(SKILL_CHOICE_TEXTS["魔契师"])
        self.assertIn("宗教", warlock["options"])
        self.assertNotIn("自然或宗教", warlock["options"])
        # 解析不出 N 项时返回 None，不造占位。
        self.assertIsNone(extractor.parse_skill_choice("任意技能"))

    def test_parse_saving_throws_keeps_source_order(self) -> None:
        self.assertEqual(extractor.parse_saving_throws("力量与体质"), ["str", "con"])
        self.assertEqual(extractor.parse_saving_throws("感知与魅力"), ["wis", "cha"])
        self.assertEqual(extractor.parse_saving_throws("力量与敏捷"), ["str", "dex"])
        # 顺序按中文在原字符串里出现的先后，而非属性表顺序。
        self.assertEqual(extractor.parse_saving_throws("魅力与力量"), ["cha", "str"])

    def test_weapon_entries_declare_ability_and_finesse(self) -> None:
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

    def test_validator_passes_with_gbk_console_encoding(self) -> None:
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
