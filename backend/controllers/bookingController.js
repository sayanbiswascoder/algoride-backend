/**
 * Booking Controller
 * Handles seat booking, listing, and status updates.
 * Uses Firestore with transactions for atomic operations.
 */
const { db } = require('../models/firebase');

const bookingsRef = db.collection('bookings');
const tripsRef = db.collection('trips');
const usersRef = db.collection('users');

// POST /api/bookings — Book seats on a trip
async function createBooking(req, res) {
    try {
        const { tripId, riderId, seatsBooked } = req.body;

        if (!tripId || !riderId) {
            return res.status(400).json({ error: 'tripId and riderId are required' });
        }

        const seats = parseInt(seatsBooked, 10) || 1;

        // Use a transaction for atomicity (check availability + create booking + decrement seats)
        const result = await db.runTransaction(async (t) => {
            const tripDoc = await t.get(tripsRef.doc(tripId));
            if (!tripDoc.exists) throw new Error('Trip not found');

            const trip = tripDoc.data();
            if (trip.status !== 'active') throw new Error('Trip is no longer active');
            if (trip.seatsAvailable < seats) throw new Error(`Only ${trip.seatsAvailable} seats available`);
            if (trip.driverId === riderId) throw new Error('Driver cannot book own trip');

            // Calculate fare: distance × pricePerKm × seats
            const totalFare = parseFloat((trip.distance * trip.pricePerKm * seats).toFixed(6));

            const bookingData = {
                tripId,
                riderId,
                seatsBooked: seats,
                totalFare,
                paymentTxId: null,
                status: 'pending',
                createdAt: new Date().toISOString(),
            };

            const bookingRef = bookingsRef.doc();
            t.set(bookingRef, bookingData);
            t.update(tripsRef.doc(tripId), {
                seatsAvailable: trip.seatsAvailable - seats,
            });

            return { id: bookingRef.id, ...bookingData };
        });

        res.status(201).json(result);
    } catch (err) {
        console.error('createBooking error:', err);
        const msg = err.message;
        if (msg.includes('not found') || msg.includes('no longer active') || msg.includes('seats available') || msg.includes('cannot book')) {
            return res.status(400).json({ error: msg });
        }
        res.status(500).json({ error: 'Failed to create booking' });
    }
}

// GET /api/bookings/:userId — Get bookings for a user (as rider)
async function getBookingsByUser(req, res) {
    try {
        const snapshot = await bookingsRef
            .where('riderId', '==', req.params.userId)
            .orderBy('createdAt', 'desc')
            .get();

        const bookings = [];
        for (const doc of snapshot.docs) {
            const booking = { id: doc.id, ...doc.data() };

            // Attach trip data with driver info
            const tripDoc = await tripsRef.doc(booking.tripId).get();
            if (tripDoc.exists) {
                const trip = { id: tripDoc.id, ...tripDoc.data() };
                const driverDoc = await usersRef.doc(trip.driverId).get();
                if (driverDoc.exists) {
                    const d = driverDoc.data();
                    trip.driver = { id: driverDoc.id, name: d.name, rating: d.rating, walletAddress: d.walletAddress };
                }
                booking.trip = trip;
            }

            bookings.push(booking);
        }

        res.json(bookings);
    } catch (err) {
        console.error('getBookingsByUser error:', err);
        res.status(500).json({ error: 'Failed to fetch bookings' });
    }
}

// PATCH /api/bookings/:id/status — Update booking status
async function updateBookingStatus(req, res) {
    try {
        const { status, paymentTxId } = req.body;
        const data = {};
        if (status) data.status = status;
        if (paymentTxId) data.paymentTxId = paymentTxId;

        await bookingsRef.doc(req.params.id).update(data);

        const updated = await bookingsRef.doc(req.params.id).get();
        res.json({ id: updated.id, ...updated.data() });
    } catch (err) {
        console.error('updateBookingStatus error:', err);
        res.status(500).json({ error: 'Failed to update booking' });
    }
}

module.exports = { createBooking, getBookingsByUser, updateBookingStatus };
