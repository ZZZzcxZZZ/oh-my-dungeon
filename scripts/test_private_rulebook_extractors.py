from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import extract_dmg_2024_items as dmg
import extract_monster_manual_private as mm


class MonsterManualExtractorTest(unittest.TestCase):
    def test_parses_stat_block_and_character_markdown_from_fixture(self) -> None:
        html = """
        <div class="stat-block">
          <h5>测试丧尸 Test Zombie</h5>
          <div class="sub-line">中型亡灵，中立邪恶</div>
          <table>
            <tr><td><strong>AC </strong>8</td><td><strong>先攻 </strong>-2（8）</td></tr>
            <tr><td><strong>HP </strong>15（2d8+6）</td></tr>
            <tr><td><strong>速度 </strong>20尺</td></tr>
          </table>
          <table class="stat-abilities">
            <tr><td><strong>力量</strong></td><td>13</td><td>+1</td><td>+1</td>
                <td><strong>敏捷</strong></td><td>6</td><td>-2</td><td>-2</td>
                <td><strong>体质</strong></td><td>16</td><td>+3</td><td>+3</td></tr>
            <tr><td><strong>智力</strong></td><td>3</td><td>-4</td><td>-4</td>
                <td><strong>感知</strong></td><td>6</td><td>-2</td><td>-2</td>
                <td><strong>魅力</strong></td><td>5</td><td>-3</td><td>-3</td></tr>
          </table>
          <table>
            <tr><td><strong>感官 </strong>黑暗视觉60尺；被动察觉8</td></tr>
            <tr><td><strong>语言 </strong>理解通用语但不会说</td></tr>
            <tr><td><strong>CR </strong>1/4（XP 50；PB+2）</td></tr>
          </table>
          <p>腐朽的尸体被死灵能量驱动。</p>
          <h6>特质 Traits</h6>
          <p><strong>不死坚韧 Undead Fortitude。</strong>测试正文。</p>
          <h6>动作 Actions</h6>
          <p><strong>猛击 Slam。</strong>命中：5（1d8+1）钝击伤害。</p>
        </div>
        """

        monsters = mm.parse_monsters(html, source_path="fixture.htm")

        self.assertEqual(len(monsters), 1)
        monster = monsters[0]
        self.assertEqual(monster.name, "测试丧尸")
        self.assertEqual(monster.armor_class, 8)
        self.assertEqual(monster.hit_points, 15)
        self.assertEqual(monster.hit_point_formula, "2d8+6")
        self.assertEqual(monster.abilities["con"], 16)
        self.assertEqual(monster.challenge_rating, "1/4")
        self.assertEqual(monster.proficiency_bonus, 2)
        self.assertEqual(monster.description, "腐朽的尸体被死灵能量驱动。")
        self.assertIn("不死坚韧", monster.sections["特质"])
        markdown = mm.character_markdown(monster)
        self.assertIn("format: dnd-table-character/v2", markdown)
        self.assertIn("revision: 1", markdown)
        self.assertIn("contentHash: sha256:", markdown)
        self.assertIn("kind: monster", markdown)
        self.assertIn("## 描述", markdown)
        self.assertIn("## 怪物资料", markdown)
        self.assertNotIn("## 感官与语言", markdown)
        self.assertIn("### 不死坚韧", markdown)
        entry = mm.content_entry(monster, "test-zombie")
        self.assertEqual(
            entry["structured"]["classification"]["creatureType"],
            "undead",
        )
        self.assertEqual(
            entry["structured"]["characterTemplate"]["actions"][0]["name"],
            "猛击",
        )
        self.assertEqual(
            entry["structured"]["characterTemplate"]["senses"],
            ["黑暗视觉60尺", "被动察觉8"],
        )
        self.assertEqual(
            entry["structured"]["characterTemplate"]["languages"],
            ["理解通用语但不会说"],
        )
        self.assertEqual(
            entry["structured"]["characterTemplate"]["challenge"]["rating"],
            "1/4",
        )
        self.assertIn(
            {"type": "heading", "level": 3, "text": "不死坚韧"},
            entry["body"],
        )
        self.assertFalse(
            any(
                block.get("type") == "paragraph"
                and block.get("text", "").startswith("###")
                for block in entry["body"]
            ),
        )

    def test_normalizes_bilingual_heading_and_english_size(self) -> None:
        html = """
        <div class="stat-block">
          <h5>恶咒蛇人（1型） Yuan-ti Malison (Type 1)</h5>
          <div class="sub-line">Medium 怪兽，中立邪恶</div>
          <table><tr><td><strong>AC </strong>12</td></tr></table>
          <table class="stat-abilities"><tr><td><strong>力量</strong></td><td>16</td></tr></table>
        </div>
        """

        monster = mm.parse_monsters(html, source_path="fixture.htm")[0]
        entry = mm.content_entry(monster, "yuan-ti-malison-type-1")

        self.assertEqual(monster.name, "恶咒蛇人（1型）")
        self.assertEqual(monster.english_name, "Yuan-ti Malison (Type 1)")
        self.assertEqual(monster.size, "medium")
        self.assertEqual(monster.creature_type, "怪兽")
        self.assertEqual(entry["summary"], "中型 怪兽，中立邪恶")

        self.assertEqual(mm.split_name("矮种马Pony"), ("矮种马", "Pony"))
        self.assertEqual(mm.split_name("狼Wolf"), ("狼", "Wolf"))
        self.assertEqual(
            mm.split_name("鬼火Will-o’-Wisp"),
            ("鬼火", "Will-o’-Wisp"),
        )

    def test_preserves_all_monster_groups_and_flags_ambiguous_content(self) -> None:
        html = """
        <div class="stat-block">
          <h5>测试亡灵法师 Test Undead Mage</h5>
          <div class="sub-line">中型亡灵法师，中立邪恶</div>
          <table><tr><td><strong>AC </strong>13</td><td><strong>HP </strong>27</td></tr></table>
          <table class="stat-abilities"><tr><td><strong>力量</strong></td><td>10</td></tr></table>
          <h6>特质 Traits</h6>
          <p><strong>亡灵本质 Undead Nature。</strong>无需呼吸。</p>
          <h6>动作 Actions</h6>
          <p><strong>枯萎之触 Withering Touch。</strong>命中：+5，造成 2d8+3 黯蚀伤害。</p>
          <h6>附赠动作 Bonus Actions</h6>
          <p><strong>暗影步 Shadow Step。</strong>传送 30 尺。</p>
          <h6>反应 Reactions</h6>
          <p><strong>法术偏转 Spell Deflection。</strong>AC +2。</p>
          <h6>传奇动作 Legendary Actions</h6>
          <p><strong>侦测 Detect。</strong>进行一次感知检定。</p>
          <h6>施法 Spellcasting</h6>
          <p><strong>天生施法 Innate Spellcasting。</strong>施法属性为智力。</p>
          <h6>特殊段落 Odd Section</h6>
          <p><strong>撕咬 Bite。</strong>第一项。<strong>爪击 Claw。</strong>第二项。</p>
        </div>
        """

        monster = mm.parse_monsters(html, source_path="fixture.htm")[0]
        entry = mm.content_entry(monster, "test-undead-mage")
        template = entry["structured"]["characterTemplate"]
        review = mm.build_manual_review([monster])

        self.assertEqual(entry["structured"]["classification"]["creatureType"], "undead")
        self.assertIn("亡灵法师", entry["structured"]["classification"]["tags"])
        self.assertEqual(template["traits"][0]["name"], "亡灵本质")
        self.assertEqual(template["actions"][0]["name"], "枯萎之触")
        self.assertEqual(template["bonusActions"][0]["name"], "暗影步")
        self.assertEqual(template["reactions"][0]["name"], "法术偏转")
        self.assertEqual(template["legendaryActions"][0]["name"], "侦测")
        self.assertEqual(template["spellcasting"][0]["name"], "天生施法")
        markdown = mm.character_markdown(monster, "test-undead-mage")
        self.assertIn("## 特性", markdown)
        self.assertIn("## 附赠动作", markdown)
        self.assertIn("## 施法", markdown)
        self.assertTrue(
            any(item["reason"] == "multiple-titled-blocks" for item in review)
        )
        self.assertTrue(
            any(item["reason"] == "unclassified-section" for item in review)
        )

    def test_unknown_creature_type_requires_manual_review(self) -> None:
        monster = mm.MonsterRecord(
            name="测试未知生物",
            english_name="Test Unknown",
            source_path="fixture.htm",
            creature_type="时间旅者",
        )

        entry = mm.content_entry(monster, "test-unknown")
        review = mm.build_manual_review([monster])

        self.assertEqual(
            entry["structured"]["classification"]["creatureType"],
            "unknown",
        )
        self.assertIn("时间旅者", entry["structured"]["classification"]["tags"])
        self.assertTrue(
            any(item["reason"] == "unknown-creature-type" for item in review)
        )


class DmgItemExtractorTest(unittest.TestCase):
    def test_parses_multiple_magic_items_from_one_page(self) -> None:
        html = """
        <h6>测试戒指 Test Ring</h6>
        <p><em>戒指，珍稀（需同调）</em><br>佩戴者获得测试能力。</p>
        <h6>测试药水 Test Potion</h6>
        <p><em>药水，普通</em><br>饮用后恢复1点生命值。</p>
        """

        items = dmg.parse_magic_items(html, source_path="fixture.htm")

        self.assertEqual([item.name for item in items], ["测试戒指", "测试药水"])
        self.assertEqual(items[0].category, "戒指")
        self.assertEqual(items[0].rarity, "珍稀")
        self.assertTrue(items[0].attunement)
        self.assertFalse(items[1].attunement)
        self.assertIn("恢复1点生命值", items[1].description)
        entry = dmg.content_entry(items[0], "test-ring")
        self.assertEqual(
            entry["structured"]["itemTemplate"]["templateRef"],
            "private-dmg-2024:item/test-ring",
        )


if __name__ == "__main__":
    unittest.main()
