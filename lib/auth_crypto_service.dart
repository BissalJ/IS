import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class AuthCryptoService {
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final String keyPairStorageKey = 'biometric_auth_keypair';

  Future<AsymmetricKeyPair<PublicKey, PrivateKey>> generateKeyPair() async {
    final keyGen = RSAKeyGenerator();
    final secureRandom = FortunaRandom();

    // Seed the random number generator
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(255));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final params = RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64);
    keyGen.init(ParametersWithRandom(params, secureRandom));

    return keyGen.generateKeyPair();
  }

  Future<void> storeKeyPair(
      AsymmetricKeyPair<PublicKey, PrivateKey> keyPair) async {
    try {
      await secureStorage.write(
        key: keyPairStorageKey,
        value: _serializeKeyPair(keyPair),
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );
    } catch (e) {
      throw Exception('Failed to store key pair: $e');
    }
  }

  Future<AsymmetricKeyPair<PublicKey, PrivateKey>>
      getKeyPairWithBiometrics() async {
    try {
      // Check if biometrics are available
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        throw Exception(
            'Biometric authentication not available on this device');
      }

      // Get available biometrics
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        throw Exception('No biometrics enrolled on this device');
      }

      // Authenticate the user
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Access your authentication keys',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!didAuthenticate) {
        throw Exception('Biometric authentication failed');
      }

      // Retrieve the key pair
      final serialized = await secureStorage.read(key: keyPairStorageKey);
      if (serialized == null) {
        throw Exception('No key pair found');
      }

      return _deserializeKeyPair(serialized);
    } catch (e) {
      throw Exception('Failed to authenticate with biometrics: $e');
    }
  }

  String _serializeKeyPair(AsymmetricKeyPair<PublicKey, PrivateKey> keyPair) {
    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    final keyPairMap = {
      'publicKey': {
        'modulus': publicKey.modulus!.toRadixString(16),
        'exponent': publicKey.exponent!.toRadixString(16),
      },
      'privateKey': {
        'modulus': privateKey.modulus!.toRadixString(16),
        'privateExponent': privateKey.privateExponent!.toRadixString(16),
        'p': privateKey.p?.toRadixString(16),
        'q': privateKey.q?.toRadixString(16),
      },
    };

    return jsonEncode(keyPairMap);
  }

  AsymmetricKeyPair<PublicKey, PrivateKey> _deserializeKeyPair(
      String serialized) {
    try {
      final keyPairMap = jsonDecode(serialized) as Map<String, dynamic>;

      final publicKeyMap = keyPairMap['publicKey'] as Map<String, dynamic>;
      final privateKeyMap = keyPairMap['privateKey'] as Map<String, dynamic>;

      final publicKey = RSAPublicKey(
        BigInt.parse(publicKeyMap['modulus'] as String, radix: 16),
        BigInt.parse(publicKeyMap['exponent'] as String, radix: 16),
      );

      final privateKey = RSAPrivateKey(
        BigInt.parse(privateKeyMap['modulus'] as String, radix: 16),
        BigInt.parse(privateKeyMap['privateExponent'] as String, radix: 16),
        privateKeyMap['p'] != null
            ? BigInt.parse(privateKeyMap['p'] as String, radix: 16)
            : null,
        privateKeyMap['q'] != null
            ? BigInt.parse(privateKeyMap['q'] as String, radix: 16)
            : null,
      );

      return AsymmetricKeyPair<PublicKey, PrivateKey>(publicKey, privateKey);
    } catch (e) {
      throw Exception('Failed to deserialize key pair: $e');
    }
  }

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );

  IOSOptions _getIOSOptions() => const IOSOptions(
        accessibility: KeychainAccessibility.passcode,
      );
}
