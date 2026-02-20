/**
 * Booking Controller
 * Handles seat booking, listing, and status updates.
 * Uses Firestore with transactions for atomic operations.
 */
const { db } = require('../models/firebase');
const fetch = require('node-fetch');

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

            // Calculate fare: flat price × seats
            const totalFare = parseFloat((trip.price * seats).toFixed(6));

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

// POST /api/bookings/:id/confirm-payment — Verify on-chain ALGO tx and confirm booking
async function confirmBookingPayment(req, res) {
    try {
        const { txId } = req.body;
        const bookingId = req.params.id;

        if (!txId) {
            return res.status(400).json({ error: 'txId is required' });
        }

        // Fetch the booking
        const bookingDoc = await bookingsRef.doc(bookingId).get();
        if (!bookingDoc.exists) {
            return res.status(404).json({ error: 'Booking not found' });
        }
        const booking = bookingDoc.data();

        if (booking.status === 'confirmed') {
            return res.status(400).json({ error: 'Booking is already confirmed' });
        }

        // Fetch the trip to get driver wallet and verify fare
        const tripDoc = await tripsRef.doc(booking.tripId).get();
        if (!tripDoc.exists) {
            return res.status(404).json({ error: 'Trip not found' });
        }
        const trip = tripDoc.data();

        // Get driver wallet address
        const driverDoc = await usersRef.doc(trip.driverId).get();
        if (!driverDoc.exists || !driverDoc.data().walletAddress) {
            return res.status(400).json({ error: 'Driver has no wallet address' });
        }
        const driverWallet = driverDoc.data().walletAddress;

        // Verify the transaction on-chain via Algorand Indexer (TestNet)
        const indexerUrl = `https://testnet-idx.algonode.cloud/v2/transactions/${txId}`;
        const txResponse = await fetch(indexerUrl);

        if (!txResponse.ok) {
            return res.status(400).json({ error: 'Transaction not found on chain. Please wait a moment and try again.' });
        }

        const txData = await txResponse.json();
        const tx = txData.transaction;

        if (!tx) {
            return res.status(400).json({ error: 'Invalid transaction data' });
        }

        // Verify it's a payment transaction
        if (tx['tx-type'] !== 'pay') {
            return res.status(400).json({ error: 'Transaction is not a payment transaction' });
        }

        // Verify receiver matches driver wallet
        const paymentDetails = tx['payment-transaction'];
        if (!paymentDetails) {
            return res.status(400).json({ error: 'No payment details in transaction' });
        }

        const txReceiver = paymentDetails.receiver;
        if (txReceiver.toUpperCase() !== driverWallet.toUpperCase()) {
            return res.status(400).json({ error: 'Transaction receiver does not match driver wallet' });
        }

        // Verify amount (totalFare is in ALGO, tx amount is in microAlgos)
        const expectedMicroAlgos = Math.floor(booking.totalFare * 1000000);
        const txAmount = paymentDetails.amount;
        // Allow 1% tolerance for rounding
        if (txAmount < expectedMicroAlgos * 0.99) {
            return res.status(400).json({
                error: `Insufficient payment. Expected ${booking.totalFare} ALGO, got ${txAmount / 1000000} ALGO`,
            });
        }

        // All verified — update booking and create payment record
        await bookingsRef.doc(bookingId).update({
            status: 'confirmed',
            paymentTxId: txId,
        });

        // Create payment record
        const paymentData = {
            bookingId,
            userId: booking.riderId,
            txId,
            amount: booking.totalFare,
            status: 'completed',
            verifiedOnChain: true,
            createdAt: new Date().toISOString(),
        };
        await db.collection('payments').add(paymentData);

        const updated = await bookingsRef.doc(bookingId).get();
        res.json({ id: updated.id, ...updated.data(), paymentVerified: true });
    } catch (err) {
        console.error('confirmBookingPayment error:', err);
        res.status(500).json({ error: 'Failed to confirm payment' });
    }
}

module.exports = { createBooking, getBookingsByUser, updateBookingStatus, confirmBookingPayment };
