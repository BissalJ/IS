import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/signers/rsa_signer.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'auth_crypto_service.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _cryptoService = AuthCryptoService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<void> registerWithCredentials(String userId) async {
    try {
      // 1. Generate key pair
      final keyPair = await _cryptoService.generateKeyPair();

      // 2. Store private key securely
      await _cryptoService.storeKeyPair(keyPair);

      // 3. Store public key in Firestore
      final publicKeyString = _serializePublicKey(keyPair.publicKey);

      await _firestore.collection('userKeys').doc(userId).set({
        'publicKey': publicKeyString,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<void> signInWithBiometrics() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint to authenticate',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!didAuthenticate) {
        throw Exception('Biometric authentication failed');
      }
      // If successful, just return
      return;
    } catch (e) {
      throw Exception('Biometric authentication failed: $e');
    }
  }

  Future<String> _generateServerChallenge() async {
    final random = Random.secure();
    final challenge = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(challenge);
  }

  String _signData(String data, PrivateKey privateKey) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    final rsaPrivateKey = privateKey as RSAPrivateKey;
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(rsaPrivateKey));

    final bytes = Uint8List.fromList(utf8.encode(data));
    final signature = signer.generateSignature(bytes);

    return base64Encode(signature.bytes);
  }

  Future<String> _verifySignature({
    required String userId,
    required String challenge,
    required String signature,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyBiometricSignature');
      final result = await callable.call({
        'userId': userId,
        'challenge': challenge,
        'signature': signature,
      });

      // Ensure we're getting a token string
      if (result.data is Map && result.data['token'] is String) {
        return result.data['token'];
      }
      throw Exception('Invalid token format returned from server');
    } catch (e) {
      throw Exception('Failed to verify signature: $e');
    }
  }

  String _serializePublicKey(PublicKey publicKey) {
    final rsaPublicKey = publicKey as RSAPublicKey;
    // Convert to a consistent string format
    return base64Encode(utf8.encode(rsaPublicKey.modulus!.toRadixString(16)));
  }
}
