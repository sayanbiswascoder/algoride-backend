/**
 * TripDetail — Full trip view with booking, payment, and rating.
 */
import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import useStore from '../store/useStore';
import { getTrip, createBooking, createRating } from '../services/api';
import { formatAlgo } from '../services/algorand';
import RatingStars from '../components/RatingStars';
import PaymentModal from '../components/PaymentModal';

export default function TripDetail() {
    const { id } = useParams();
    const navigate = useNavigate();
    const { user, showNotification } = useStore();
    const [trip, setTrip] = useState(null);
    const [loading, setLoading] = useState(true);
    const [booking, setBooking] = useState(false);
    const [seats, setSeats] = useState(1);
    const [showPayment, setShowPayment] = useState(null);
    const [ratingForm, setRatingForm] = useState({ rating: 0, comment: '' });
    const [submittingRating, setSubmittingRating] = useState(false);

    const fetchTrip = async () => {
        try {
            const { data } = await getTrip(id);
            setTrip(data);
        } catch (err) {
            console.error('Fetch trip error:', err);
            showNotification('Trip not found', 'error');
            navigate('/trips');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchTrip(); }, [id]);

    const handleBook = async () => {
        setBooking(true);
        try {
            const { data } = await createBooking({
                tripId: trip.id,
                riderId: user.id,
                seatsBooked: seats,
            });
            showNotification('Seats booked! Proceed to payment.', 'success');
            setShowPayment(data);
            fetchTrip(); // refresh
        } catch (err) {
            showNotification(err.response?.data?.error || 'Booking failed', 'error');
        } finally {
            setBooking(false);
        }
    };

    const handleRate = async () => {
        if (ratingForm.rating === 0) return showNotification('Please select a rating', 'warning');
        setSubmittingRating(true);
        try {
            await createRating({
                fromUserId: user.id,
                toUserId: trip.driverId,
                rating: ratingForm.rating,
                comment: ratingForm.comment,
            });
            showNotification('Rating submitted! ⭐', 'success');
            setRatingForm({ rating: 0, comment: '' });
            fetchTrip();
        } catch (err) {
            showNotification('Failed to submit rating', 'error');
        } finally {
            setSubmittingRating(false);
        }
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center h-[60vh]">
                <div className="text-3xl animate-spin">⏳</div>
            </div>
        );
    }

    if (!trip) return null;

    const isDriver = trip.driverId === user?.id;
    const farePerSeat = (trip.distance * trip.pricePerKm).toFixed(6);
    const totalFare = (trip.distance * trip.pricePerKm * seats).toFixed(6);
    const myBooking = trip.bookings?.find((b) => b.riderId === user?.id);

    return (
        <div className="max-w-4xl mx-auto px-4 sm:px-6 page-enter">
            {/* Header */}
            <div className="glass-card p-6 rounded-2xl mb-6">
                <div className="flex items-start justify-between mb-4">
                    <div>
                        <span className={`badge ${trip.status === 'active' ? 'badge-active' : trip.status === 'completed' ? 'badge-completed' : 'badge-pending'} mb-2`}>
                            {trip.status}
                        </span>
                        <h1 className="text-xl sm:text-2xl font-bold text-white">Trip Details</h1>
                    </div>
                    <p className="text-2xl font-bold text-accent-400">
                        {farePerSeat} <span className="text-sm text-dark-400">ALGO/seat</span>
                    </p>
                </div>

                {/* Route Visual */}
                <div className="flex items-center gap-4 py-4">
                    <div className="flex flex-col items-center gap-1">
                        <div className="w-4 h-4 rounded-full bg-accent-500 ring-4 ring-accent-500/20"></div>
                        <div className="w-px h-16 bg-gradient-to-b from-accent-500 to-primary-500"></div>
                        <div className="w-4 h-4 rounded-full bg-primary-500 ring-4 ring-primary-500/20"></div>
                    </div>
                    <div className="flex-1 space-y-8">
                        <div>
                            <p className="text-xs text-dark-400 uppercase tracking-wide">Origin</p>
                            <p className="text-lg font-semibold text-white">{trip.origin}</p>
                        </div>
                        <div>
                            <p className="text-xs text-dark-400 uppercase tracking-wide">Destination</p>
                            <p className="text-lg font-semibold text-white">{trip.destination}</p>
                        </div>
                    </div>
                </div>

                {/* Trip Info Grid */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-4 border-t border-dark-700/50">
                    <div className="text-center">
                        <p className="text-xs text-dark-400">Distance</p>
                        <p className="text-lg font-semibold text-white">{trip.distance?.toFixed(1)} km</p>
                    </div>
                    <div className="text-center">
                        <p className="text-xs text-dark-400">Departure</p>
                        <p className="text-sm font-semibold text-white">{new Date(trip.departureTime).toLocaleString()}</p>
                    </div>
                    <div className="text-center">
                        <p className="text-xs text-dark-400">Seats Left</p>
                        <p className="text-lg font-semibold text-white">{trip.seatsAvailable}</p>
                    </div>
                    <div className="text-center">
                        <p className="text-xs text-dark-400">Price/km</p>
                        <p className="text-lg font-semibold text-accent-400">{trip.pricePerKm} ALGO</p>
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Left Column — Driver Info + Rating */}
                <div className="space-y-6">
                    {/* Driver Card */}
                    <div className="glass-card p-5 rounded-2xl">
                        <h3 className="text-sm font-medium text-dark-400 mb-3">Driver</h3>
                        <div className="flex items-center gap-3">
                            <div className="w-12 h-12 rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-xl font-bold">
                                {trip.driver?.name?.charAt(0)?.toUpperCase()}
                            </div>
                            <div>
                                <p className="text-white font-semibold">{trip.driver?.name}</p>
                                <RatingStars rating={trip.driver?.rating || 0} size="sm" />
                            </div>
                        </div>
                    </div>

                    {/* Rate Driver (for riders who completed the trip) */}
                    {!isDriver && myBooking?.status === 'completed' && (
                        <div className="glass-card p-5 rounded-2xl space-y-3">
                            <h3 className="text-sm font-medium text-dark-400">Rate Driver</h3>
                            <RatingStars rating={ratingForm.rating} interactive onChange={(r) => setRatingForm({ ...ratingForm, rating: r })} size="lg" />
                            <textarea
                                className="input-field text-sm"
                                rows={2}
                                placeholder="Leave a comment (optional)"
                                value={ratingForm.comment}
                                onChange={(e) => setRatingForm({ ...ratingForm, comment: e.target.value })}
                            />
                            <button onClick={handleRate} className="btn-primary w-full text-sm" disabled={submittingRating}>
                                {submittingRating ? 'Submitting...' : '⭐ Submit Rating'}
                            </button>
                        </div>
                    )}
                </div>

                {/* Right Column — Booking + Passengers */}
                <div className="lg:col-span-2 space-y-6">
                    {/* Book section (for riders) */}
                    {!isDriver && trip.status === 'active' && !myBooking && trip.seatsAvailable > 0 && (
                        <div className="glass-card p-6 rounded-2xl space-y-4">
                            <h3 className="text-lg font-semibold text-white">🎫 Book Seats</h3>
                            <div className="flex items-center gap-4">
                                <div className="flex-1">
                                    <label className="label-text">Number of Seats</label>
                                    <input
                                        type="number" min="1" max={trip.seatsAvailable}
                                        className="input-field"
                                        value={seats}
                                        onChange={(e) => setSeats(Math.min(parseInt(e.target.value) || 1, trip.seatsAvailable))}
                                    />
                                </div>
                                <div className="text-right">
                                    <p className="text-xs text-dark-400">Total Fare</p>
                                    <p className="text-xl font-bold text-accent-400">{totalFare} <span className="text-xs">ALGO</span></p>
                                </div>
                            </div>
                            <button onClick={handleBook} className="btn-accent w-full" disabled={booking}>
                                {booking ? '⏳ Booking...' : '🎫 Book Now'}
                            </button>
                        </div>
                    )}

                    {/* Existing booking info */}
                    {myBooking && (
                        <div className="glass-card p-5 rounded-2xl">
                            <h3 className="text-sm font-medium text-dark-400 mb-3">Your Booking</h3>
                            <div className="flex items-center justify-between">
                                <div>
                                    <p className="text-white font-medium">{myBooking.seatsBooked} seat(s)</p>
                                    <p className="text-sm text-dark-400">Fare: {formatAlgo(myBooking.totalFare)} ALGO</p>
                                </div>
                                <span className={`badge ${myBooking.status === 'confirmed' ? 'badge-active' : myBooking.status === 'completed' ? 'badge-completed' : 'badge-pending'}`}>
                                    {myBooking.status}
                                </span>
                            </div>
                            {myBooking.status === 'pending' && (
                                <button onClick={() => setShowPayment(myBooking)} className="btn-accent w-full mt-3 text-sm">
                                    💸 Pay Now
                                </button>
                            )}
                            {myBooking.paymentTxId && (
                                <div className="mt-3 text-xs">
                                    <span className="text-dark-500">Tx: </span>
                                    <a href={`https://testnet.algoexplorer.io/tx/${myBooking.paymentTxId}`}
                                        target="_blank" rel="noopener noreferrer"
                                        className="text-primary-400 font-mono hover:underline break-all">
                                        {myBooking.paymentTxId}
                                    </a>
                                </div>
                            )}
                        </div>
                    )}

                    {/* Passengers List (visible to driver) */}
                    {isDriver && trip.bookings?.length > 0 && (
                        <div className="glass-card p-5 rounded-2xl">
                            <h3 className="text-sm font-medium text-dark-400 mb-3">Passengers ({trip.bookings.length})</h3>
                            <div className="space-y-2">
                                {trip.bookings.map((b) => (
                                    <div key={b.id} className="flex items-center justify-between py-2 border-b border-dark-700/30 last:border-0">
                                        <div className="flex items-center gap-2">
                                            <div className="w-8 h-8 rounded-full bg-dark-600 flex items-center justify-center text-xs font-bold">
                                                {b.rider?.name?.charAt(0)?.toUpperCase()}
                                            </div>
                                            <div>
                                                <p className="text-sm text-white">{b.rider?.name}</p>
                                                <p className="text-xs text-dark-500">{b.seatsBooked} seat(s) • {formatAlgo(b.totalFare)} ALGO</p>
                                            </div>
                                        </div>
                                        <span className={`badge text-xs ${b.status === 'confirmed' ? 'badge-active' : b.status === 'completed' ? 'badge-completed' : 'badge-pending'}`}>
                                            {b.status}
                                        </span>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}
                </div>
            </div>

            {/* Payment Modal */}
            {showPayment && (
                <PaymentModal
                    booking={showPayment}
                    driverWallet={trip.driver?.walletAddress}
                    onClose={() => setShowPayment(null)}
                    onSuccess={(txId) => {
                        setShowPayment(null);
                        fetchTrip();
                    }}
                />
            )}
        </div>
    );
}
