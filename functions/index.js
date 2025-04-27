const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

exports.verifyBiometricSignature = functions.https.onCall(async (data, context) => {
  const { userId, challenge, signature } = data;
  
  // 1. Get stored public key
  const userDoc = await admin.firestore().collection('userKeys').doc(userId).get();
  const publicKey = userDoc.data()?.publicKey;
  
  if (!publicKey) {
    throw new functions.https.HttpsError('not-found', 'Public key not found');
  }
  
  // 2. Verify signature
  const verifier = crypto.createVerify('SHA256');
  verifier.update(challenge);
  const isValid = verifier.verify(publicKey, signature, 'base64');
  
  if (!isValid) {
    throw new functions.https.HttpsError('unauthenticated', 'Invalid signature');
  }
  
  // 3. Create custom token
  return admin.auth().createCustomToken(userId);
}); 