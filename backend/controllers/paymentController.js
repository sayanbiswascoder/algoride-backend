/**
 * Payment Controller
 * Handles payment initiation (escrow) and completion (release).
 * Uses Firestore.
 */
const { db } = require('../models/firebase');

const paymentsRef = db.collection('payments');
const bookingsRef = db.collection('bookings');

// POST /api/payments/initiate — Record payment initiation (rider sends ALGO to escrow)
async function initiatePayment(req, res) {
    try {
        const { bookingId, userId, txId, amount } = req.body;

        if (!bookingId || !userId || !txId || !amount) {
            return res.status(400).json({ error: 'bookingId, userId, txId, and amount are required' });
        }

        const paymentData = {
            bookingId,
            userId,
            txId,
            amount: parseFloat(amount),
            status: 'escrow',
            createdAt: new Date().toISOString(),
        };

        const docRef = await paymentsRef.add(paymentData);

        // Update booking with transaction ID and confirm it
        await bookingsRef.doc(bookingId).update({
            paymentTxId: txId,
            status: 'confirmed',
        });

        res.status(201).json({ id: docRef.id, ...paymentData });
    } catch (err) {
        console.error('initiatePayment error:', err);
        res.status(500).json({ error: 'Failed to initiate payment' });
    }
}

// POST /api/payments/complete — Release escrow payment to driver
async function completePayment(req, res) {
    try {
        const { paymentId, releaseTxId } = req.body;

        if (!paymentId) {
            return res.status(400).json({ error: 'paymentId is required' });
        }

        const data = { status: 'released' };
        if (releaseTxId) data.txId = releaseTxId;

        await paymentsRef.doc(paymentId).update(data);

        const updated = await paymentsRef.doc(paymentId).get();
        res.json({ id: updated.id, ...updated.data() });
    } catch (err) {
        console.error('completePayment error:', err);
        res.status(500).json({ error: 'Failed to complete payment' });
    }
}

// GET /api/payments/booking/:bookingId — Get payments for a booking
async function getPaymentsByBooking(req, res) {
    try {
        const snapshot = await paymentsRef
            .where('bookingId', '==', req.params.bookingId)
            .orderBy('createdAt', 'desc')
            .get();

        const payments = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.json(payments);
    } catch (err) {
        console.error('getPaymentsByBooking error:', err);
        res.status(500).json({ error: 'Failed to fetch payments' });
    }
}

module.exports = { initiatePayment, completePayment, getPaymentsByBooking };
