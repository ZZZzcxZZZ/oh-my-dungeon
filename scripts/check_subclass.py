"""检查 subclass 数据完整性（v2 canonical 结构）。

校验维度：
- relations 中包含 subclassOf 关系且目标存在
- structured.parentClass 用于 UI 显示
- rules.progression 至少包含一个等级
- 子职业 classFeature 数量统计
"""
import json
import sys
from collections import Counter

bundle_path = sys.argv[1] if len(sys.argv) > 1 else 'private-imports/phb-2024-v2-bundle.json'
with open(bundle_path, encoding='utf-8') as f:
    data = json.load(f)

entries = data['entries']
entry_ids = {e['id'] for e in entries}

subclasses = [e for e in entries if e['type'] == 'subclass']
print(f'subclass total: {len(subclasses)}')

# Canonical: subclassOf 在 relations 数组中
has_subclass_of_relation = sum(
    1 for s in subclasses
    if any(r.get('type') == 'subclassOf' for r in s.get('relations', []))
)
print(f'has relations.subclassOf: {has_subclass_of_relation}')

# 关系目标有效性
broken_targets = [
    s['id'] for s in subclasses
    for r in s.get('relations', [])
    if r.get('type') == 'subclassOf' and r.get('targetId') not in entry_ids
]
print(f'broken subclassOf targets: {len(broken_targets)}')

# Display 字段
has_parent_class = sum(
    1 for s in subclasses if s.get('structured', {}).get('parentClass')
)
print(f'has structured.parentClass: {has_parent_class}')

# Rules
has_rules = sum(1 for s in subclasses if s.get('rules'))
has_progression = sum(
    1 for s in subclasses if s.get('rules', {}).get('progression')
)
print(f'has rules: {has_rules}')
print(f'has rules.progression: {has_progression}')

# 子职业 classFeature 统计
sub_features = [
    e for e in entries
    if e['type'] == 'classFeature'
    and 'subclass' in e.get('tags', [])
]
print(f'\nsubclass classFeature total: {len(sub_features)}')

print('\nfirst 5 subclasses:')
for s in subclasses[:5]:
    sid = s['id']
    name = s['name']
    pc = s.get('structured', {}).get('parentClass', '(none)')
    rels = s.get('relations', [])
    sub_of = next(
        (r.get('targetId') for r in rels if r.get('type') == 'subclassOf'),
        '(none)',
    )
    prog = s.get('rules', {}).get('progression', [])
    levels = [p.get('level') for p in prog]
    print(f'  id={sid}, name={name}, parentClass={pc}, '
          f'subclassOf={sub_of}, levels={levels}')

print('\nby parentClass:')
pc_counts = Counter(
    s.get('structured', {}).get('parentClass', '(empty)')
    for s in subclasses
)
for pc, count in pc_counts.most_common():
    print(f'  {pc}: {count}')

print('\nclasses for comparison:')
classes = [e for e in entries if e['type'] == 'class']
print(f'class total: {len(classes)}')
print(f'class names: {[c["name"] for c in classes]}')
