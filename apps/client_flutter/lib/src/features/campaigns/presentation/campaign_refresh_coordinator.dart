import 'dart:async';

typedef CampaignRefreshCallback = Future<void> Function(String campaignId);
typedef CampaignResourceRefreshCallback =
    Future<void> Function(String campaignId, String? cursor);

enum CampaignRefreshResource { messages, characters, archives, conversations }

/// Coalesces campaign invalidation signals without owning any page state.
///
/// The legacy constructor remains available for callers that still refresh a
/// whole campaign. New integrations should use [CampaignRefreshCoordinator.resources]
/// so unrelated resources can refresh independently.
class CampaignRefreshCoordinator {
  CampaignRefreshCoordinator({
    required CampaignRefreshCallback onRefresh,
    this.debounceDuration = const Duration(milliseconds: 180),
    this.fallbackInterval = const Duration(seconds: 45),
  }) : _onRefresh = onRefresh,
       _refreshers = const {};

  CampaignRefreshCoordinator.resources({
    required Map<CampaignRefreshResource, CampaignResourceRefreshCallback>
    refreshers,
    this.debounceDuration = const Duration(milliseconds: 180),
    this.fallbackInterval = const Duration(seconds: 45),
  }) : assert(refreshers.isNotEmpty),
       _onRefresh = null,
       _refreshers = Map.unmodifiable(refreshers);

  final CampaignRefreshCallback? _onRefresh;
  final Map<CampaignRefreshResource, CampaignResourceRefreshCallback>
  _refreshers;
  final Duration debounceDuration;
  final Duration fallbackInterval;

  String? _activeCampaignId;
  Timer? _debounceTimer;
  Timer? _fallbackTimer;
  bool _refreshing = false;
  bool _refreshPending = false;
  bool _disposed = false;
  int _activationEpoch = 0;
  final Map<CampaignRefreshResource, _ResourceRefreshState> _resourceStates =
      {};

  String? get activeCampaignId => _activeCampaignId;

  void activate(String? campaignId) {
    if (_disposed || _activeCampaignId == campaignId) return;
    _activeCampaignId = campaignId;
    _activationEpoch += 1;
    _resourceStates.clear();
    _debounceTimer?.cancel();
    _restartFallbackTimer();
  }

  /// Invalidates every registered resource, or the legacy whole-campaign
  /// callback when this coordinator was created with the default constructor.
  void invalidate() {
    if (_disposed || _activeCampaignId == null) return;
    if (_refreshers.isNotEmpty) {
      for (final resource in _refreshers.keys) {
        _stateFor(resource).register(null);
      }
      _scheduleResourceDrain();
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, refreshNow);
  }

  /// Invalidates one resource. Repeated signals carrying the same or an older
  /// cursor are ignored. Cursor-less signals are coalesced by generation.
  void invalidateResource(CampaignRefreshResource resource, {String? cursor}) {
    if (_disposed ||
        _activeCampaignId == null ||
        !_refreshers.containsKey(resource)) {
      return;
    }
    if (!_stateFor(resource).register(cursor)) return;
    _scheduleResourceDrain();
  }

  Future<void> onForegroundResumed() => refreshNow();

  Future<void> refreshNow() async {
    if (_disposed || _activeCampaignId == null) return;
    _debounceTimer?.cancel();
    if (_refreshers.isNotEmpty) {
      for (final resource in _refreshers.keys) {
        _stateFor(resource).register(null);
      }
      await _drainResources();
      return;
    }
    await _refreshLegacy();
  }

  Future<void> _refreshLegacy() async {
    if (_refreshing) {
      _refreshPending = true;
      return;
    }

    _refreshing = true;
    do {
      _refreshPending = false;
      final campaignId = _activeCampaignId;
      if (campaignId == null || _disposed) break;
      try {
        await _onRefresh!(campaignId);
      } catch (_) {
        // A failed refresh must not stop the next socket or foreground retry.
      }
    } while (_refreshPending && !_disposed);
    _refreshing = false;
  }

  _ResourceRefreshState _stateFor(CampaignRefreshResource resource) =>
      _resourceStates.putIfAbsent(resource, _ResourceRefreshState.new);

  void _scheduleResourceDrain() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, _drainResources);
  }

  Future<void> _drainResources() async {
    if (_disposed || _activeCampaignId == null) return;
    final pending = _refreshers.keys
        .where((resource) => _stateFor(resource).hasPending)
        .map(_refreshResource)
        .toList(growable: false);
    await Future.wait(pending);
  }

  Future<void> _refreshResource(CampaignRefreshResource resource) async {
    final state = _stateFor(resource);
    if (state.running) return;
    state.running = true;
    final epoch = _activationEpoch;
    try {
      while (state.hasPending && !_disposed && epoch == _activationEpoch) {
        final campaignId = _activeCampaignId;
        if (campaignId == null) break;
        final targetGeneration = state.generation;
        final targetCursor = state.latestCursor;
        try {
          await _refreshers[resource]!(campaignId, targetCursor);
        } catch (_) {
          // Entity controllers expose local errors. A later invalidation can
          // retry this resource without blocking other resource refreshes.
        }
        state.completedGeneration = targetGeneration;
      }
    } finally {
      state.running = false;
    }
  }

  void _restartFallbackTimer() {
    _fallbackTimer?.cancel();
    if (_activeCampaignId == null || fallbackInterval <= Duration.zero) return;
    _fallbackTimer = Timer.periodic(fallbackInterval, (_) => refreshNow());
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _fallbackTimer?.cancel();
  }
}

class _ResourceRefreshState {
  int generation = 0;
  int completedGeneration = 0;
  String? latestCursor;
  bool running = false;

  bool get hasPending => completedGeneration < generation;

  bool register(String? cursor) {
    if (cursor != null &&
        latestCursor != null &&
        !_isAdvancedCursor(cursor, latestCursor!)) {
      return false;
    }
    latestCursor = cursor;
    generation += 1;
    return true;
  }

  bool _isAdvancedCursor(String next, String current) {
    if (next == current) return false;
    final nextNumber = BigInt.tryParse(next);
    final currentNumber = BigInt.tryParse(current);
    if (nextNumber != null && currentNumber != null) {
      return nextNumber > currentNumber;
    }
    return true;
  }
}
