// character_detail_page.dart 的 part：装备/物品/货币区与库存归一化工具。
part of 'character_detail_page.dart';

class _EquipmentPanel extends StatefulWidget {
  const _EquipmentPanel({
    required this.character,
    required this.contentEntries,
    this.onUpdateInventory,
  });

  final CharacterSheet character;
  final List<ContentEntry> contentEntries;
  final CharacterInventoryUpdate? onUpdateInventory;

  @override
  State<_EquipmentPanel> createState() => _EquipmentPanelState();
}

class _EquipmentPanelState extends State<_EquipmentPanel> {
  late List<Map<String, Object>> _inventory;
  late Map<String, int> _currency;

  @override
  void initState() {
    super.initState();
    _syncFromCharacter();
  }

  @override
  void didUpdateWidget(covariant _EquipmentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) {
      _syncFromCharacter();
    }
  }

  void _syncFromCharacter() {
    _inventory = _normalizeInventory(widget.character.inventoryList);
    _currency = _normalizeCurrency(widget.character.currencyMap);
  }

  @override
  Widget build(BuildContext context) {
    final equipped = _inventory
        .where((item) => item['equipped'] == true)
        .toList(growable: false);
    final carried = _inventory
        .where((item) => item['equipped'] != true)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: '货币',
          icon: Icons.paid_outlined,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_currency.isEmpty)
                    Text(
                      '暂无货币记录',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        // Text on secondaryContainer must use the matching
                        // on-* role (E2).
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    )
                  else
                    for (final entry in _currency.entries)
                      _CurrencyControl(
                        code: entry.key,
                        value: entry.value,
                        onIncrement: () => _adjustCurrency(entry.key, 1),
                        onDecrement: () => _adjustCurrency(entry.key, -1),
                      ),
                ],
              ),
            ),
          ),
        ),
        _Section(
          title: '装备与物品',
          icon: Icons.inventory_2_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onUpdateInventory != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _addLibraryItem,
                        icon: const Icon(Icons.add),
                        label: const Text('从资料库添加'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addCustomItem,
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('自定义物品'),
                      ),
                    ],
                  ),
                ),
              if (_inventory.isEmpty)
                Text('暂无装备', style: Theme.of(context).textTheme.bodyMedium)
              else ...[
                if (equipped.isNotEmpty) ...[
                  Text('已装备', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (final item in equipped) _buildInventoryLine(item),
                  const SizedBox(height: 8),
                ],
                if (carried.isNotEmpty) ...[
                  Text('背包', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (final item in carried) _buildInventoryLine(item),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryLine(Map<String, Object> item) {
    final index = _inventory.indexOf(item);
    final entryId = item['entryId']?.toString();
    final entry = widget.contentEntries
        .where((candidate) => candidate.id == entryId)
        .firstOrNull;
    return _InventoryLine(
      item: item,
      entry: entry,
      onOpen: entry == null ? null : () => _openEntry(entry),
      onIncrement: () => _adjustInventoryQuantity(index, 1),
      onDecrement: () => _adjustInventoryQuantity(index, -1),
      onConsume: _isConsumable(item)
          ? () => _adjustInventoryQuantity(index, -1)
          : null,
      onToggleEquipped: () => _toggleItemFlag(index, 'equipped'),
      onToggleAttuned: () => _toggleItemFlag(index, 'attuned'),
      onDelete: () => _deleteInventoryItem(index),
    );
  }

  void _openEntry(ContentEntry entry) {
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: widget.contentEntries,
    );
  }

  Future<void> _adjustInventoryQuantity(int index, int delta) async {
    final next = _inventory
        .map((item) => Map<String, Object>.from(item))
        .toList();
    final item = next[index];
    final current = _intValue(item['quantity'], fallback: 1);
    item['quantity'] = (current + delta).clamp(0, 999);
    setState(() => _inventory = next);
    await widget.onUpdateInventory?.call(inventory: _snapshotInventory());
  }

  Future<void> _addLibraryItem() async {
    final entry = await _pickContentEntry(
      context,
      title: '添加装备',
      entries: widget.contentEntries
          .where(
            (entry) => const <String>{
              'equipment',
              'item',
              'weapon',
              'armor',
            }.contains(entry.type),
          )
          .toList(growable: false),
    );
    if (entry == null) return;
    final next = <Map<String, Object>>[
      ..._inventory.map(Map<String, Object>.from),
      <String, Object>{
        'entryId': entry.id,
        'name': entry.name,
        'quantity': 1,
        'equipped': false,
        'attuned': false,
      },
    ];
    await _saveInventory(next);
  }

  Future<void> _addCustomItem() async {
    final value = await _showNameDescriptionDialog(context, title: '自定义物品');
    if (value == null) return;
    final next = <Map<String, Object>>[
      ..._inventory.map(Map<String, Object>.from),
      <String, Object>{
        'name': value.$1,
        'quantity': 1,
        if (value.$2.trim().isNotEmpty) 'description': value.$2.trim(),
        'equipped': false,
        'attuned': false,
      },
    ];
    await _saveInventory(next);
  }

  Future<void> _toggleItemFlag(int index, String key) async {
    final next = _inventory.map(Map<String, Object>.from).toList();
    next[index][key] = next[index][key] != true;
    await _saveInventory(next);
  }

  Future<void> _deleteInventoryItem(int index) async {
    final next = _inventory.map(Map<String, Object>.from).toList()
      ..removeAt(index);
    await _saveInventory(next);
  }

  Future<void> _saveInventory(List<Map<String, Object>> next) async {
    setState(() => _inventory = next);
    await widget.onUpdateInventory?.call(inventory: _snapshotInventory());
  }

  Future<void> _adjustCurrency(String code, int delta) async {
    final next = Map<String, int>.from(_currency);
    final current = next[code] ?? 0;
    next[code] = (current + delta).clamp(0, 999999);
    setState(() => _currency = next);
    await widget.onUpdateInventory?.call(currency: Map.unmodifiable(_currency));
  }

  List<Map<String, Object>> _snapshotInventory() {
    return _inventory
        .map((item) => Map<String, Object>.unmodifiable(item))
        .toList(growable: false);
  }
}

class _InventoryLine extends StatelessWidget {
  const _InventoryLine({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    this.entry,
    this.onOpen,
    this.onConsume,
    this.onToggleEquipped,
    this.onToggleAttuned,
    this.onDelete,
  });

  final Map<String, Object> item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ContentEntry? entry;
  final VoidCallback? onOpen;
  final VoidCallback? onConsume;
  final VoidCallback? onToggleEquipped;
  final VoidCallback? onToggleAttuned;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? '未命名物品';
    final quantity = _intValue(item['quantity'], fallback: 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text('$name x$quantity'),
            subtitle: Text(
              [
                if (entry != null) entry!.type,
                if (item['equipped'] == true) '已装备',
                if (item['attuned'] == true) '已同调',
                if ('${item['description'] ?? ''}'.trim().isNotEmpty)
                  '${item['description']}',
              ].join(' · '),
            ),
            onTap: onOpen,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '$name -1',
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  tooltip: '$name +1',
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                if (onDelete != null ||
                    onToggleEquipped != null ||
                    onToggleAttuned != null)
                  PopupMenuButton<String>(
                    tooltip: '更多装备操作',
                    onSelected: (value) {
                      switch (value) {
                        case 'equipped':
                          onToggleEquipped?.call();
                        case 'attuned':
                          onToggleAttuned?.call();
                        case 'delete':
                          onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'equipped',
                        child: Text(item['equipped'] == true ? '卸下' : '装备'),
                      ),
                      PopupMenuItem(
                        value: 'attuned',
                        child: Text(item['attuned'] == true ? '解除同调' : '同调'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
              ],
            ),
          ),
          if (onConsume != null)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: OutlinedButton.icon(
                onPressed: quantity > 0 ? onConsume : null,
                icon: const Icon(Icons.local_drink_outlined),
                label: Text('消耗$name'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrencyControl extends StatelessWidget {
  const _CurrencyControl({
    required this.code,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String code;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '$code -1',
              onPressed: onDecrement,
              // Icons and text sit on the currency box's secondaryContainer
              // background, so they must use the matching on-* role (E2).
              icon: Icon(Icons.remove, color: colors.onSecondaryContainer),
            ),
            Text(
              '$code $value',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
            IconButton(
              tooltip: '$code +1',
              onPressed: onIncrement,
              icon: Icon(Icons.add, color: colors.onSecondaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

List<Map<String, Object>> _normalizeInventory(List<Object?> items) {
  return items.map(_normalizeInventoryItem).toList(growable: false);
}

Map<String, Object> _normalizeInventoryItem(Object? item) {
  if (item is Map) {
    final name = item['name']?.toString() ?? '未命名物品';
    final result = <String, Object>{
      'name': name,
      'quantity': _intValue(item['quantity'], fallback: 1),
    };
    if (item['consumable'] is bool) {
      result['consumable'] = item['consumable']! as bool;
    }
    // 保留资料引用与装备状态，使条目点击可打开 reader 并显示已装备/已同调标记。
    final entryId = item['entryId']?.toString();
    if (entryId != null && entryId.isNotEmpty) {
      result['entryId'] = entryId;
    }
    if (item['equipped'] is bool) {
      result['equipped'] = item['equipped']! as bool;
    }
    if (item['attuned'] is bool) {
      result['attuned'] = item['attuned']! as bool;
    }
    final description = item['description']?.toString();
    if (description != null && description.trim().isNotEmpty) {
      result['description'] = description;
    }
    return result;
  }
  return {'name': item?.toString() ?? '未命名物品', 'quantity': 1};
}

Map<String, int> _normalizeCurrency(Map<String, Object?> currency) {
  return {
    for (final entry in currency.entries)
      entry.key: _intValue(entry.value, fallback: 0),
  };
}

List<Map<String, Object?>> _objectMaps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
}

bool _isConsumable(Map<String, Object> item) {
  if (item['consumable'] == true) return true;
  final name = item['name']?.toString().toLowerCase() ?? '';
  return name.contains('药水') ||
      name.contains('potion') ||
      name.contains('卷轴') ||
      name.contains('scroll') ||
      name.contains('口粮') ||
      name.contains('ration');
}

int _intValue(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
