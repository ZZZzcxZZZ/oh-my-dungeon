import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_table_client/src/features/campaigns/data/campaign_media_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show ClientException;
import 'package:http/testing.dart';

const _apiBaseUrl = 'http://localhost:3000/api';
const _accessToken = 'tok';

void main() {
  group('CampaignMediaApiClient', () {
    test('upload posts base64 payload and returns asset id', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'id': 'asset-1', 'mimeType': 'image/png'}),
          201,
        );
      });

      final media = CampaignMediaApiClient(httpClient: client);
      final asset = await media.upload(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        purpose: 'avatar',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(asset.id, 'asset-1');
      expect(captured.url.toString(), '$_apiBaseUrl/media');
      final body = jsonDecode(captured.body) as Map<String, Object?>;
      expect(body['purpose'], 'avatar');
      expect(body['mimeType'], 'image/png');
      expect(body['base64'], base64Encode([1, 2, 3]));
    });

    test('upload includes campaignId when provided', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'id': 'asset-2', 'mimeType': 'image/jpeg'}),
          201,
        );
      });

      final media = CampaignMediaApiClient(httpClient: client);
      await media.upload(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        purpose: 'campaignFile',
        mimeType: 'image/jpeg',
        bytes: Uint8List.fromList([9]),
        campaignId: 'camp-1',
      );

      final body = jsonDecode(captured.body) as Map<String, Object?>;
      expect(body['campaignId'], 'camp-1');
    });

    test('read returns mimeType and decoded bytes', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'id': 'asset-1',
            'mimeType': 'image/png',
            'base64': base64Encode([4, 5, 6]),
          }),
          200,
        );
      });

      final media = CampaignMediaApiClient(httpClient: client);
      final content = await media.read(
        apiBaseUrl: _apiBaseUrl,
        accessToken: _accessToken,
        assetId: 'asset-1',
      );

      expect(content.mimeType, 'image/png');
      expect(content.bytes, [4, 5, 6]);
    });

    test('upload throws on non-201', () async {
      final client = MockClient((_) async => http.Response('bad request', 400));
      final media = CampaignMediaApiClient(httpClient: client);

      expect(
        () => media.upload(
          apiBaseUrl: _apiBaseUrl,
          accessToken: _accessToken,
          purpose: 'avatar',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(isA<ClientException>()),
      );
    });
  });
}
