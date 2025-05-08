import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'secure_identification.dart'; // <-- Import this
import 'main_page_screen.dart'; // For returning to main page
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'session_lookup.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool scanned = false;
  final MobileScannerController controller = MobileScannerController();

  void _onDetect(BarcodeCapture capture) async {
    if (scanned) return;

    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      scanned = true; // Prevent multiple scans

      final code = barcodes.first.rawValue ?? '';
      print('🟡 Scanned QR code: $code');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing scanned QR...')),
      );

      // Verify signature and mark attendance
      final result = await getSessionPublicKeyAndVerify(code);
      print('✅ Signature verification result: ${result.message}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );

      await Future.delayed(const Duration(seconds: 2));
      scanned = false;
    } else {
      print('❌ No QR code detected.');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF223045),
      appBar: AppBar(
        title: const Text('QR Code Scan'),
        backgroundColor: const Color(0xFF223045),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: 340,
          height: 400,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: MobileScanner(
              controller: controller,
              onDetect: _onDetect,
            ),
          ),
        ),
      ),
    );
  }
}
