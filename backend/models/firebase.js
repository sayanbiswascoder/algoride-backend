/**
 * Firebase Admin SDK — singleton init for Firestore + Auth.
 */
const admin = require('firebase-admin');
const path = require('path');

// Use service account key from project root
const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const auth = admin.auth();

module.exports = { admin, db, auth };
