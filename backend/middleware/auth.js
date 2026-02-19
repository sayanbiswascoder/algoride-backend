/**
 * Auth Middleware — verifies Firebase ID tokens.
 * Attaches decoded user (uid, email) to req.user.
 */
const { auth } = require('../models/firebase');

async function verifyToken(req, res, next) {
    const header = req.headers.authorization;

    if (!header || !header.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }

    const token = header.split('Bearer ')[1];

    try {
        const decoded = await auth.verifyIdToken(token);
        req.user = { uid: decoded.uid, email: decoded.email };
        next();
    } catch (err) {
        console.error('Token verification failed:', err.message);
        return res.status(401).json({ error: 'Invalid or expired token' });
    }
}

module.exports = verifyToken;
