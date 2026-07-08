import 'dart:convert';

import 'package:dnd_table_client/src/features/rooms/data/room_api_client.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('creates a room through the server API using dm mode header', () async {
    http.Request? capturedRequest;
    final client = RoomApiClient(
      httpClient: MockClient((request) async {
        capturedRequest = request;
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://localhost:3000/api/rooms');
        expect(request.headers['x-client-mode'], 'dm');
        expect(jsonDecode(request.body), {'name': 'Friday One Shot'});

        return http.Response(
          jsonEncode({
            'id': 'room-1',
            'name': 'Friday One Shot',
            'status': 'open',
            'system': 'dnd5e',
            'createdAt': '2026-07-08T00:00:00.000Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final room = await client.createRoom(
      apiBaseUrl: 'http://localhost:3000/api',
      name: 'Friday One Shot',
    );

    expect(capturedRequest, isA<http.Request>());
    expect(room, const Room(id: 'room-1', name: 'Friday One Shot'));
  });

  test('throws a room api exception when creation fails', () async {
    final client = RoomApiClient(
      httpClient: MockClient((request) async {
        return http.Response('Forbidden', 403);
      }),
    );

    expect(
      () => client.createRoom(
        apiBaseUrl: 'http://localhost:3000/api',
        name: 'Friday One Shot',
      ),
      throwsA(isA<RoomApiException>()),
    );
  });
}
