from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import extract_phb_2024_v2 as extractor


REPO_ROOT = Path(__file__).resolve().parent.parent


class Phb2024V2ToolsTest(unittest.TestCase):
    def setUp(self) -> None:
        extractor.MANUAL_REVIEW.clear()

    def test_feature_alias_matches_translation_variant(self) -> None:
        self.assertEqual(
            extractor._match_feature_slug(
                "奥术化神",
                {"奥术登神": "arcane-apotheosis"},
            ),
            "arcane-apotheosis",
        )

    def test_warlock_progression_uses_short_rest_pact_slots(self) -> None:
        progression = [{"level": level} for level in range(1, 21)]

        extractor._build_spell_slot_progression(
            "魔契师",
            "warlock",
            progression,
        )

        level_five = progression[4]["grants"]
        self.assertEqual(
            level_five,
            [
                {
                    "id": "pact-magic-slots",
                    "kind": "resource",
                    "label": "契约魔法位（3环）",
                    "target": "classResource:pactMagicSlots",
                    "value": 2,
                    "data": {
                        "recovery": "shortRest",
                        "spellLevel": 3,
                    },
                }
            ],
        )
        self.assertFalse(
            any(
                grant.get("target", "").startswith("spellSlot:")
                for step in progression
                for grant in step.get("grants", [])
            )
        )

    def test_real_warlock_entry_includes_pact_slots(self) -> None:
        extractor.SLUG_SEEN.clear()
        class_entry, _, _ = extractor.extract_class("魔契师")

        self.assertIsNotNone(class_entry)
        level_five = next(
            step
            for step in class_entry["rules"]["progression"]
            if step["level"] == 5
        )
        pact_slot = next(
            grant
            for grant in level_five["grants"]
            if grant["id"] == "pact-magic-slots"
        )
        self.assertEqual(pact_slot["value"], 2)
        self.assertEqual(pact_slot["data"]["spellLevel"], 3)
        self.assertEqual(pact_slot["data"]["recovery"], "shortRest")

    def test_real_wizard_entry_declares_spell_selection_progression(self) -> None:
        extractor.SLUG_SEEN.clear()
        extractor.CLASS_ENTRY_SLUGS.clear()

        class_entry, _, _ = extractor.extract_class("法师")

        spellcasting = class_entry["structured"]["spellcasting"]
        self.assertEqual(spellcasting["ability"], "int")
        self.assertEqual(spellcasting["listTags"], ["spell-list:wizard"])
        level_one = next(
            row for row in spellcasting["progression"] if row["level"] == 1
        )
        self.assertEqual(level_one["maximumSpellLevel"], 1)
        self.assertEqual(level_one["maximumCantrips"], 3)
        self.assertEqual(level_one["maximumLeveledSpells"], 4)

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
