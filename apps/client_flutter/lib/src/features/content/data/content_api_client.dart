import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/content.dart';

abstract class ContentClient {
  Future<ImportContentPackageResult> importCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required Object package,
    bool dryRun = false,
  });
  Future<ImportContentPackageResult> importPackage({
    required String apiBaseUrl,
    required String accessToken,
    required Object package,
    bool dryRun = false,
  });

  Future<List<ContentPackage>> listPackages({
    required String apiBaseUrl,
    required String accessToken,
  });

  Future<Map<String, Object?>> exportPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String packageId,
  });

  Future<List<ContentItem>> listItems({
    required String apiBaseUrl,
    required String accessToken,
    String? type,
    String? query,
    String? packageId,
  });

  Future<List<ContentItem>> listAvailableCampaignItems({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? type,
    String? query,
    bool favoriteOnly = false,
  });

  Future<void> setCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String packageId,
    required bool enabled,
  });

  Future<void> disableCampaignItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    String? reason,
  });

  Future<void> setCampaignItemFavorite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    required bool favorite,
  });

  Future<ContentItemDetail> getCampaignItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
  });
}

class ContentApiClient implements ContentClient {
  ContentApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<ImportContentPackageResult> importCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required Object package,
    bool dryRun = false,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/packages/import'),
      headers: _headers(accessToken),
      body: jsonEncode({'dryRun': dryRun, 'package': package}),
    );
    if (response.statusCode != 201) throw _toException(response);
    return ImportContentPackageResult.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  @override
  Future<ImportContentPackageResult> importPackage({
    required String apiBaseUrl,
    required String accessToken,
    required Object package,
    bool dryRun = false,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/content/packages/import'),
      headers: _headers(accessToken),
      body: jsonEncode({'dryRun': dryRun, 'package': package}),
    );

    if (response.statusCode != 201) {
      throw _toException(response);
    }

    return ImportContentPackageResult.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  @override
  Future<List<ContentPackage>> listPackages({
    required String apiBaseUrl,
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/content/packages'),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => ContentPackage.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<Map<String, Object?>> exportPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String packageId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/content/packages/$packageId/export'),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    return jsonDecode(response.body) as Map<String, Object?>;
  }

  @override
  Future<List<ContentItem>> listItems({
    required String apiBaseUrl,
    required String accessToken,
    String? type,
    String? query,
    String? packageId,
  }) async {
    final uri = _buildUri(
      '${_normalize(apiBaseUrl)}/content/items',
      type: type,
      query: query,
      packageId: packageId,
    );
    final response = await _httpClient.get(
      uri,
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => ContentItem.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<List<ContentItem>> listAvailableCampaignItems({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    String? type,
    String? query,
    bool favoriteOnly = false,
  }) async {
    final uri = _buildUri(
      '${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/available',
      type: type,
      query: query,
      favoriteOnly: favoriteOnly,
    );
    final response = await _httpClient.get(
      uri,
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw _toException(response);
    }

    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .map((item) => ContentItem.fromJson(item as Map<String, Object?>))
        .toList();
  }

  @override
  Future<void> setCampaignPackage({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String packageId,
    required bool enabled,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/packages',
      ),
      headers: _headers(accessToken),
      body: jsonEncode({'packageId': packageId, 'enabled': enabled}),
    );

    if (response.statusCode != 201) {
      throw _toException(response);
    }
  }

  @override
  Future<void> disableCampaignItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    String? reason,
  }) async {
    final body = <String, Object?>{
      'baseContentItemId': itemId,
      'overrideType': 'disable',
    };
    if (reason != null) body['reason'] = reason;

    final response = await _httpClient.post(
      Uri.parse(
        '${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/overrides',
      ),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw _toException(response);
    }
  }

  @override
  Future<void> setCampaignItemFavorite({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
    required bool favorite,
  }) async {
    final uri = Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/items/$itemId/favorite');
    final response = favorite
        ? await _httpClient.post(uri, headers: _headers(accessToken))
        : await _httpClient.delete(uri, headers: _headers(accessToken));
    if (response.statusCode != 201 && response.statusCode != 204) throw _toException(response);
  }

  @override
  Future<ContentItemDetail> getCampaignItem({
    required String apiBaseUrl,
    required String accessToken,
    required String campaignId,
    required String itemId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/campaigns/$campaignId/content/items/$itemId'),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) throw _toException(response);
    return ContentItemDetail.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }

  Map<String, String> _headers(String accessToken) {
    return {
      'content-type': 'application/json',
      'authorization': 'Bearer $accessToken',
    };
  }
}

Uri _buildUri(String base, {String? type, String? query, String? packageId, bool favoriteOnly = false}) {
  final params = <String, String>{};
  if (type != null && type.isNotEmpty) params['type'] = type;
  if (query != null && query.isNotEmpty) params['q'] = query;
  if (packageId != null && packageId.isNotEmpty) {
    params['packageId'] = packageId;
  }
  if (favoriteOnly) params['favoriteOnly'] = 'true';
  return Uri.parse(
    base,
  ).replace(queryParameters: params.isEmpty ? null : params);
}

String _normalize(String apiBaseUrl) {
  return apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
}

ContentApiException _toException(http.Response response) {
  String message;
  try {
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final raw = decoded['message'];
    message = raw is List ? raw.join(', ') : raw as String;
  } catch (_) {
    message = 'Content request failed with HTTP ${response.statusCode}.';
  }
  return ContentApiException(message, statusCode: response.statusCode);
}

class ContentApiException implements Exception {
  const ContentApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
