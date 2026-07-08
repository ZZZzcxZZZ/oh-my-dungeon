import 'dart:convert';

import 'package:dnd_table_client/src/features/client_mode/domain/client_mode.dart';
import 'package:dnd_table_client/src/features/rooms/data/room_api_client.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room.dart';
import 'package:dnd_table_client/src/features/rooms/domain/room_roll.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('lists rooms through the server API', () async {
    final client = RoomApiClient(
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://localhost:3000/api/rooms');

        return http.Response(
          jsonEncode([
            {
              'id': 'room-1',
              'name': 'Friday One Shot',
              'status': 'open',
              'system': 'dnd5e',
              'createdAt': '2026-07-08T00:00:00.000Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final rooms = await client.listRooms(
      apiBaseUrl: 'http://localhost:3000/api',
    );

    expect(rooms, const [Room(id: 'room-1', name: 'Friday One Shot')]);
  });

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

  test('lists room rolls through the server API', () async {
    final client = RoomApiClient(
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://localhost:3000/api/rooms/room-1/rolls',
        );

        return http.Response(
          jsonEncode([
            {
              'id': 'roll-1',
              'roomId': 'room-1',
              'notation': 'd20',
              'total': 17,
              'actorName': 'Ada',
              'actorMode': 'player',
              'createdAt': '2026-07-09T00:00:00.000Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final rolls = await client.listRolls(
      apiBaseUrl: 'http://localhost:3000/api',
      roomId: 'room-1',
    );

    expect(rolls, const [
      RoomRoll(
        id: 'roll-1',
        roomId: 'room-1',
        notation: 'd20',
        total: 17,
        actorName: 'Ada',
        actorMode: 'player',
        createdAt: '2026-07-09T00:00:00.000Z',
      ),
    ]);
  });

  test('creates a room roll through the server API', () async {
    final client = RoomApiClient(
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'http://localhost:3000/api/rooms/room-1/rolls',
        );
        expect(request.headers['x-client-mode'], 'player');
        expect(jsonDecode(request.body), {
          'notation': 'd20',
          'total': 20,
          'actorName': 'Ada',
        });

        return http.Response(
          jsonEncode({
            'id': 'roll-1',
            'roomId': 'room-1',
            'notation': 'd20',
            'total': 20,
            'actorName': 'Ada',
            'actorMode': 'player',
            'createdAt': '2026-07-09T00:00:00.000Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final roll = await client.createRoll(
      apiBaseUrl: 'http://localhost:3000/api',
      roomId: 'room-1',
      notation: 'd20',
      total: 20,
      actorName: 'Ada',
      actorMode: ClientMode.player,
    );

    expect(
      roll,
      const RoomRoll(
        id: 'roll-1',
        roomId: 'room-1',
        notation: 'd20',
        total: 20,
        actorName: 'Ada',
        actorMode: 'player',
        createdAt: '2026-07-09T00:00:00.000Z',
      ),
    );
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

  test('throws a room api exception when listing fails', () async {
    final client = RoomApiClient(
      httpClient: MockClient((request) async {
        return http.Response('Unavailable', 503);
      }),
    );

    expect(
      () => client.listRooms(apiBaseUrl: 'http://localhost:3000/api'),
      throwsA(isA<RoomApiException>()),
    );
  });

  test('throws a room api exception when room roll creation fails', () async {
    final client = RoomApiClient(
      httpClient: MockClient((request) async {
        return http.Response('Bad Request', 400);
      }),
    );

    expect(
      () => client.createRoll(
        apiBaseUrl: 'http://localhost:3000/api',
        roomId: 'room-1',
        notation: 'd20',
        total: 20,
        actorName: 'Ada',
        actorMode: ClientMode.player,
      ),
      throwsA(isA<RoomApiException>()),
    );
  });
}
