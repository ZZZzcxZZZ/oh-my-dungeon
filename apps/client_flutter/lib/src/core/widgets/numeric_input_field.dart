import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact Material 3 integer input used by dense tool surfaces.
/// [allowEmpty] 时允许清空输入 (不触发 [onChanged]), 配合 [onCleared] 表达
/// "无值" 语义 (如可选的 DC 检定目标).
class NumericInputField extends StatefulWidget {
  const NumericInputField({
    required this.value,
    required this.onChanged,
    this.label,
    this.allowNegative = false,
    this.allowEmpty = false,
    this.onCleared,
    this.width = 72,
    this.fieldKey,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String? label;
  final bool allowNegative;
  final bool allowEmpty;
  final VoidCallback? onCleared;
  final double width;
  final Key? fieldKey;

  @override
  State<NumericInputField> createState() => _NumericInputFieldState();
}

class _NumericInputFieldState extends State<NumericInputField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );

  @override
  void didUpdateWidget(covariant NumericInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        int.tryParse(_controller.text) != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        key: widget.fieldKey,
        controller: _controller,
        keyboardType: TextInputType.numberWithOptions(
          signed: widget.allowNegative,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            widget.allowNegative ? RegExp(r'^-?\d*') : RegExp(r'^\d*'),
          ),
        ],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) {
          if (text.isEmpty) {
            // 允许空值: 清空输入表达"无值", 由调用方决定回填或置空.
            if (widget.allowEmpty) {
              widget.onCleared?.call();
            } else {
              _controller.text = '${widget.value}';
            }
            return;
          }
          final value = int.tryParse(text);
          if (value != null) widget.onChanged(value);
        },
      ),
    );
  }
}
