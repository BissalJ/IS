import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'secure_identification.dart';

class AttendanceService {
  static Future<String?> markAttendanceFromQr(String encryptedQr) async {
    try {
      // 1. Decrypt QR data
      final qrData = await SecureIdentification.decryptQrData(encryptedQr);
      if (qrData == null) return 'Invalid QR code';

      // 2. Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Not logged in';

      final sessionId = qrData['sessionId'] as String;

      // 3. Verify session exists and is active
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) return 'Session not found';
      if (sessionDoc['status'] != 'active') return 'Session not active';

      // 4. Check for existing attendance
      final attendanceRef = FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .collection('attendees')
          .doc(user.uid);

      if ((await attendanceRef.get()).exists) {
        return 'Attendance already recorded';
      }

      // 5. Get user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return 'User profile missing';

      // 6. Record attendance
      await attendanceRef.set({
        'userId': user.uid,
        'name': userDoc['name'],
        'email': user.email,
        'cmsId': userDoc['cmsId'],
        'timestamp': FieldValue.serverTimestamp(),
        'verifiedBy': 'qr_scan',
      });

      // 7. Update session counters
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .update({
        'attendeeCount': FieldValue.increment(1),
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      return null; // Success
    } on FirebaseException catch (e) {
      return 'Database error: ${e.message}';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }
}
