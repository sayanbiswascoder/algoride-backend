/**
 * Rating Controller
 * Handles submitting ratings and computing averages.
 * Uses Firestore.
 */
const { db } = require('../models/firebase');

const ratingsRef = db.collection('ratings');
const usersRef = db.collection('users');

// POST /api/ratings — Submit a rating
async function createRating(req, res) {
    try {
        const { fromUserId, toUserId, rating, comment } = req.body;

        if (!fromUserId || !toUserId || rating === undefined) {
            return res.status(400).json({ error: 'fromUserId, toUserId, and rating are required' });
        }

        const ratingValue = parseFloat(rating);
        if (ratingValue < 1 || ratingValue > 5) {
            return res.status(400).json({ error: 'Rating must be between 1 and 5' });
        }

        const ratingData = {
            fromUserId,
            toUserId,
            rating: ratingValue,
            comment: comment || null,
            createdAt: new Date().toISOString(),
        };

        const docRef = await ratingsRef.add(ratingData);

        // Recalculate the average rating for the target user
        const allRatings = await ratingsRef.where('toUserId', '==', toUserId).get();
        let sum = 0;
        allRatings.docs.forEach(d => { sum += d.data().rating; });
        const avgRating = parseFloat((sum / allRatings.size).toFixed(2));

        await usersRef.doc(toUserId).update({ rating: avgRating });

        res.status(201).json({ id: docRef.id, ...ratingData });
    } catch (err) {
        console.error('createRating error:', err);
        res.status(500).json({ error: 'Failed to submit rating' });
    }
}

// GET /api/ratings/:userId — Get ratings received by a user
async function getRatings(req, res) {
    try {
        const snapshot = await ratingsRef
            .where('toUserId', '==', req.params.userId)
            .orderBy('createdAt', 'desc')
            .get();

        const ratings = [];
        for (const doc of snapshot.docs) {
            const r = { id: doc.id, ...doc.data() };
            const fromDoc = await usersRef.doc(r.fromUserId).get();
            if (fromDoc.exists) {
                r.fromUser = { id: fromDoc.id, name: fromDoc.data().name };
            }
            ratings.push(r);
        }

        res.json(ratings);
    } catch (err) {
        console.error('getRatings error:', err);
        res.status(500).json({ error: 'Failed to fetch ratings' });
    }
}

module.exports = { createRating, getRatings };
