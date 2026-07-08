import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/campaign_api_client.dart';
import '../domain/campaign.dart';

class CampaignController extends ChangeNotifier {
  CampaignController({
    required this.apiBaseUrl,
    required this.authController,
    required this.campaignClient,
  }) {
    authController.addListener(_onAuthChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final CampaignClient campaignClient;

  List<Campaign> _campaigns = [];
  bool _loading = false;
  String? _error;

  Campaign? _selectedCampaign;
  List<CampaignInvite> _invites = [];
  bool _detailLoading = false;
  String? _detailError;

  List<Campaign> get campaigns => _campaigns;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get accessToken => authController.accessToken;

  Campaign? get selectedCampaign => _selectedCampaign;
  List<CampaignInvite> get invites => _invites;
  bool get isDetailLoading => _detailLoading;
  String? get detailError => _detailError;

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _campaigns = [];
      _selectedCampaign = null;
      _invites = [];
      _error = null;
      _detailError = null;
      notifyListeners();
    }
  }

  Future<void> loadCampaigns() async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _campaigns = await campaignClient.listCampaigns(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
      );
    } on CampaignApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load campaigns';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> createCampaign({
    required String name,
    String? description,
    String? system,
  }) async {
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      final campaign = await campaignClient.createCampaign(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        name: name,
        description: description,
        system: system,
      );
      _campaigns = [..._campaigns, campaign];
      notifyListeners();
      return true;
    } on CampaignApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinCampaign({required String code}) async {
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      await campaignClient.joinCampaign(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        code: code,
      );
      await loadCampaigns();
      return true;
    } on CampaignApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCampaignDetail(String campaignId) async {
    final token = accessToken;
    if (token == null) return;

    _detailLoading = true;
    _detailError = null;
    notifyListeners();

    try {
      _selectedCampaign = await campaignClient.getCampaign(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on CampaignApiException catch (e) {
      _detailError = e.message;
      _detailLoading = false;
      notifyListeners();
      return;
    } catch (_) {
      _detailError = 'Failed to load campaign details';
      _detailLoading = false;
      notifyListeners();
      return;
    }

    // Invites may be inaccessible for non-managers (403) — that's expected.
    _invites = [];
    try {
      _invites = await campaignClient.listInvites(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on CampaignApiException catch (_) {
      // Non-managers cannot view invites; leave _invites empty.
    }

    _detailLoading = false;
    notifyListeners();
  }

  Future<CampaignInvite?> createInvite({
    required String campaignId,
    String? roleOnJoin,
    int? maxUses,
  }) async {
    final token = accessToken;
    if (token == null) return null;

    _detailError = null;
    try {
      final invite = await campaignClient.createInvite(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        roleOnJoin: roleOnJoin,
        maxUses: maxUses,
      );
      _invites = [..._invites, invite];
      notifyListeners();
      return invite;
    } on CampaignApiException catch (e) {
      _detailError = e.message;
      notifyListeners();
      return null;
    }
  }

  void clearSelection() {
    _selectedCampaign = null;
    _invites = [];
    _detailError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }
}
