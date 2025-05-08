import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/api.dart' as crypto;
import 'package:pointycastle/signers/rsa_signer.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:flutter/foundation.dart';

/// Result object to return verification status and info
class SignatureVerificationResult {
  final bool isValid;
  final String message;
  final String? sessionId;

  SignatureVerificationResult({
    required this.isValid,
    required this.message,
    this.sessionId,
  });
}

/// Fully integrated: verify QR and mark attendance if valid
Future<SignatureVerificationResult> getSessionPublicKeyAndVerify(
    String scannedQrData) async {
  try {
    debugPrint('[DEBUG] Decoding scanned QR data');
    final outerJson = jsonDecode(scannedQrData);
    final String innerDataJson = outerJson['data'];
    final String signatureBase64 = outerJson['signature'];

    final sessionData = jsonDecode(innerDataJson);
    final String? sessionId = sessionData['sessionId'];
    final String? expiresAtStr = sessionData['expiresAt'];

    if (sessionId == null || expiresAtStr == null) {
      return SignatureVerificationResult(
        isValid: false,
        message: 'Missing session ID or expiry time in QR data.',
      );
    }

    final sessionDoc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) {
      return SignatureVerificationResult(
        isValid: false,
        message: 'Session not found in Firestore.',
      );
    }

    final sessionInfo = sessionDoc.data();
    final String? publicKeyBase64 = sessionInfo?['publicKey'];
    if (publicKeyBase64 == null) {
      return SignatureVerificationResult(
        isValid: false,
        message: 'Public key not found for session.',
      );
    }

    final publicKeyBytes = base64Decode(publicKeyBase64);
    final RSAPublicKey publicKey = _bytesToPublicKey(publicKeyBytes);

    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

    final messageBytes = Uint8List.fromList(utf8.encode(innerDataJson));
    final signatureBytes = base64Decode(signatureBase64);

    final bool isValid = signer.verifySignature(
      messageBytes,
      RSASignature(signatureBytes),
    );

    if (!isValid) {
      return SignatureVerificationResult(
        isValid: false,
        message: 'Signature verification failed.',
      );
    }

    // Check expiration
    final expiresAt = DateTime.parse(expiresAtStr);
    if (DateTime.now().isAfter(expiresAt)) {
      return SignatureVerificationResult(
        isValid: false,
        message: 'This session QR has expired.',
      );
    }

    // Get current user
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return SignatureVerificationResult(
        isValid: false,
        message: 'User not logged in.',
      );
    }

    // Get user info
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      return SignatureVerificationResult(
        isValid: false,
        message: 'User record not found.',
      );
    }

    final name = userDoc['name'];
    final cmsId = userDoc['cmsId'];

    // Mark attendance
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('attendees')
        .doc(user.uid)
        .set({
      'name': name,
      'cmsId': cmsId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return SignatureVerificationResult(
      isValid: true,
      message: 'Signature verified and attendance marked.',
      sessionId: sessionId,
    );
  } catch (e, stackTrace) {
    debugPrint('[ERROR] $e\n$stackTrace');
    return SignatureVerificationResult(
      isValid: false,
      message: 'Unexpected error occurred: $e',
    );
  }
}

/// Reconstruct RSAPublicKey from combined modulus + exponent bytes
RSAPublicKey _bytesToPublicKey(Uint8List bytes) {
  final modulusBytes = bytes.sublist(0, 256);
  final exponentBytes = bytes.sublist(256);

  final modulus = _bytesToBigInt(modulusBytes);
  final exponent = _bytesToBigInt(exponentBytes);

  return RSAPublicKey(modulus, exponent);
}

/// Convert Uint8List to BigInt
BigInt _bytesToBigInt(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (int i = 0; i < bytes.length; i++) {
    result = result * BigInt.from(256) + BigInt.from(bytes[i]);
  }
  return result;
}
