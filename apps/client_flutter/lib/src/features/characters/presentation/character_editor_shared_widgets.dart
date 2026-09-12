// character_editor_page.dart 的 part：共享分区容器与数值/物品解析工具。
part of 'character_editor_page.dart';

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

int _intValue(TextEditingController controller, int fallback) {
  return int.tryParse(controller.text.trim()) ?? fallback;
}

List<Map<String, Object>> _parseInventory(String text) {
  final result = <Map<String, Object>>[];
  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final match = RegExp(r'^(.*?)\s*[xX×]\s*(\d+)$').firstMatch(line);
    if (match == null) {
      result.add({'name': line, 'quantity': 1});
    } else {
      result.add({
        'name': match.group(1)!.trim(),
        'quantity': int.parse(match.group(2)!),
      });
    }
  }
  return result;
}

String _inventoryToLines(List<Object?> inventory) {
  return inventory
      .map((item) {
        if (item is Map) {
          final name = item['name']?.toString() ?? '';
          final quantity = item['quantity'];
          if (quantity == null || quantity == 1) return name;
          return '$name x$quantity';
        }
        return '$item';
      })
      .join('\n');
}

List<Object?> _mergeInventory(List<Object?> current, List<Object?> generated) {
  final result = <Object?>[...current];
  final keys = {for (final item in current) _inventoryIdentity(item)}
    ..removeWhere((key) => key.isEmpty);
  for (final item in generated) {
    final key = _inventoryIdentity(item);
    if (key.isEmpty || !keys.add(key)) continue;
    result.add(item);
  }
  return result;
}

String _inventoryIdentity(Object? item) {
  if (item is Map) {
    final entryId = item['entryId']?.toString().trim();
    if (entryId != null && entryId.isNotEmpty) return 'id:$entryId';
    final name = item['name']?.toString().trim().toLowerCase() ?? '';
    return name.isEmpty ? '' : 'name:$name';
  }
  final name = '$item'.trim().toLowerCase();
  return name.isEmpty ? '' : 'name:$name';
}
