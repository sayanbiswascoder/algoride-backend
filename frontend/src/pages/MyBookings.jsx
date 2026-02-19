/**
 * MyBookings — Rider's booked trips with payment and status.
 */
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import useStore from '../store/useStore';
import { getBookingsByUser } from '../services/api';
import { formatAlgo } from '../services/algorand';
import PaymentModal from '../components/PaymentModal';

export default function MyBookings() {
    const { user } = useStore();
    const [bookings, setBookings] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showPayment, setShowPayment] = useState(null);

    const fetchBookings = async () => {
        try {
            const { data } = await getBookingsByUser(user.id);
            setBookings(data);
        } catch (err) {
            console.error('Fetch bookings error:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchBookings(); }, [user.id]);

    const statusBadge = (status) => {
        const map = { pending: 'badge-pending', confirmed: 'badge-active', completed: 'badge-completed', cancelled: 'badge-cancelled' };
        return map[status] || 'badge';
    };

    return (
        <div className="max-w-5xl mx-auto px-4 sm:px-6 page-enter">
            <div className="mb-8">
                <h1 className="text-2xl sm:text-3xl font-bold text-white">🎫 My Bookings</h1>
                <p className="text-dark-400 mt-1">View your booked rides and payment status.</p>
            </div>

            {loading ? (
                <div className="flex items-center justify-center h-40">
                    <div className="text-3xl animate-spin">⏳</div>
                </div>
            ) : bookings.length > 0 ? (
                <div className="space-y-4">
                    {bookings.map((booking) => (
                        <div key={booking.id} className="glass-card-hover p-5 rounded-2xl">
                            <div className="flex items-start justify-between mb-3">
                                <div className="flex-1 min-w-0">
                                    <Link to={`/trips/${booking.tripId}`} className="text-white font-semibold hover:text-primary-400 transition-colors">
                                        {booking.trip?.origin} → {booking.trip?.destination}
                                    </Link>
                                    <p className="text-xs text-dark-500 mt-0.5">
                                        {booking.trip?.departureTime && new Date(booking.trip.departureTime).toLocaleString()}
                                    </p>
                                </div>
                                <span className={`badge ${statusBadge(booking.status)}`}>{booking.status}</span>
                            </div>

                            <div className="grid grid-cols-3 gap-3 text-sm">
                                <div>
                                    <p className="text-xs text-dark-500">Seats</p>
                                    <p className="text-white font-medium">{booking.seatsBooked}</p>
                                </div>
                                <div>
                                    <p className="text-xs text-dark-500">Total Fare</p>
                                    <p className="text-accent-400 font-semibold">{formatAlgo(booking.totalFare)} ALGO</p>
                                </div>
                                <div>
                                    <p className="text-xs text-dark-500">Driver</p>
                                    <p className="text-white">{booking.trip?.driver?.name || '—'}</p>
                                </div>
                            </div>

                            {/* Payment action */}
                            {booking.status === 'pending' && (
                                <button
                                    onClick={() => setShowPayment({ ...booking, riderId: user.id })}
                                    className="btn-accent w-full mt-3 text-sm"
                                >
                                    💸 Pay {formatAlgo(booking.totalFare)} ALGO
                                </button>
                            )}

                            {/* Transaction link */}
                            {booking.paymentTxId && (
                                <div className="mt-2 text-xs">
                                    <span className="text-dark-500">Tx: </span>
                                    <a href={`https://testnet.algoexplorer.io/tx/${booking.paymentTxId}`}
                                        target="_blank" rel="noopener noreferrer"
                                        className="text-primary-400 font-mono hover:underline break-all">
                                        {booking.paymentTxId.slice(0, 16)}...
                                    </a>
                                </div>
                            )}
                        </div>
                    ))}
                </div>
            ) : (
                <div className="glass-card p-12 rounded-2xl text-center">
                    <span className="text-5xl mb-4 block">🎫</span>
                    <h3 className="text-lg font-semibold text-white mb-2">No bookings yet</h3>
                    <p className="text-dark-400 text-sm mb-4">Find a ride and book your seat!</p>
                    <Link to="/trips" className="btn-primary inline-block">Find a Ride</Link>
                </div>
            )}

            {/* Payment Modal */}
            {showPayment && (
                <PaymentModal
                    booking={showPayment}
                    driverWallet={showPayment.trip?.driver?.walletAddress}
                    onClose={() => setShowPayment(null)}
                    onSuccess={() => { setShowPayment(null); fetchBookings(); }}
                />
            )}
        </div>
    );
}
