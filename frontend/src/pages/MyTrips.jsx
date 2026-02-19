/**
 * MyTrips — Driver's trips list with status management.
 */
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import useStore from '../store/useStore';
import { getTripsByDriver, updateTripStatus } from '../services/api';
import TripCard from '../components/TripCard';

export default function MyTrips() {
    const { user, showNotification } = useStore();
    const [trips, setTrips] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('all');

    const fetchTrips = async () => {
        try {
            const { data } = await getTripsByDriver(user.id);
            setTrips(data);
        } catch (err) {
            console.error('Fetch driver trips error:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchTrips(); }, [user.id]);

    const handleStatusUpdate = async (tripId, status) => {
        const confirmMsg = status === 'completed'
            ? 'Mark this trip as completed? This will finalize all bookings.'
            : `Change trip status to "${status}"?`;
        if (!window.confirm(confirmMsg)) return;

        try {
            await updateTripStatus(tripId, { status });
            showNotification(`Trip ${status}!`, 'success');
            fetchTrips();
        } catch (err) {
            showNotification('Failed to update trip', 'error');
        }
    };

    const filteredTrips = filter === 'all'
        ? trips
        : trips.filter((t) => t.status === filter);

    return (
        <div className="max-w-5xl mx-auto px-4 sm:px-6 page-enter">
            <div className="flex items-center justify-between mb-8">
                <div>
                    <h1 className="text-2xl sm:text-3xl font-bold text-white">📋 My Trips</h1>
                    <p className="text-dark-400 mt-1">Manage your offered rides.</p>
                </div>
                <Link to="/trips/create" className="btn-primary text-sm">
                    + New Trip
                </Link>
            </div>

            {/* Filter Tabs */}
            <div className="flex gap-2 mb-6 overflow-x-auto pb-2">
                {['all', 'active', 'in_progress', 'completed', 'cancelled'].map((f) => (
                    <button
                        key={f}
                        onClick={() => setFilter(f)}
                        className={`px-4 py-2 rounded-xl text-sm font-medium whitespace-nowrap transition-all ${filter === f
                                ? 'bg-primary-600/20 text-primary-400 border border-primary-500/30'
                                : 'text-dark-400 hover:text-white hover:bg-dark-700/50'
                            }`}
                    >
                        {f.replace('_', ' ').replace(/\b\w/g, (c) => c.toUpperCase())}
                    </button>
                ))}
            </div>

            {loading ? (
                <div className="flex items-center justify-center h-40">
                    <div className="text-3xl animate-spin">⏳</div>
                </div>
            ) : filteredTrips.length > 0 ? (
                <div className="space-y-4">
                    {filteredTrips.map((trip) => (
                        <div key={trip.id} className="relative">
                            <TripCard trip={trip} showDriver={false} />
                            {/* Action Buttons */}
                            {trip.status === 'active' && (
                                <div className="flex gap-2 mt-2 ml-auto max-w-fit">
                                    <button
                                        onClick={(e) => { e.preventDefault(); handleStatusUpdate(trip.id, 'in_progress'); }}
                                        className="btn-secondary text-xs py-1.5 px-3"
                                    >
                                        🚗 Start Trip
                                    </button>
                                    <button
                                        onClick={(e) => { e.preventDefault(); handleStatusUpdate(trip.id, 'cancelled'); }}
                                        className="btn-danger text-xs py-1.5 px-3"
                                    >
                                        ✕ Cancel
                                    </button>
                                </div>
                            )}
                            {trip.status === 'in_progress' && (
                                <div className="mt-2 ml-auto max-w-fit">
                                    <button
                                        onClick={(e) => { e.preventDefault(); handleStatusUpdate(trip.id, 'completed'); }}
                                        className="btn-accent text-xs py-1.5 px-3"
                                    >
                                        ✅ Mark Complete
                                    </button>
                                </div>
                            )}
                        </div>
                    ))}
                </div>
            ) : (
                <div className="glass-card p-12 rounded-2xl text-center">
                    <span className="text-5xl mb-4 block">🚗</span>
                    <h3 className="text-lg font-semibold text-white mb-2">No trips yet</h3>
                    <p className="text-dark-400 text-sm mb-4">Start offering rides to fellow students.</p>
                    <Link to="/trips/create" className="btn-primary inline-block">Create Your First Trip</Link>
                </div>
            )}
        </div>
    );
}
