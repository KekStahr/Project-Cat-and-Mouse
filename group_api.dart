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
  }) => _send(
    'POST',
    '/api/groups',
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

  Future<Map<String, dynamic>> fetchGroup({
    required String groupId,
    required String memberId,
  }) => _send('GET', '/api/groups/$groupId', memberId: memberId);

  Future<Map<String, dynamic>> sendMessage({
    required String groupId,
    required String memberId,
    required String text,
  }) => _send(
    'POST',
    '/api/groups/$groupId/messages',
    memberId: memberId,
    body: {'text': text},
  );

  Future<Map<String, dynamic>> createPing({
    required String groupId,
    required String memberId,
    required String type,
  }) => _send(
    'POST',
    '/api/groups/$groupId/pings',
    memberId: memberId,
    body: {'type': type},
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

  Future<Map<String, dynamic>> updateName({
    required String groupId,
    required String memberId,
    required String name,
  }) => _send(
    'PATCH',
    '/api/groups/$groupId/members/me',
    memberId: memberId,
    body: {'name': name},
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
      var message = 'Server nicht erreichbar (${response.statusCode}).';
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
