import 'package:flutter/material.dart';

import '../../../characters/domain/dnd5e_rules.dart';
import '../../domain/campaign_actor.dart';

/// DM 向玩家发起检定请求的草稿。由 [CheckRequestSheet] 返回给宿主页面，
/// 宿主页面再调用 sendMessage 提交 kind=checkRequest。
class CheckRequestDraft {
  const CheckRequestDraft({
    required this.type,
    required this.key,
    required this.label,
    required this.dc,
    required this.rollMode,
  });

  final String type;
  final String key;
  final String label;
  final int? dc;
  final String rollMode;
}

/// 检定请求表单：选择类型（属性/豁免/技能）、项目、可选 DC、掷骰模式，
/// 提交后通过 Navigator.pop 返回 [CheckRequestDraft]。
class CheckRequestSheet extends StatefulWidget {
  const CheckRequestSheet({required this.actor, super.key});

  final CampaignActor actor;

  @override
  State<CheckRequestSheet> createState() => _CheckRequestSheetState();
}

class _CheckRequestSheetState extends State<CheckRequestSheet> {
  final _dcController = TextEditingController();
  String _type = 'ability';
  String _key = 'str';
  String _rollMode = 'normal';

  @override
  void dispose() {
    _dcController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _options {
    if (_type == 'skill') {
      return [
        for (final skill in Dnd5eRules.skills) MapEntry(skill.name, skill.name),
      ];
    }
    return Dnd5eRules.abilityLabels.entries.toList(growable: false);
  }

  void _setType(String type) {
    setState(() {
      _type = type;
      _key = type == 'skill' ? Dnd5eRules.skills.first.name : 'str';
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.actor.sheet['name']?.toString().trim();
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '为 ${name == null || name.isEmpty ? '该角色' : name} 代掷检定',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'ability',
                  label: Text('属性', key: Key('check-type-ability')),
                ),
                ButtonSegment(
                  value: 'save',
                  label: Text('豁免', key: Key('check-type-save')),
                ),
                ButtonSegment(
                  value: 'skill',
                  label: Text('技能', key: Key('check-type-skill')),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => _setType(selection.single),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('check-key-$_type'),
              initialValue: _key,
              decoration: const InputDecoration(
                labelText: '检定项目',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in _options)
                  DropdownMenuItem(
                    value: option.key,
                    child: Text(option.value),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _key = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dcController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '难度等级 DC（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'normal', label: Text('普通')),
                ButtonSegment(value: 'advantage', label: Text('优势')),
                ButtonSegment(value: 'disadvantage', label: Text('劣势')),
              ],
              selected: {_rollMode},
              onSelectionChanged: (selection) {
                setState(() => _rollMode = selection.single);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('roll-check-now'),
                onPressed: _submit,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('立即掷骰'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final dc = int.tryParse(_dcController.text.trim());
    final option = _options.firstWhere((item) => item.key == _key);
    final suffix = switch (_type) {
      'skill' => '技能检定',
      'save' => '豁免检定',
      _ => '属性检定',
    };
    Navigator.of(context).pop(
      CheckRequestDraft(
        type: _type,
        key: _key,
        label: '${option.value}$suffix',
        dc: dc,
        rollMode: _rollMode,
      ),
    );
  }
}
