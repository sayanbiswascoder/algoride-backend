/**
 * Dashboard — Overview page with wallet balance, stats, and recent activity.
 */
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import useStore from '../store/useStore';
import useWallet from '../hooks/useWallet';
import { getUser, getTripsByDriver, getBookingsByUser } from '../services/api';
import { formatAlgo } from '../services/algorand';
import TripCard from '../components/TripCard';

export default function Dashboard() {
    const { user } = useStore();
    const { walletConnected, walletAddress, walletBalance, refreshBalance } = useWallet();
    const [stats, setStats] = useState({ trips: 0, bookings: 0, rating: 0 });
    const [recentTrips, setRecentTrips] = useState([]);
    const [recentBookings, setRecentBookings] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (!user?.id) return;

        const fetchData = async () => {
            try {
                const [userData, driverTrips, userBookings] = await Promise.all([
                    getUser(user.id),
                    getTripsByDriver(user.id),
                    getBookingsByUser(user.id),
                ]);

                setStats({
                    trips: driverTrips.data.length,
                    bookings: userBookings.data.length,
                    rating: userData.data.rating,
                });
                setRecentTrips(driverTrips.data.slice(0, 3));
                setRecentBookings(userBookings.data.slice(0, 3));

                if (walletConnected) refreshBalance();
            } catch (err) {
                console.error('Dashboard fetch error:', err);
            } finally {
                setLoading(false);
            }
        };

        fetchData();
    }, [user?.id]);

    if (loading) {
        return (
            <div className="flex items-center justify-center h-[60vh]">
                <div className="text-3xl animate-spin">⏳</div>
            </div>
        );
    }

    return (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 page-enter">
            {/* Welcome Header */}
            <div className="mb-8">
                <h1 className="text-2xl sm:text-3xl font-bold text-white">
                    Good {new Date().getHours() < 12 ? 'morning' : new Date().getHours() < 18 ? 'afternoon' : 'evening'},{' '}
                    <span className="gradient-text">{user?.name}</span> 👋
                </h1>
                <p className="text-dark-400 mt-1">Here's your ride-sharing overview.</p>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                {/* Wallet Balance */}
                <div className="glass-card p-5 rounded-2xl col-span-2 lg:col-span-1">
                    <div className="flex items-center gap-3 mb-2">
                        <div className="w-10 h-10 rounded-xl bg-accent-600/20 flex items-center justify-center text-xl">💰</div>
                        <div>
                            <p className="text-xs text-dark-400">Wallet Balance</p>
                            <p className="text-xl font-bold text-accent-400">
                                {walletConnected ? `${formatAlgo(walletBalance)}` : '—'}
                            </p>
                        </div>
                    </div>
                    <p className="text-xs text-dark-500">
                        {walletConnected ? 'ALGO (TestNet)' : 'Connect wallet to see balance'}
                    </p>
                </div>

                {/* Trips Created */}
                <div className="glass-card p-5 rounded-2xl">
                    <div className="flex items-center gap-3 mb-2">
                        <div className="w-10 h-10 rounded-xl bg-primary-600/20 flex items-center justify-center text-xl">🚗</div>
                        <div>
                            <p className="text-xs text-dark-400">Trips Offered</p>
                            <p className="text-xl font-bold text-white">{stats.trips}</p>
                        </div>
                    </div>
                </div>

                {/* Bookings */}
                <div className="glass-card p-5 rounded-2xl">
                    <div className="flex items-center gap-3 mb-2">
                        <div className="w-10 h-10 rounded-xl bg-yellow-600/20 flex items-center justify-center text-xl">🎫</div>
                        <div>
                            <p className="text-xs text-dark-400">Rides Taken</p>
                            <p className="text-xl font-bold text-white">{stats.bookings}</p>
                        </div>
                    </div>
                </div>

                {/* Rating */}
                <div className="glass-card p-5 rounded-2xl">
                    <div className="flex items-center gap-3 mb-2">
                        <div className="w-10 h-10 rounded-xl bg-purple-600/20 flex items-center justify-center text-xl">⭐</div>
                        <div>
                            <p className="text-xs text-dark-400">Rating</p>
                            <p className="text-xl font-bold text-white">
                                {stats.rating > 0 ? stats.rating.toFixed(1) : 'N/A'}
                            </p>
                        </div>
                    </div>
                </div>
            </div>

            {/* Quick Actions */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
                <Link to="/trips/create"
                    className="glass-card-hover p-6 rounded-2xl flex items-center gap-4 group">
                    <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-primary-600 to-primary-400 flex items-center justify-center text-2xl group-hover:scale-110 transition-transform">
                        🚗
                    </div>
                    <div>
                        <h3 className="text-lg font-semibold text-white">Offer a Ride</h3>
                        <p className="text-sm text-dark-400">Post a trip for other students</p>
                    </div>
                </Link>
                <Link to="/trips"
                    className="glass-card-hover p-6 rounded-2xl flex items-center gap-4 group">
                    <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-accent-600 to-accent-400 flex items-center justify-center text-2xl group-hover:scale-110 transition-transform">
                        🔍
                    </div>
                    <div>
                        <h3 className="text-lg font-semibold text-white">Find a Ride</h3>
                        <p className="text-sm text-dark-400">Search available trips</p>
                    </div>
                </Link>
            </div>

            {/* Recent Activity */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Recent Trips */}
                <div>
                    <div className="flex items-center justify-between mb-4">
                        <h2 className="text-lg font-semibold text-white">Recent Trips Offered</h2>
                        <Link to="/my-trips" className="text-sm text-primary-400 hover:text-primary-300">View all →</Link>
                    </div>
                    {recentTrips.length > 0 ? (
                        <div className="space-y-3">
                            {recentTrips.map((trip) => (
                                <TripCard key={trip.id} trip={trip} showDriver={false} />
                            ))}
                        </div>
                    ) : (
                        <div className="glass-card p-8 rounded-2xl text-center">
                            <p className="text-dark-400">No trips offered yet.</p>
                            <Link to="/trips/create" className="text-primary-400 text-sm hover:underline mt-1 inline-block">
                                Create your first trip →
                            </Link>
                        </div>
                    )}
                </div>

                {/* Recent Bookings */}
                <div>
                    <div className="flex items-center justify-between mb-4">
                        <h2 className="text-lg font-semibold text-white">Recent Bookings</h2>
                        <Link to="/my-bookings" className="text-sm text-primary-400 hover:text-primary-300">View all →</Link>
                    </div>
                    {recentBookings.length > 0 ? (
                        <div className="space-y-3">
                            {recentBookings.map((booking) => (
                                <div key={booking.id} className="glass-card-hover p-4 rounded-xl">
                                    <div className="flex items-center justify-between">
                                        <div>
                                            <p className="text-sm font-medium text-white">{booking.trip?.origin} → {booking.trip?.destination}</p>
                                            <p className="text-xs text-dark-400 mt-0.5">
                                                {booking.seatsBooked} seat(s) • {formatAlgo(booking.totalFare)} ALGO
                                            </p>
                                        </div>
                                        <span className={`badge ${booking.status === 'confirmed' ? 'badge-active' : booking.status === 'completed' ? 'badge-completed' : 'badge-pending'}`}>
                                            {booking.status}
                                        </span>
                                    </div>
                                </div>
                            ))}
                        </div>
                    ) : (
                        <div className="glass-card p-8 rounded-2xl text-center">
                            <p className="text-dark-400">No bookings yet.</p>
                            <Link to="/trips" className="text-primary-400 text-sm hover:underline mt-1 inline-block">
                                Find a ride →
                            </Link>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
