/**
 * API Service — Axios instance pointing to the backend.
 * Automatically attaches Firebase ID token to every request.
 */
import axios from 'axios';
import { onAuthStateChanged } from 'firebase/auth'; // Import for modular SDK
import { auth } from './firebase';

const API_URL = import.meta.env.VITE_BACKEND_URL || 'http://localhost:5000';

const api = axios.create({
    baseURL: `${API_URL}/api`,
    headers: { 'Content-Type': 'application/json' },
});

// Attach Firebase auth token to every request
api.interceptors.request.use(async (config) => {
    // 1. Check if user is already available synchronously
    let user = auth.currentUser;

    // 2. If not, wait for auth state to settle (handles page reloads/initialization)
    if (!user) {
        user = await new Promise((resolve) => {
            const unsubscribe = onAuthStateChanged(auth, (u) => {
                unsubscribe();
                resolve(u);
            });
        });
    }

    if (user) {
        const token = await user.getIdToken();
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

// ── User endpoints ────────────────────────────────────
export const registerUserProfile = (data) => api.post('/users', data);
export const getUser = (id) => api.get(`/users/${id}`);
export const updateUser = (id, data) => api.put(`/users/${id}`, data);

// ── Trip endpoints ────────────────────────────────────
export const createTrip = (data) => api.post('/trips', data);
export const getTrips = (params) => api.get('/trips', { params });
export const getTrip = (id) => api.get(`/trips/${id}`);
export const getTripsByDriver = (driverId) => api.get(`/trips/driver/${driverId}`);
export const updateTripStatus = (id, data) => api.patch(`/trips/${id}/status`, data);

// ── Booking endpoints ─────────────────────────────────
export const createBooking = (data) => api.post('/bookings', data);
export const getBookingsByUser = (userId) => api.get(`/bookings/${userId}`);
export const updateBookingStatus = (id, data) => api.patch(`/bookings/${id}/status`, data);

// ── Rating endpoints ──────────────────────────────────
export const createRating = (data) => api.post('/ratings', data);
export const getUserRatings = (userId) => api.get(`/ratings/${userId}`);

// ── Payment endpoints ─────────────────────────────────
export const initiatePayment = (data) => api.post('/payments/initiate', data);
export const completePayment = (data) => api.post('/payments/complete', data);
export const getPaymentsByBooking = (bookingId) => api.get(`/payments/booking/${bookingId}`);

export default api;
