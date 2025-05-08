import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureIdentification {
  static const String _keyStorageKey = 'secure_identification_key';

  /* Get AES key from local storage */
  static Future<encrypt.Key> _getKey() async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_keyStorageKey);
    if (storedKey == null) {
      throw Exception('Encryption key not found');
    }
    return encrypt.Key(base64Decode(storedKey));
  }

  /* Decrypt QR data and verify signature */
  static Future<Map<String, dynamic>?> decryptQrData(
      String encryptedData) async {
    try {
      // 1. Decode QR payload
      final data = jsonDecode(encryptedData) as Map<String, dynamic>;
      final iv = encrypt.IV(base64Decode(data['iv'] as String));
      final encrypted =
          encrypt.Encrypted(base64Decode(data['encryptedData'] as String));

      // 2. Decrypt AES payload
      final encrypter = encrypt.Encrypter(
        encrypt.AES(await _getKey(), mode: encrypt.AESMode.cbc),
      );
      final decryptedJson = encrypter.decrypt(encrypted, iv: iv);
      final decryptedData = jsonDecode(decryptedJson) as Map<String, dynamic>;

      // 3. HMAC Integrity check
      final payload = decryptedData['data'] as Map<String, dynamic>;
      final storedHash = base64Decode(decryptedData['integrityHash'] as String);

      final hmac = Hmac(sha256, (await _getKey()).bytes);
      final calculatedHash =
          hmac.convert(utf8.encode(jsonEncode(payload))).bytes;

      if (!_constantTimeEquals(storedHash, calculatedHash)) {
        throw Exception('Data integrity check failed');
      }

      // 4. Field validation
      final sessionId = payload['sessionId']?.toString();
      final expiresAtStr = payload['expiresAt']?.toString();
      if (sessionId == null || expiresAtStr == null) {
        throw Exception('Missing sessionId or expiresAt');
      }

      // 5. Expiration check
      final expiresAt = DateTime.parse(expiresAtStr);
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('QR code has expired');
      }

      // 6. Signature Verification
      final publicKeyPem = payload['publicKey']?.toString();
      final signatureBase64 = payload['signature']?.toString();
      final message = sessionId + expiresAtStr;

      if (publicKeyPem == null || signatureBase64 == null) {
        throw Exception('Missing publicKey or signature');
      }

      final verified = await verifySignature(
        publicKeyPem: publicKeyPem,
        message: message,
        signatureBase64: signatureBase64,
      );

      if (!verified) {
        throw Exception('Signature verification failed');
      }

      // ✅ All checks passed
      return {
        'sessionId': sessionId,
        'expiresAt': expiresAt,
        ...payload,
      };
    } catch (e) {
      debugPrint('Decryption/Verification failed: $e');
      return null;
    }
  }

  /* RSA Signature Verification */
  static Future<bool> verifySignature({
    required String publicKeyPem,
    required String message,
    required String signatureBase64,
  }) async {
    try {
      // Convert the public key from PEM format
      final RSAPublicKey publicKey =
          CryptoUtils.rsaPublicKeyFromPem(publicKeyPem);

      // Create the signer and initialize with the public key
      final signer = Signer("SHA-256/RSA");
      signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      // Convert the message to bytes and the signature from base64 to bytes
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final signatureBytes = base64Decode(signatureBase64);

      // Create RSASignature from the decoded signature bytes
      final rsaSignature = RSASignature(signatureBytes);

      // Verify the signature
      return signer.verifySignature(messageBytes, rsaSignature);
    } catch (e) {
      debugPrint('RSA Signature verification error: $e');
      return false;
    }
  }

  /* Constant-time equality check */
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
