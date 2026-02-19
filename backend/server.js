/**
 * Campus Ride-Share Backend — Express Server
 * Entry point: mounts all routes, configures CORS & JSON parsing.
 */
require('dotenv').config();
const express = require('express');
const cors = require('cors');

const userRoutes    = require('./routes/users');
const tripRoutes    = require('./routes/trips');
const bookingRoutes = require('./routes/bookings');
const ratingRoutes  = require('./routes/ratings');
const paymentRoutes = require('./routes/payments');

const app = express();
const PORT = process.env.PORT || 5000;

// ── Middleware ────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Health check ─────────────────────────────────────────
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── API Routes ───────────────────────────────────────────
app.use('/api/users',    userRoutes);
app.use('/api/trips',    tripRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/ratings',  ratingRoutes);
app.use('/api/payments', paymentRoutes);

// ── Global error handler ─────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Start ────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🚗 Campus Ride-Share API running on http://localhost:${PORT}`);
});
