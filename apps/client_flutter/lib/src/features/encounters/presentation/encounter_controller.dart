import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/encounter_api_client.dart';
import '../domain/encounter.dart';

class EncounterController extends ChangeNotifier {
  EncounterController({
    required this.apiBaseUrl,
    required this.authController,
    required this.encounterClient,
  }) {
    authController.addListener(_onAuthChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final EncounterClient encounterClient;

  List<Encounter> _encounters = [];
  Encounter? _activeEncounter;
  bool _loading = false;
  String? _error;

  List<Encounter> get encounters => _encounters;
  Encounter? get activeEncounter => _activeEncounter;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get accessToken => authController.accessToken;

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _encounters = [];
      _activeEncounter = null;
      _error = null;
      notifyListeners();
    }
  }

  Future<void> loadEncounters(String campaignId) async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _encounters = await encounterClient.listEncounters(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on EncounterApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '加载遭遇失败';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> loadEncounter(String encounterId) async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _activeEncounter = await encounterClient.getEncounter(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        encounterId: encounterId,
      );
    } on EncounterApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '加载遭遇详情失败';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> createEncounter({
    required String campaignId,
    required String name,
  }) async {
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      final encounter = await encounterClient.createEncounter(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        name: name,
      );
      _encounters = [..._encounters, encounter];
      notifyListeners();
      return true;
    } on EncounterApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> adjustParticipantHp({
    required String encounterId,
    required String participantId,
    required int delta,
  }) async {
    final token = accessToken;
    final active = _activeEncounter;
    if (token == null || active == null) return false;

    final participant = active.participants.firstWhere(
      (item) => item.id == participantId,
    );
    final nextHp = participant.hpCurrent + delta;
    try {
      final updated = await encounterClient.updateParticipant(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        encounterId: encounterId,
        participantId: participantId,
        hpCurrent: nextHp,
      );
      _activeEncounter = active.copyWith(
        participants: [
          for (final item in active.participants)
            if (item.id == participantId) updated else item,
        ],
      );
      notifyListeners();
      return true;
    } on EncounterApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> startEncounter() async {
    final token = accessToken;
    final active = _activeEncounter;
    if (token == null || active == null) return false;

    _error = null;
    try {
      _activeEncounter = await encounterClient.startEncounter(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        encounterId: active.id,
      );
      notifyListeners();
      return true;
    } on EncounterApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> advanceTurn() async {
    final token = accessToken;
    final active = _activeEncounter;
    if (token == null || active == null) return false;

    _error = null;
    try {
      _activeEncounter = await encounterClient.advanceTurn(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        encounterId: active.id,
      );
      notifyListeners();
      return true;
    } on EncounterApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> endEncounter() async {
    final token = accessToken;
    final active = _activeEncounter;
    if (token == null || active == null) return false;

    _error = null;
    try {
      _activeEncounter = await encounterClient.endEncounter(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        encounterId: active.id,
      );
      notifyListeners();
      return true;
    } on EncounterApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }
}
