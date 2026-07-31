import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Compact Material 3 integer input used by dense tool surfaces.
class NumericInputField extends StatefulWidget {
  const NumericInputField({
    required this.value,
    required this.onChanged,
    this.label,
    this.allowNegative = false,
    this.width = 72,
    this.fieldKey,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String? label;
  final bool allowNegative;
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
          final value = int.tryParse(text);
          if (value != null) widget.onChanged(value);
        },
      ),
    );
  }
}
