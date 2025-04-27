import 'package:flutter/material.dart';
import 'biometric_auth_service.dart';

class FingerprintScreen extends StatelessWidget {
  const FingerprintScreen({super.key});

  Future<void> _authenticate(BuildContext context) async {
    final biometricService = BiometricAuthService();
    try {
      await biometricService.signInWithBiometrics();
      Navigator.of(context).pushReplacementNamed('/qrscan');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fingerprint failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text('Fingerprint Authentication'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF22345A),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Fingerprint Authentication',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () => _authenticate(context),
                child: Icon(
                  Icons.fingerprint,
                  size: 90,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Touch the fingerprint sensor',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
