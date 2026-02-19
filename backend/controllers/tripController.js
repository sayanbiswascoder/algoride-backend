/**
 * Trip Controller
 * Handles trip creation, listing, detail view, and status updates.
 * Uses Firestore.
 */
const { db } = require('../models/firebase');

const tripsRef = db.collection('trips');
const usersRef = db.collection('users');

// POST /api/trips — Create a new trip
async function createTrip(req, res) {
    try {
        const {
            driverId, origin, originLat, originLng,
            destination, destinationLat, destinationLng,
            distance, departureTime, seatsAvailable, pricePerKm,
        } = req.body;

        if (!driverId || !origin || !destination || !departureTime || !seatsAvailable || !pricePerKm) {
            return res.status(400).json({ error: 'Missing required trip fields' });
        }

        const tripData = {
            driverId,
            origin,
            originLat: originLat || null,
            originLng: originLng || null,
            destination,
            destinationLat: destinationLat || null,
            destinationLng: destinationLng || null,
            distance: distance || 0,
            departureTime: new Date(departureTime).toISOString(),
            seatsAvailable: parseInt(seatsAvailable, 10),
            pricePerKm: parseFloat(pricePerKm),
            status: 'active',
            createdAt: new Date().toISOString(),
        };

        const docRef = await tripsRef.add(tripData);

        // Increment driver's total trips count
        const driverDoc = await usersRef.doc(driverId).get();
        if (driverDoc.exists) {
            await usersRef.doc(driverId).update({
                totalTrips: (driverDoc.data().totalTrips || 0) + 1,
            });
        }

        res.status(201).json({ id: docRef.id, ...tripData });
    } catch (err) {
        console.error('createTrip error:', err);
        res.status(500).json({ error: 'Failed to create trip' });
    }
}

// GET /api/trips — List all active trips (with optional filtering)
async function getTrips(req, res) {
    try {
        const { origin, destination, status } = req.query;

        let query = tripsRef.orderBy('departureTime', 'asc');

        // Filter by status (default: active)
        const filterStatus = status || 'active';
        query = query.where('status', '==', filterStatus);

        const snapshot = await query.get();
        let trips = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

        // Client-side filtering for text contains (Firestore doesn't support contains)
        if (origin) {
            const lowerOrigin = origin.toLowerCase();
            trips = trips.filter(t => t.origin.toLowerCase().includes(lowerOrigin));
        }
        if (destination) {
            const lowerDest = destination.toLowerCase();
            trips = trips.filter(t => t.destination.toLowerCase().includes(lowerDest));
        }

        // Attach driver info
        for (const trip of trips) {
            const driverDoc = await usersRef.doc(trip.driverId).get();
            if (driverDoc.exists) {
                const d = driverDoc.data();
                trip.driver = { id: driverDoc.id, name: d.name, rating: d.rating, walletAddress: d.walletAddress };
            } else {
                trip.driver = null;
            }
        }

        res.json(trips);
    } catch (err) {
        console.error('getTrips error:', err);
        res.status(500).json({ error: 'Failed to fetch trips' });
    }
}

// GET /api/trips/:id — Get single trip with driver & bookings
async function getTrip(req, res) {
    try {
        const doc = await tripsRef.doc(req.params.id).get();
        if (!doc.exists) return res.status(404).json({ error: 'Trip not found' });

        const trip = { id: doc.id, ...doc.data() };

        // Attach driver info
        const driverDoc = await usersRef.doc(trip.driverId).get();
        if (driverDoc.exists) {
            const d = driverDoc.data();
            trip.driver = { id: driverDoc.id, name: d.name, rating: d.rating, walletAddress: d.walletAddress };
        }

        // Attach bookings with rider info
        const bookingsSnap = await db.collection('bookings')
            .where('tripId', '==', req.params.id)
            .get();
        trip.bookings = [];
        for (const bDoc of bookingsSnap.docs) {
            const booking = { id: bDoc.id, ...bDoc.data() };
            const riderDoc = await usersRef.doc(booking.riderId).get();
            if (riderDoc.exists) {
                const r = riderDoc.data();
                booking.rider = { id: riderDoc.id, name: r.name, rating: r.rating };
            }
            trip.bookings.push(booking);
        }

        res.json(trip);
    } catch (err) {
        console.error('getTrip error:', err);
        res.status(500).json({ error: 'Failed to fetch trip' });
    }
}

// GET /api/trips/driver/:driverId — Get trips by driver
async function getTripsByDriver(req, res) {
    try {
        const snapshot = await tripsRef
            .where('driverId', '==', req.params.driverId)
            .orderBy('createdAt', 'desc')
            .get();

        const trips = [];
        for (const doc of snapshot.docs) {
            const trip = { id: doc.id, ...doc.data() };

            // Attach bookings with rider info
            const bookingsSnap = await db.collection('bookings')
                .where('tripId', '==', doc.id)
                .get();
            trip.bookings = [];
            for (const bDoc of bookingsSnap.docs) {
                const booking = { id: bDoc.id, ...bDoc.data() };
                const riderDoc = await usersRef.doc(booking.riderId).get();
                if (riderDoc.exists) {
                    booking.rider = { id: riderDoc.id, name: riderDoc.data().name };
                }
                trip.bookings.push(booking);
            }

            trips.push(trip);
        }

        res.json(trips);
    } catch (err) {
        console.error('getTripsByDriver error:', err);
        res.status(500).json({ error: 'Failed to fetch driver trips' });
    }
}

// PATCH /api/trips/:id/status — Update trip status (complete, cancel)
async function updateTripStatus(req, res) {
    try {
        const { status } = req.body;
        if (!['active', 'in_progress', 'completed', 'cancelled'].includes(status)) {
            return res.status(400).json({ error: 'Invalid status' });
        }

        await tripsRef.doc(req.params.id).update({ status });

        // If trip completed, update all confirmed bookings to completed
        if (status === 'completed') {
            const bookingsSnap = await db.collection('bookings')
                .where('tripId', '==', req.params.id)
                .where('status', '==', 'confirmed')
                .get();

            const batch = db.batch();
            bookingsSnap.docs.forEach(doc => {
                batch.update(doc.ref, { status: 'completed' });
            });
            await batch.commit();
        }

        const updated = await tripsRef.doc(req.params.id).get();
        res.json({ id: updated.id, ...updated.data() });
    } catch (err) {
        console.error('updateTripStatus error:', err);
        res.status(500).json({ error: 'Failed to update trip status' });
    }
}

module.exports = { createTrip, getTrips, getTrip, getTripsByDriver, updateTripStatus };
