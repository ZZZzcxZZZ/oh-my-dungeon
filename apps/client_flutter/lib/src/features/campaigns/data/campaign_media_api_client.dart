import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 上传后返回的媒体资产元数据。
class MediaAsset {
  const MediaAsset({required this.id, required this.mimeType});

  final String id;
  final String mimeType;
}

/// 读取媒体资产返回的内容。
class MediaAssetContent {
  const MediaAssetContent({required this.mimeType, required this.bytes});

  final String mimeType;
  final Uint8List bytes;
}

abstract class CampaignMediaClient {
  Future<MediaAsset> upload({
    required String apiBaseUrl,
    required String accessToken,
    required String purpose,
    required String mimeType,
    required Uint8List bytes,
    String? campaignId,
  });

  Future<MediaAssetContent> read({
    required String apiBaseUrl,
    required String accessToken,
    required String assetId,
  });
}

/// 调用服务端 `/api/media` 的 HTTP 客户端。
///
/// 上传时把字节 base64 编码进 JSON body（与服务端 MediaController 约定一致），
/// 读取时解码 base64 返回原始字节。头像和战役群文件复用同一接口，用
/// [purpose]（`avatar` / `campaignFile`）区分。
class CampaignMediaApiClient implements CampaignMediaClient {
  CampaignMediaApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  @override
  Future<MediaAsset> upload({
    required String apiBaseUrl,
    required String accessToken,
    required String purpose,
    required String mimeType,
    required Uint8List bytes,
    String? campaignId,
  }) async {
    final body = <String, Object?>{
      'purpose': purpose,
      'mimeType': mimeType,
      'base64': base64Encode(bytes),
      'campaignId': ?campaignId,
    };

    final response = await _httpClient.post(
      Uri.parse('${_normalize(apiBaseUrl)}/media'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw http.ClientException(
        'Media upload failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    return MediaAsset(
      id: json['id']! as String,
      mimeType: json['mimeType']! as String,
    );
  }

  @override
  Future<MediaAssetContent> read({
    required String apiBaseUrl,
    required String accessToken,
    required String assetId,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('${_normalize(apiBaseUrl)}/media/$assetId'),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Media read failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    return MediaAssetContent(
      mimeType: json['mimeType']! as String,
      bytes: Uint8List.fromList(base64Decode(json['base64']! as String)),
    );
  }

  String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
