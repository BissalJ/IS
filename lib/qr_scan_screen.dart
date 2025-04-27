import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool scanned = false;
  MobileScannerController? controller;

  void _onDetect(BarcodeCapture capture) {
    if (scanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      scanned = true;
      final code = barcodes.first.rawValue ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR Code: $code')),
      );
      Navigator.of(context).popUntil(ModalRoute.withName('/main'));
    }
  }

  @override
  void dispose() {
    controller?.dispose();
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
