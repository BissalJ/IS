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

class BiometricAuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _cryptoService = AuthCryptoService();

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

  Future<UserCredential> signInWithBiometrics() async {
    try {
      // Ensure clean state
      await _auth.signOut();

      // 1. Get server challenge
      final challenge = await _generateServerChallenge();

      // 2. Access private key with biometrics
      final keyPair = await _cryptoService.getKeyPairWithBiometrics();

      // 3. Sign the challenge
      final signature = _signData(challenge, keyPair.privateKey);

      // 4. Get the public key from the stored key pair
      final rsaPublicKey = keyPair.publicKey as RSAPublicKey;
      final publicKeyString = _serializePublicKey(keyPair.publicKey);

      // 5. Find the user ID by searching for the public key
      final querySnapshot = await _firestore
          .collection('userKeys')
          .where('publicKey', isEqualTo: publicKeyString)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('No user found with this key pair');
      }

      final userId = querySnapshot.docs.first.id;

      // 7. Verify with Firebase
      final token = await _verifySignature(
        userId: userId,
        challenge: challenge,
        signature: signature,
      );

      // 8. Sign in with the custom token
      final userCredential = await _auth.signInWithCustomToken(token);

      // 9. Verify the sign in was successful
      if (userCredential.user == null) {
        throw Exception('Failed to sign in with custom token');
      }

      return userCredential;
    } catch (e) {
      // Ensure clean state on error
      await _auth.signOut();
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
