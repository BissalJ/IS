import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Helper function to hash the device ID consistently
  String _hashDeviceId(String deviceId) {
    return sha256.convert(utf8.encode(deviceId)).toString();
  }

  // Helper function to get the unique device ID
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = _uuid.v4(); // Generate new if not exists
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

  // Register user function (no change needed here)
  Future<String?> registerUser(
      String email, String password, String name, String cmsId) async {
    try {
      // Validate CMS ID format before anything
      if (!RegExp(r'^\d{6}$').hasMatch(cmsId)) {
        return 'CMS ID must be exactly 6 digits';
      }

      // Create user first to get UID (auth must exist for Firestore rules)
      final result = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user == null) return 'User creation failed';

      // Now check CMS ID uniqueness AFTER auth (required for Firestore access)
      final existing = await _firestore
          .collection('users')
          .where('cmsId', isEqualTo: cmsId)
          .get();

      if (existing.docs.isNotEmpty) {
        // Clean up the newly created Firebase Auth user
        await user.delete();
        return 'CMS ID already in use';
      }

      final deviceId = await getDeviceId();
      final hashedDeviceId = _hashDeviceId(deviceId);

      final deviceCheck = await _firestore
          .collection('users')
          .where('deviceId', isEqualTo: hashedDeviceId)
          .get();

      if (deviceCheck.docs.isNotEmpty) {
        await user.delete();
        return 'This device is already registered';
      }

      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'name': name,
        'cmsId': cmsId,
        'uid': user.uid,
        'deviceId': hashedDeviceId,
      });

      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred: $e';
    }
  }

  // Sign in function (make sure device check is consistent)
  Future<bool> signInWithUsernameAndPassword(
      String email, String password, String deviceId) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);

      final user = userCredential.user;
      if (user == null) return false;

      final hashedDeviceId = _hashDeviceId(deviceId);
      final docSnapshot =
          await _firestore.collection('users').doc(user.uid).get();
      final userDoc = docSnapshot.data();

      if (userDoc == null || userDoc['deviceId'] != hashedDeviceId) {
        await _firebaseAuth.signOut();
        return false;
      }
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (e) {
      return false;
    }
  }
}
