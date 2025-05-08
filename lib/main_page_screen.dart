import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'secure_identification.dart';
//import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/signers/rsa_signer.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/api.dart' as crypto;
import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart' as pc;
import 'dart:math';

class MainPageScreen extends StatefulWidget {
  const MainPageScreen({super.key});

  @override
  State<MainPageScreen> createState() => _MainPageScreenState();
}

class _MainPageScreenState extends State<MainPageScreen> {
  String _name = 'Loading...';
  String _cmsId = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            _name = docSnapshot.data()?['name'] ?? 'Not found';
            _cmsId = docSnapshot.data()?['cmsId'] ?? 'Not found';
          });
        }
      }
    } catch (e) {
      setState(() {
        _name = 'Error loading data';
        _cmsId = 'Error loading data';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E5D),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile avatar
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 60, color: Color(0xFF4B7BAE)),
              ),
              const SizedBox(height: 24),
              // Greeting
              Text(
                'Welcome,',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              // Name
              Text(
                _name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Card for student info
              Card(
                color: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: Row(
                    children: [
                      Icon(Icons.badge, color: Color(0xFF4B7BAE)),
                      SizedBox(width: 12),
                      Text(
                        'Student ID:',
                        style: TextStyle(
                          color: Color(0xFF4B7BAE),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        _cmsId,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Mark Attendance Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/fingerprint');
                },
                icon: Icon(Icons.fingerprint, color: Color(0xFF1B3A4B)),
                label: Text(
                  'Mark Attendance',
                  style: TextStyle(
                    color: Color(0xFF1B3A4B),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> verifyAndMarkAttendance(String qrEncryptedData) async {
  try {
    debugPrint('[DEBUG] Starting attendance verification process');
    debugPrint('[DEBUG] QR Data Received: $qrEncryptedData');

    // Step 1: Decrypt and verify QR data
    debugPrint('[DEBUG] Step 1: Decrypting QR data...');
    final data = await SecureIdentification.decryptQrData(qrEncryptedData);
    if (data == null) {
      debugPrint('[DEBUG] QR data decryption failed - returned null');
      return 'QR data is invalid or corrupted.';
    }
    debugPrint('[DEBUG] Decrypted QR Data: $data');

    final sessionId = data['sessionId'];
    final expiresAtStr = data['expiresAt'];
    final classId = data['classId']; // optional
    final user = FirebaseAuth.instance.currentUser;

    debugPrint('[DEBUG] Extracted sessionId: $sessionId');
    debugPrint('[DEBUG] Extracted expiresAt: $expiresAtStr');
    debugPrint('[DEBUG] Current user: ${user?.uid}');

    // Step 2: Check if user is logged in
    if (user == null) {
      debugPrint('[DEBUG] User not logged in - aborting');
      return 'User not logged in';
    }

    // Step 3: Check expiry
    debugPrint('[DEBUG] Step 3: Checking session expiry...');
    final expiresAt = DateTime.parse(expiresAtStr);
    debugPrint('[DEBUG] ExpiresAt parsed: $expiresAt');
    debugPrint('[DEBUG] Current time: ${DateTime.now()}');

    if (DateTime.now().isAfter(expiresAt)) {
      debugPrint('[DEBUG] Session has expired');
      return 'This session has expired';
    }

    // Step 4: Fetch session data from Firestore
    debugPrint('[DEBUG] Step 4: Fetching session data from Firestore...');
    final sessionDoc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .get();

    debugPrint('[DEBUG] Session document exists: ${sessionDoc.exists}');
    if (!sessionDoc.exists) return 'Session not found';

    final sessionData = sessionDoc.data();
    debugPrint('[DEBUG] Session data: $sessionData');

    if (sessionData == null || sessionData['status'] != 'active') {
      debugPrint('[DEBUG] Session not active or data null');
      return 'This session is no longer active';
    }

    // Step 5: Fetch public key from Firestore
    debugPrint('[DEBUG] Step 5: Fetching public key...');
    final publicKeyPem = sessionData['publicKey'];
    if (publicKeyPem == null) {
      debugPrint('[DEBUG] Public key not found in session data');
      return 'Public key not found for this session';
    }
    debugPrint(
        '[DEBUG] Public key found (first 50 chars): ${publicKeyPem.toString().substring(0, min(50, publicKeyPem.length))}');

    // Step 6: Extract signature and message
    debugPrint('[DEBUG] Step 6: Extracting signature and message...');
    final signatureBase64 = data['signature']?.toString();
    final message = data['sessionId'] + data['expiresAt'];

    debugPrint('[DEBUG] Message to verify: $message');
    debugPrint(
        '[DEBUG] Signature (first 50 chars): ${signatureBase64?.substring(0, min(50, signatureBase64?.length ?? 0))}');

    if (signatureBase64 == null) {
      debugPrint('[DEBUG] Signature not found in QR data');
      return 'Signature not found in QR data';
    }

    // Step 7: Verify signature
    debugPrint('[DEBUG] Step 7: Verifying signature...');
    final verified = await SecureIdentification.verifySignature(
      publicKeyPem: publicKeyPem,
      message: message,
      signatureBase64: signatureBase64,
    );

    debugPrint('[DEBUG] Signature verification result: $verified');
    if (!verified) {
      debugPrint('[DEBUG] Signature verification failed');
      return 'Signature verification failed';
    }

    // Step 8: Fetch user data from Firestore
    debugPrint('[DEBUG] Step 8: Fetching user data...');
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    debugPrint('[DEBUG] User document exists: ${userDoc.exists}');
    if (!userDoc.exists) return 'User data not found';

    final name = userDoc['name'];
    final cmsId = userDoc['cmsId'];
    debugPrint('[DEBUG] User details - Name: $name, CMS ID: $cmsId');

    // Step 9: Mark attendance for the user in the session
    debugPrint('[DEBUG] Step 9: Marking attendance...');
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

    debugPrint('[DEBUG] Attendance marked successfully!');
    return null; // Success, attendance marked
  } catch (e, stackTrace) {
    debugPrint('[DEBUG] Error caught: $e');
    debugPrint('[DEBUG] Stack trace: $stackTrace');
    return 'Error: ${e.toString()}';
  }
}
