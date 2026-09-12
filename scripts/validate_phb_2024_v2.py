#!/usr/bin/env python3
"""验证 PHB 2024 v2 资料包：schema 校验 + 引用完整性校验。

模拟 ContentPackageImporter 的校验逻辑，不修改公开测试。
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BUNDLE_PATH = REPO_ROOT / "private-imports" / "phb-2024-v2-bundle.json"

VALID_BLOCK_TYPES = {
    "heading", "paragraph", "list", "table", "quote",
    "callout", "image", "statBlock", "entryLink", "diceExpression",
}
VALID_ENTRY_TYPES = {
    "class", "subclass", "classFeature", "species", "background", "feat",
    "spell", "equipment", "item", "condition", "rule", "monster", "custom",
    "equipmentBundle",
}
VALID_GRANT_KINDS = {
    "feature", "proficiency", "spell", "equipment", "resource", "action",
    "conditionResistance", "speed", "armorClass", "hitPoints", "ability", "note",
}
VALID_BUILDER_STEPS = {
    "class", "origin", "abilities", "proficiencies", "equipment", "spells", "details",
}
VALID_CHOICE_OPTION_TYPES = {"subclass", "feat", "spell", "equipment", "skill", "tool", "language"}


def _progression_levels(step: object) -> list[int]:
    """progression 步骤的生效等级：新契约只写 `levels` 数组。

    旧 `level` 单值形状不再接受（客户端 `RuleProgressionDefinition.fromJson`
    会抛 FormatException），这里只读 `levels` 供汇总/完整性检查使用。
    """
    if not isinstance(step, dict):
        return []
    raw = step.get("levels")
    if not isinstance(raw, list):
        return []
    return [item for item in raw if isinstance(item, int)]


def main() -> int:
    if not BUNDLE_PATH.exists():
        print(f"ERROR: Bundle not found: {BUNDLE_PATH}")
        return 1

    bundle = json.loads(BUNDLE_PATH.read_text(encoding="utf-8"))
    errors: list[str] = []
    warnings: list[str] = []

    # ---- Manifest 校验 ----
    manifest_fields = {
        "formatVersion": int,
        "id": str,
        "name": str,
        "version": str,
        "locale": str,
        "system": str,
        "entryCount": int,
    }
    for field, expected_type in manifest_fields.items():
        val = bundle.get(field)
        if val is None:
            errors.append(f"$.{field}: missing required field")
        elif not isinstance(val, expected_type):
            errors.append(f"$.{field}: expected {expected_type.__name__}, got {type(val).__name__}")
        elif isinstance(val, str) and not val.strip():
            errors.append(f"$.{field}: must be non-empty string")

    if bundle.get("formatVersion") != 3:
        errors.append(f"$.formatVersion: must be 3, got {bundle.get('formatVersion')}")

    if bundle.get("system") != "dnd5e-2024":
        errors.append(f"$.system: must be 'dnd5e-2024', got '{bundle.get('system')}'")

    package_id = bundle.get("id", "")
    entries = bundle.get("entries", [])
    if not isinstance(entries, list):
        errors.append("$.entries: must be a list")
        entries = []

    declared_count = bundle.get("entryCount", -1)
    if declared_count >= 0 and declared_count != len(entries):
        errors.append(
            f"$.entryCount: declared {declared_count} but actual {len(entries)}"
        )

    # ---- 条目校验 ----
    entry_ids: set[str] = set()
    id_counts: Counter[str] = Counter()
    entry_by_id: dict[str, dict] = {}

    for i, entry in enumerate(entries):
        prefix = f"$.entries[{i}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix}: entry must be a JSON object")
            continue

        # 必填字段
        for field in ("id", "type", "slug", "name", "body", "revision"):
            if field not in entry:
                errors.append(f"{prefix}.{field}: missing required field")

        entry_id = entry.get("id", "")
        entry_type = entry.get("type", "")
        slug = entry.get("slug", "")
        name = entry.get("name", "")
        body = entry.get("body", [])

        # A title or slug made from page prose is technically valid JSON but
        # unusable in the library UI. Treat it as an extraction failure.
        if not isinstance(name, str) or not name.strip():
            errors.append(f"{prefix}.name: must be a non-empty string")
        elif len(name) > 100:
            errors.append(f"{prefix}.name: exceeds the 100-character title limit")
        if not isinstance(slug, str) or not slug.strip():
            errors.append(f"{prefix}.slug: must be a non-empty string")
        elif len(slug) > 60:
            errors.append(f"{prefix}.slug: exceeds the 60-character slug limit")

        # ID 前缀校验
        if package_id and not entry_id.startswith(f"{package_id}:"):
            errors.append(
                f"{prefix}.id: '{entry_id}' must start with '{package_id}:'"
            )

        # ID 去重
        id_counts[entry_id] += 1
        if id_counts[entry_id] > 1:
            errors.append(f"{prefix}.id: duplicate entry ID: {entry_id}")
        else:
            entry_ids.add(entry_id)
            entry_by_id[entry_id] = entry

        # 类型校验
        if entry_type and entry_type not in VALID_ENTRY_TYPES:
            errors.append(
                f"{prefix}.type: '{entry_type}' is not a valid entry type"
            )

        # body 校验
        if not isinstance(body, list):
            errors.append(f"{prefix}.body: must be a list")
        else:
            for j, block in enumerate(body):
                bprefix = f"{prefix}.body[{j}]"
                if not isinstance(block, dict):
                    errors.append(f"{bprefix}: block must be a JSON object")
                    continue
                btype = block.get("type", "")
                if btype not in VALID_BLOCK_TYPES:
                    errors.append(f"{bprefix}.type: '{btype}' is not a valid block type")
                    continue
                # entryLink targetId 校验（第二遍）
                if btype == "entryLink":
                    target = block.get("targetId", "")
                    if target and target not in entry_ids:
                        # 可能是前向引用，先记录，后面统一检查
                        pass

        # rules 结构校验延后到第二遍（前向引用需要全部条目已收集）

    # ---- 第二遍：引用完整性 + rules 校验 ----
    broken_links: list[str] = []
    broken_relations: list[str] = []
    broken_rule_refs: list[str] = []

    for i, entry in enumerate(entries):
        if not isinstance(entry, dict):
            continue
        prefix = f"$.entries[{i}]"
        entry_id = entry.get("id", "")

        # entryLink 引用
        for j, block in enumerate(entry.get("body", [])):
            if isinstance(block, dict) and block.get("type") == "entryLink":
                target = block.get("targetId", "")
                if target and target not in entry_ids:
                    broken_links.append(
                        f"{prefix}.body[{j}].targetId: '{target}' does not exist"
                    )

        # structured 中的关系引用（parentClass 是显示名，不是 ID）
        structured = entry.get("structured", {})
        if isinstance(structured, dict):
            for rel_key in ("subclassOf", "featureOf"):
                ref = structured.get(rel_key)
                if isinstance(ref, str) and ref and ref not in entry_ids:
                    broken_relations.append(
                        f"{entry_id}.structured.{rel_key}: '{ref}' does not exist"
                    )

        # rules 结构校验 + 引用校验（v2，全部条目已收集）
        rules = entry.get("rules")
        if rules and isinstance(rules, dict):
            _validate_rules(entry_id, rules, entry_ids, entry_by_id, f"{prefix}.rules", errors)
            _check_rule_refs(
                entry_id, rules, entry_ids, f"{prefix}.rules", broken_rule_refs
            )

    # Class progression and subclass choices are executable rules, so missing
    # levels or choices are validation failures rather than report-only notes.
    for entry in entries:
        if not isinstance(entry, dict) or entry.get("type") != "class":
            continue
        entry_id = entry.get("id", "")
        progression = entry.get("rules", {}).get("progression", [])
        levels = {
            level
            for step in progression
            for level in _progression_levels(step)
        }
        missing_levels = [level for level in range(1, 21) if level not in levels]
        if missing_levels:
            errors.append(
                f"{entry_id}.rules.progression: missing levels {missing_levels}"
            )
        level_three = next(
            (
                step
                for step in progression
                if 3 in _progression_levels(step)
            ),
            None,
        )
        subclass_choices = [
            choice
            for choice in (level_three or {}).get("choices", [])
            if isinstance(choice, dict)
            and choice.get("optionType") == "subclass"
        ]
        if not subclass_choices:
            errors.append(
                f"{entry_id}.rules.progression[3]: missing subclass choice"
            )

    # Subclass 规则完整性：每个 subclass 必须声明 subclassOf 关系并至少
    # 提供一条 progression（子职业特性在 3/7/10/15/18 等级解锁）。
    # 这是 v2 包规则介入正确性的硬性要求，缺失会让角色构建器无法解析子职特性。
    for entry in entries:
        if not isinstance(entry, dict) or entry.get("type") != "subclass":
            continue
        entry_id = entry.get("id", "")

        relations = entry.get("relations", [])
        if not isinstance(relations, list) or not relations:
            errors.append(
                f"{entry_id}.relations: subclass must declare subclassOf relation"
            )
        else:
            subclass_of = [
                rel
                for rel in relations
                if isinstance(rel, dict) and rel.get("type") == "subclassOf"
            ]
            if not subclass_of:
                errors.append(
                    f"{entry_id}.relations: missing subclassOf relation"
                )
            else:
                target = subclass_of[0].get("targetId", "")
                if target not in entry_ids:
                    errors.append(
                        f"{entry_id}.relations.subclassOf: '{target}' does not exist"
                    )

        sub_progression = entry.get("rules", {}).get("progression", [])
        if not sub_progression:
            errors.append(
                f"{entry_id}.rules.progression: subclass must declare at least one level"
            )

    # ---- 统计报告 ----
    by_type: Counter[str] = Counter()
    for entry in entries:
        if isinstance(entry, dict):
            by_type[entry.get("type", "unknown")] += 1

    print("=" * 60)
    print("PHB 2024 v2 资料包校验报告")
    print("=" * 60)
    print(f"Bundle: {BUNDLE_PATH}")
    print(f"formatVersion: {bundle.get('formatVersion')}")
    print(f"packageId: {package_id}")
    print(f"version: {bundle.get('version')}")
    print(f"system: {bundle.get('system')}")
    print(f"entryCount (declared): {declared_count}")
    print(f"entryCount (actual): {len(entries)}")
    print()
    print("By type:")
    for t, count in sorted(by_type.items()):
        print(f"  {t}: {count}")

    # 重复项
    duplicates = {k: v for k, v in id_counts.items() if v > 1}
    print(f"\nDuplicate IDs: {len(duplicates)}")
    for dup_id, count in duplicates.items():
        print(f"  {dup_id}: {count}")

    print(f"\nSchema errors: {len(errors)}")
    for err in errors[:20]:
        print(f"  {err}")
    if len(errors) > 20:
        print(f"  ... and {len(errors) - 20} more")

    print(f"\nBroken entryLinks: {len(broken_links)}")
    for link in broken_links[:10]:
        print(f"  {link}")

    print(f"\nBroken relations: {len(broken_relations)}")
    for rel in broken_relations[:10]:
        print(f"  {rel}")

    print(f"\nBroken rule references: {len(broken_rule_refs)}")
    for ref in broken_rule_refs[:10]:
        print(f"  {ref}")

    # progression 完整性：每个 class 应有 1-20 级
    print("\nProgression check:")
    for entry in entries:
        if isinstance(entry, dict) and entry.get("type") == "class":
            rules = entry.get("rules", {})
            prog = rules.get("progression", [])
            levels = [
                level for p in prog for level in _progression_levels(p)
            ]
            missing = [l for l in range(1, 21) if l not in levels]
            cls_name = entry.get("name", "?")
            if missing:
                print(f"  {cls_name}: missing levels {missing}")
            else:
                feature_grants = sum(
                    1 for p in prog
                    if isinstance(p, dict)
                    for g in p.get("grants", [])
                    if isinstance(g, dict) and g.get("kind") == "feature"
                )
                print(f"  {cls_name}: 1-20 complete, {feature_grants} feature grants")

    # 子职业选择校验
    print("\nSubclass choice check:")
    for entry in entries:
        if isinstance(entry, dict) and entry.get("type") == "class":
            rules = entry.get("rules", {})
            prog = rules.get("progression", [])
            for p in prog:
                if isinstance(p, dict) and 3 in _progression_levels(p):
                    choices = p.get("choices", [])
                    subclass_choices = [
                        c for c in choices
                        if isinstance(c, dict) and c.get("optionType") == "subclass"
                    ]
                    cls_name = entry.get("name", "?")
                    if subclass_choices:
                        print(f"  {cls_name}: has subclass choice at level 3 [OK]")
                    else:
                        print(f"  {cls_name}: MISSING subclass choice at level 3")

    print("\n" + "=" * 60)
    if errors:
        print(f"RESULT: FAIL ({len(errors)} schema errors)")
    elif broken_links or broken_relations or broken_rule_refs:
        print(
            f"RESULT: FAIL ({len(broken_links)} broken links, "
            f"{len(broken_relations)} broken relations, "
            f"{len(broken_rule_refs)} broken rule refs)"
        )
    else:
        print("RESULT: PASS - schema and reference integrity OK")
    print("=" * 60)

    return 1 if (errors or broken_links or broken_relations or broken_rule_refs) else 0


def _validate_rules(
    entry_id: str,
    rules: dict,
    entry_ids: set[str],
    entry_by_id: dict[str, dict],
    path: str,
    errors: list[str],
) -> None:
    """校验 rules 结构（模拟 CharacterRuleDefinition.fromJson）。"""
    # grants
    for i, grant in enumerate(rules.get("grants", [])):
        gpath = f"{path}.grants[{i}]"
        if not isinstance(grant, dict):
            errors.append(f"{gpath}: grant must be an object")
            continue
        if not grant.get("id"):
            errors.append(f"{gpath}: grant requires id")
        kind = grant.get("kind", "")
        if kind not in VALID_GRANT_KINDS:
            errors.append(f"{gpath}.kind: '{kind}' is not a valid grant kind")
        ref = grant.get("entryId")
        if ref and ref not in entry_ids:
            errors.append(f"{gpath}.entryId: '{ref}' does not exist")

    # choices
    for i, choice in enumerate(rules.get("choices", [])):
        cpath = f"{path}.choices[{i}]"
        if not isinstance(choice, dict):
            errors.append(f"{cpath}: choice must be an object")
            continue
        if not choice.get("id"):
            errors.append(f"{cpath}: choice requires id")
        if not choice.get("optionType"):
            errors.append(f"{cpath}: choice requires optionType")
        minimum = choice.get("minimum", 1)
        maximum = choice.get("maximum", minimum)
        if minimum < 0 or maximum < minimum:
            errors.append(f"{cpath}: invalid range {minimum}..{maximum}")
        mol = choice.get("maximumOptionLevel")
        if mol is not None and (mol < 0 or mol > 9):
            errors.append(f"{cpath}.maximumOptionLevel: must be 0-9, got {mol}")
        bs = choice.get("builderStep")
        if bs and bs not in VALID_BUILDER_STEPS:
            errors.append(f"{cpath}.builderStep: '{bs}' is not valid")
        for j, ref in enumerate(choice.get("optionEntryIds", [])):
            if ref not in entry_ids:
                errors.append(f"{cpath}.optionEntryIds[{j}]: '{ref}' does not exist")
        for j, ref in enumerate(choice.get("recommendedEntryIds", [])):
            if ref not in entry_ids:
                errors.append(f"{cpath}.recommendedEntryIds[{j}]: '{ref}' does not exist")

    # progression
    for i, step in enumerate(rules.get("progression", [])):
        spath = f"{path}.progression[{i}]"
        if not isinstance(step, dict):
            errors.append(f"{spath}: progression step must be an object")
            continue
        raw_levels = step.get("levels")
        if "level" in step:
            errors.append(
                f'{spath}.level: 旧形状 "level" 已废弃，必须写 "levels": [..]'
            )
        if (
            not isinstance(raw_levels, list)
            or not raw_levels
            or any(
                not isinstance(level, int) or level < 1 or level > 20
                for level in raw_levels
            )
        ):
            errors.append(
                f"{spath}.levels: must be a non-empty 1-20 int array, "
                f"got {raw_levels}"
            )
        # 递归校验 progression 内的 grants 和 choices
        for j, grant in enumerate(step.get("grants", [])):
            gpath = f"{spath}.grants[{j}]"
            if not isinstance(grant, dict):
                errors.append(f"{gpath}: grant must be an object")
                continue
            if not grant.get("id"):
                errors.append(f"{gpath}: grant requires id")
            kind = grant.get("kind", "")
            if kind not in VALID_GRANT_KINDS:
                errors.append(f"{gpath}.kind: '{kind}' is not a valid grant kind")
            ref = grant.get("entryId")
            if ref and ref not in entry_ids:
                errors.append(f"{gpath}.entryId: '{ref}' does not exist")
        for j, choice in enumerate(step.get("choices", [])):
            cpath = f"{spath}.choices[{j}]"
            if not isinstance(choice, dict):
                errors.append(f"{cpath}: choice must be an object")
                continue
            if not choice.get("id"):
                errors.append(f"{cpath}: choice requires id")
            if not choice.get("optionType"):
                errors.append(f"{cpath}: choice requires optionType")
            mol = choice.get("maximumOptionLevel")
            if mol is not None and (mol < 0 or mol > 9):
                errors.append(f"{cpath}.maximumOptionLevel: must be 0-9, got {mol}")
            bs = choice.get("builderStep")
            if bs and bs not in VALID_BUILDER_STEPS:
                errors.append(f"{cpath}.builderStep: '{bs}' is not valid")


def _check_rule_refs(
    entry_id: str,
    rules: dict,
    entry_ids: set[str],
    path: str,
    broken: list[str],
) -> None:
    """收集 rules 中的断链。"""
    for i, grant in enumerate(rules.get("grants", [])):
        if isinstance(grant, dict):
            ref = grant.get("entryId")
            if ref and ref not in entry_ids:
                broken.append(f"{entry_id} {path}.grants[{i}].entryId: '{ref}'")
    for i, choice in enumerate(rules.get("choices", [])):
        if isinstance(choice, dict):
            for j, ref in enumerate(choice.get("optionEntryIds", [])):
                if ref not in entry_ids:
                    broken.append(
                        f"{entry_id} {path}.choices[{i}].optionEntryIds[{j}]: '{ref}'"
                    )
    for i, step in enumerate(rules.get("progression", [])):
        if not isinstance(step, dict):
            continue
        for j, grant in enumerate(step.get("grants", [])):
            if isinstance(grant, dict):
                ref = grant.get("entryId")
                if ref and ref not in entry_ids:
                    broken.append(
                        f"{entry_id} {path}.progression[{i}].grants[{j}].entryId: '{ref}'"
                    )
        for j, choice in enumerate(step.get("choices", [])):
            if isinstance(choice, dict):
                for k, ref in enumerate(choice.get("optionEntryIds", [])):
                    if ref not in entry_ids:
                        broken.append(
                            f"{entry_id} {path}.progression[{i}].choices[{j}].optionEntryIds[{k}]: '{ref}'"
                        )


if __name__ == "__main__":
    sys.exit(main())
