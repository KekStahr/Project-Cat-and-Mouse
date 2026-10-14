import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChatCrypto {
  ChatCrypto({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static final _x25519 = X25519();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _cipher = AesGcm.with256bits();

  final FlutterSecureStorage _storage;

  Future<String> initialize(
    String memberId, {
    required String? registeredPublicKey,
  }) async {
    final privateKey = await _storage.read(key: _privateKeyName(memberId));
    final publicKey = await _storage.read(key: _publicKeyName(memberId));
    if (privateKey != null && publicKey != null) {
      if (registeredPublicKey != null && publicKey != registeredPublicKey) {
        throw const ChatCryptoException(
          'Der gespeicherte Chat-Schlüssel stimmt nicht mit dem Server überein.',
        );
      }
      return publicKey;
    }
    if (privateKey != null ||
        publicKey != null ||
        registeredPublicKey != null) {
      throw const ChatCryptoException(
        'Der private Chat-Schlüssel fehlt auf diesem Gerät. Alte Nachrichten können nicht wiederhergestellt werden.',
      );
    }

    final keyPair = await _x25519.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicBytes = await keyPair.extractPublicKey();
    final encodedPrivateKey = base64Encode(privateBytes);
    final encodedPublicKey = base64Encode(publicBytes.bytes);
    await _storage.write(
      key: _privateKeyName(memberId),
      value: encodedPrivateKey,
    );
    await _storage.write(
      key: _publicKeyName(memberId),
      value: encodedPublicKey,
    );
    return encodedPublicKey;
  }

  Future<Map<String, Object?>> encryptForMembers({
    required String text,
    required String groupId,
    required String senderId,
    required Map<String, String> publicKeys,
  }) async {
    final recipients = <String, Object?>{};
    for (final entry in publicKeys.entries) {
      final ephemeralKeyPair = await _x25519.newKeyPair();
      final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
      final salt = ephemeralPublicKey.bytes;
      final context = _context(groupId, senderId, entry.key);
      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: ephemeralKeyPair,
        remotePublicKey: _publicKey(entry.value),
      );
      final messageKey = await _hkdf.deriveKey(
        secretKey: sharedSecret,
        nonce: salt,
        info: context,
      );
      final secretBox = await _cipher.encrypt(
        utf8.encode(text),
        secretKey: messageKey,
        aad: context,
      );
      recipients[entry.key] = {
        'ephemeralKey': base64Encode(ephemeralPublicKey.bytes),
        'salt': base64Encode(salt),
        'nonce': base64Encode(secretBox.nonce),
        'cipherText': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      };
    }
    return {'version': 1, 'recipients': recipients};
  }

  Future<String?> decryptForMember({
    required Map<String, dynamic> payload,
    required String groupId,
    required String senderId,
    required String recipientId,
  }) async {
    final recipients = payload['recipients'];
    if (payload['version'] != 1 || recipients is! Map) {
      throw const ChatCryptoException('Das Nachrichtenformat ist ungültig.');
    }
    final value = recipients[recipientId];
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const ChatCryptoException(
        'Der verschlüsselte Nachrichtenschlüssel ist ungültig.',
      );
    }

    final privateKeyBytes = await _storage.read(
      key: _privateKeyName(recipientId),
    );
    final publicKeyBytes = await _storage.read(
      key: _publicKeyName(recipientId),
    );
    if (privateKeyBytes == null || publicKeyBytes == null) {
      throw const ChatCryptoException(
        'Der private Chat-Schlüssel fehlt auf diesem Gerät.',
      );
    }
    final keyPair = SimpleKeyPairData(
      base64Decode(privateKeyBytes),
      publicKey: _publicKey(publicKeyBytes),
      type: KeyPairType.x25519,
    );
    final ephemeralBytes = _requiredBytes(value, 'ephemeralKey');
    final salt = _requiredBytes(value, 'salt');
    final context = _context(groupId, senderId, recipientId);
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        ephemeralBytes,
        type: KeyPairType.x25519,
      ),
    );
    final messageKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: salt,
      info: context,
    );
    final clearText = await _cipher.decrypt(
      SecretBox(
        _requiredBytes(value, 'cipherText'),
        nonce: _requiredBytes(value, 'nonce'),
        mac: Mac(_requiredBytes(value, 'mac')),
      ),
      secretKey: messageKey,
      aad: context,
    );
    return utf8.decode(clearText);
  }

  static SimplePublicKey _publicKey(String encoded) =>
      SimplePublicKey(base64Decode(encoded), type: KeyPairType.x25519);

  static List<int> _requiredBytes(Map<String, dynamic> value, String key) {
    final encoded = value[key];
    if (encoded is! String) {
      throw ChatCryptoException(
        'Verschlüsseltes Nachrichtenfeld "$key" fehlt.',
      );
    }
    try {
      return base64Decode(encoded);
    } on FormatException {
      throw ChatCryptoException(
        'Verschlüsseltes Nachrichtenfeld "$key" ist ungültig.',
      );
    }
  }

  static List<int> _context(
    String groupId,
    String senderId,
    String recipientId,
  ) => utf8.encode('reso-chat-v1|$groupId|$senderId|$recipientId');

  static String _privateKeyName(String memberId) =>
      'reso.chat.private.$memberId';

  static String _publicKeyName(String memberId) => 'reso.chat.public.$memberId';
}

class ChatCryptoException implements Exception {
  const ChatCryptoException(this.message);

  final String message;

  @override
  String toString() => message;
}
