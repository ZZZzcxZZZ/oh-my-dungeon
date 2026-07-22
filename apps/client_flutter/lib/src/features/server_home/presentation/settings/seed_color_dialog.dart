import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Material 3 seed-color picker dialog.
///
/// Offers preset tonal seeds, a hex input, and a live preview swatch. Pressing
/// **取消** returns null and the caller MUST NOT write the store; pressing
/// **应用** returns the chosen [Color] for the caller to persist.
class SeedColorDialog extends StatefulWidget {
  const SeedColorDialog({required this.current, super.key});

  final Color current;

  /// Convenience wrapper around [showDialog] that returns the chosen color or
  /// null when the user cancels.
  static Future<Color?> show(BuildContext context, {required Color current}) {
    return showDialog<Color>(
      context: context,
      builder: (_) => SeedColorDialog(current: current),
    );
  }

  @override
  State<SeedColorDialog> createState() => _SeedColorDialogState();
}

class _SeedColorDialogState extends State<SeedColorDialog> {
  static const _presets = <_NamedSeed>[
    _NamedSeed('Material 紫', Color(0xff6750a4)),
    _NamedSeed('Material 蓝', Color(0xff0061a4)),
    _NamedSeed('Material 绿', Color(0xff386a20)),
    _NamedSeed('Material 青', Color(0xff006a60)),
    _NamedSeed('Material 橙', Color(0xff8f4c00)),
    _NamedSeed('中性色', Color(0xff5f5e62)),
  ];

  late Color _selected;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    _hexController = TextEditingController(
      text: _hexFor(widget.current).toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _hexFor(Color color) {
    final argb = color.toARGB32();
    final rgb = (argb & 0xffffff).toRadixString(16).padLeft(6, '0');
    return rgb;
  }

  Color? _parseHex(String input) {
    final trimmed = input.trim().toUpperCase().replaceFirst('#', '');
    final hex = trimmed.length == 6 ? 'FF$trimmed' : trimmed;
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AlertDialog(
      title: const Text('主题色'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('预设色', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  InkWell(
                    key: Key('seed-color-preset-${_hexFor(preset.color)}'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      setState(() {
                        _selected = preset.color;
                        _hexController.text = _hexFor(preset.color).toUpperCase();
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: preset.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selected.toARGB32() == preset.color.toARGB32()
                              ? colorScheme.onSurface
                              : colorScheme.outlineVariant,
                          width: _selected.toARGB32() == preset.color.toARGB32()
                              ? 3
                              : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _selected.toARGB32() == preset.color.toARGB32()
                          ? Icon(
                              Icons.check,
                              color: colorScheme.onPrimary,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('自定义', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _selected,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('seed-color-hex-input'),
                    controller: _hexController,
                    decoration: const InputDecoration(
                      prefixText: '#',
                      hintText: '0061A4',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9a-fA-F]'),
                      ),
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (value) {
                      final parsed = _parseHex(value);
                      if (parsed != null) {
                        setState(() => _selected = parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('应用'),
        ),
      ],
    );
  }
}

class _NamedSeed {
  const _NamedSeed(this.label, this.color);

  final String label;
  final Color color;
}
