/**
 * User Controller
 * Handles user registration, retrieval, and profile updates.
 * Uses Firestore — documents keyed by Firebase Auth UID.
 */
const { db } = require('../models/firebase');

const usersRef = db.collection('users');

// POST /api/users — Create user profile in Firestore (after Firebase Auth signup on frontend)
async function createUser(req, res) {
    try {
        const { uid } = req.user; // from auth middleware
        const { name, email, walletAddress } = req.body;

        if (!name || !email) {
            return res.status(400).json({ error: 'Name and email are required' });
        }

        // Check if profile already exists
        const existing = await usersRef.doc(uid).get();
        if (existing.exists) {
            return res.status(409).json({ error: 'User profile already exists', user: { id: uid, ...existing.data() } });
        }

        const userData = {
            name,
            email,
            walletAddress: walletAddress || null,
            rating: 0,
            totalTrips: 0,
            createdAt: new Date().toISOString(),
        };

        await usersRef.doc(uid).set(userData);

        res.status(201).json({ id: uid, ...userData });
    } catch (err) {
        console.error('createUser error:', err);
        res.status(500).json({ error: 'Failed to create user' });
    }
}

// GET /api/users/:id — Get user by ID
async function getUser(req, res) {
    try {
        const doc = await usersRef.doc(req.params.id).get();
        if (!doc.exists) return res.status(404).json({ error: 'User not found' });

        const user = { id: doc.id, ...doc.data() };

        // Fetch recent trips as driver (last 5)
        const tripsSnap = await db.collection('trips')
            .where('driverId', '==', req.params.id)
            .orderBy('createdAt', 'desc')
            .limit(5)
            .get();
        user.tripsAsDriver = tripsSnap.docs.map(d => ({ id: d.id, ...d.data() }));

        // Fetch recent bookings as rider (last 5)
        const bookingsSnap = await db.collection('bookings')
            .where('riderId', '==', req.params.id)
            .orderBy('createdAt', 'desc')
            .limit(5)
            .get();
        const bookings = bookingsSnap.docs.map(d => ({ id: d.id, ...d.data() }));

        // Attach trip data to each booking
        for (const booking of bookings) {
            const tripDoc = await db.collection('trips').doc(booking.tripId).get();
            booking.trip = tripDoc.exists ? { id: tripDoc.id, ...tripDoc.data() } : null;
        }
        user.bookings = bookings;

        res.json(user);
    } catch (err) {
        console.error('getUser error:', err);
        res.status(500).json({ error: 'Failed to fetch user' });
    }
}

// PUT /api/users/:id — Update user profile (wallet address, name)
async function updateUser(req, res) {
    try {
        const { name, walletAddress } = req.body;
        const data = {};
        if (name) data.name = name;
        if (walletAddress !== undefined) data.walletAddress = walletAddress;

        await usersRef.doc(req.params.id).update(data);

        const updated = await usersRef.doc(req.params.id).get();
        res.json({ id: updated.id, ...updated.data() });
    } catch (err) {
        console.error('updateUser error:', err);
        res.status(500).json({ error: 'Failed to update user' });
    }
}

module.exports = { createUser, getUser, updateUser };
