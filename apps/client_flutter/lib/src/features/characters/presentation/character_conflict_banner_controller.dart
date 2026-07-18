import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local/character_sync_conflict_repository.dart';

/// 角色 vs 战役 Actor 同步冲突的 UI 状态。监听
/// [CharacterSyncConflictRepository.watchAllUnresolved]，暴露未解决冲突计数。
class CharacterConflictBannerController extends ChangeNotifier {
  CharacterConflictBannerController({
    required CharacterSyncConflictRepository repository,
  }) : _repository = repository {
    _subscription = _repository.watchAllUnresolved().listen(_onData);
  }

  final CharacterSyncConflictRepository _repository;
  StreamSubscription<List<CharacterSyncConflict>>? _subscription;

  List<CharacterSyncConflict> _conflicts = const [];
  bool _loading = true;

  List<CharacterSyncConflict> get conflicts =>
      List.unmodifiable(_conflicts);
  int get unresolvedCount => _conflicts.length;
  bool get hasUnresolved => _conflicts.isNotEmpty;
  bool get isLoading => _loading;

  void _onData(List<CharacterSyncConflict> conflicts) {
    _conflicts = List.unmodifiable(conflicts);
    _loading = false;
    notifyListeners();
  }

  Future<void> markResolved(String conflictId) async {
    await _repository.markResolved(conflictId);
    // 流会自动推送新状态，不需要手动 refresh。
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
