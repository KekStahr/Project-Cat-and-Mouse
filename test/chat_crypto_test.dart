import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_genz/chat_crypto.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('only enrolled devices can decrypt encrypted group messages', () async {
    final alice = ChatCrypto();
    final bob = ChatCrypto();
    final aliceKey = await alice.initialize('alice', registeredPublicKey: null);
    final bobKey = await bob.initialize('bob', registeredPublicKey: null);

    final payload = await alice.encryptForMembers(
      text: 'Treffen am Eingang',
      groupId: 'group-1',
      senderId: 'alice',
      publicKeys: {'alice': aliceKey, 'bob': bobKey},
    );

    expect(
      await alice.decryptForMember(
        payload: payload,
        groupId: 'group-1',
        senderId: 'alice',
        recipientId: 'alice',
      ),
      'Treffen am Eingang',
    );
    expect(
      await bob.decryptForMember(
        payload: payload,
        groupId: 'group-1',
        senderId: 'alice',
        recipientId: 'bob',
      ),
      'Treffen am Eingang',
    );
    expect(
      await bob.decryptForMember(
        payload: payload,
        groupId: 'group-1',
        senderId: 'alice',
        recipientId: 'late-member',
      ),
      isNull,
    );
    expect(jsonEncode(payload), isNot(contains('Treffen am Eingang')));
  });

  test('does not silently replace a lost private key', () async {
    final crypto = ChatCrypto();
    final registeredKey = base64Encode(List<int>.filled(32, 1));

    await expectLater(
      crypto.initialize(
        'member-with-lost-key',
        registeredPublicKey: registeredKey,
      ),
      throwsA(isA<ChatCryptoException>()),
    );
  });
}
