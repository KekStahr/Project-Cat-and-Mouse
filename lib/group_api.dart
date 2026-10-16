import 'dart:convert';

import 'package:http/http.dart' as http;

const _defaultApiUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://project-cat-and-mouse.onrender.com',
);

class GroupApi {
  GroupApi({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse(_defaultApiUrl);

  final http.Client _client;
  final Uri _baseUri;

  Future<Map<String, dynamic>> createGroup({
    required String groupName,
    required String memberName,
    required int expiresInMinutes,
    String? memberId,
  }) => _send(
    'POST',
    '/api/groups',
    memberId: memberId,
    body: {
      'groupName': groupName,
      'memberName': memberName,
      'expiresInMinutes': expiresInMinutes,
    },
  );

  Future<Map<String, dynamic>> joinGroup({
    required String inviteCode,
    required String memberName,
  }) => _send(
    'POST',
    '/api/groups/join',
    body: {'inviteCode': inviteCode, 'memberName': memberName},
  );

  Future<void> leaveGroup({
    required String groupId,
    required String memberId,
  }) async {
    await _send(
      'POST',
      '/api/groups/$groupId/leave',
      memberId: memberId,
      body: const {},
      expectBody: false,
    );
  }

  Future<Map<String, dynamic>> fetchGroup({
    required String groupId,
    required String memberId,
  }) => _send('GET', '/api/groups/$groupId', memberId: memberId);

  Future<Map<String, dynamic>> sendMessage({
    required String groupId,
    required String memberId,
    required String channel,
    String? recipientId,
    required Map<String, Object?> encryptedPayload,
  }) => _send(
    'POST',
    '/api/groups/$groupId/messages',
    memberId: memberId,
    body: {
      'channel': channel,
      'recipientId': recipientId,
      'encryptedPayload': encryptedPayload,
    },
  );

  Future<Map<String, dynamic>> rotateInvite({
    required String groupId,
    required String memberId,
  }) => _send(
    'POST',
    '/api/groups/$groupId/invite/rotate',
    memberId: memberId,
    body: const {},
  );

  Future<void> kickMember({
    required String groupId,
    required String memberId,
    required String targetMemberId,
  }) async {
    await _send(
      'POST',
      '/api/groups/$groupId/members/$targetMemberId/kick',
      memberId: memberId,
      body: const {},
      expectBody: false,
    );
  }

  Future<void> registerChatKey({
    required String groupId,
    required String memberId,
    required String publicKey,
  }) async {
    await _send(
      'PATCH',
      '/api/groups/$groupId/members/me/key',
      memberId: memberId,
      body: {'publicKey': publicKey},
    );
  }

  Future<void> updateLocation({
    required String groupId,
    required String memberId,
    double? latitude,
    double? longitude,
  }) async {
    await _send(
      'PATCH',
      '/api/groups/$groupId/location',
      memberId: memberId,
      body: latitude == null || longitude == null
          ? {'enabled': false}
          : {'latitude': latitude, 'longitude': longitude},
      expectBody: false,
    );
  }

  Future<Map<String, dynamic>> promoteToOfficer({
    required String groupId,
    required String memberId,
    required String targetMemberId,
  }) => _send(
    'POST',
    '/api/groups/$groupId/members/$targetMemberId/promote',
    memberId: memberId,
    body: const {},
  );

  Future<void> joinOfficerGroup({
    required String groupId,
    required String memberId,
    required String officerId,
  }) async {
    await _send(
      'PATCH',
      '/api/groups/$groupId/members/me/officer',
      memberId: memberId,
      body: {'officerId': officerId},
      expectBody: false,
    );
  }

  Future<Map<String, dynamic>> createPing({
    required String groupId,
    required String memberId,
    required String type,
    required double latitude,
    required double longitude,
    String? targetMemberId,
    String targetScope = 'all',
  }) => _send(
    'POST',
    '/api/groups/$groupId/pings',
    memberId: memberId,
    body: {
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'targetMemberId': targetMemberId,
      'targetScope': targetScope,
    },
  );

  Future<void> acknowledgePing({
    required String groupId,
    required String memberId,
    required String pingId,
  }) async {
    await _send(
      'POST',
      '/api/groups/$groupId/pings/$pingId/ack',
      memberId: memberId,
      expectBody: false,
    );
  }

  Future<Map<String, dynamic>> movePing({
    required String groupId,
    required String memberId,
    required String pingId,
    required double latitude,
    required double longitude,
  }) => _send(
    'PATCH',
    '/api/groups/$groupId/pings/$pingId',
    memberId: memberId,
    body: {'latitude': latitude, 'longitude': longitude},
  );

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? memberId,
    Map<String, Object?>? body,
    bool expectBody = true,
  }) async {
    final uri = _baseUri.resolve(path);
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      'X-Member-Id': ?memberId,
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encodedBody),
      'PATCH' => await _client.patch(uri, headers: headers, body: encodedBody),
      _ => throw ArgumentError.value(method, 'method'),
    };
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Server request failed (${response.statusCode}).';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] is String) message = data['error'] as String;
      } on FormatException {
        // Keep the status-based message when the response is not JSON.
      }
      throw GroupApiException(message);
    }
    if (!expectBody || response.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void close() => _client.close();
}

class GroupApiException implements Exception {
  const GroupApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
