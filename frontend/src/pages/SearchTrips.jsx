/**
 * SearchTrips — Browse and filter available rides.
 */
import { useEffect, useState } from 'react';
import { getTrips } from '../services/api';
import TripCard from '../components/TripCard';

export default function SearchTrips() {
    const [trips, setTrips] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filters, setFilters] = useState({ origin: '', destination: '' });

    const fetchTrips = async () => {
        setLoading(true);
        try {
            const params = { status: 'active' };
            if (filters.origin) params.origin = filters.origin;
            if (filters.destination) params.destination = filters.destination;
            const { data } = await getTrips(params);
            setTrips(data);
        } catch (err) {
            console.error('Fetch trips error:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => { fetchTrips(); }, []);

    const handleSearch = (e) => {
        e.preventDefault();
        fetchTrips();
    };

    return (
        <div className="max-w-5xl mx-auto px-4 sm:px-6 page-enter">
            <div className="mb-8">
                <h1 className="text-2xl sm:text-3xl font-bold text-white">🔍 Find a Ride</h1>
                <p className="text-dark-400 mt-1">Search available trips and book your seat.</p>
            </div>

            {/* Search Filters */}
            <form onSubmit={handleSearch} className="glass-card p-5 rounded-2xl mb-6">
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <div>
                        <label className="label-text">Origin</label>
                        <input
                            className="input-field"
                            placeholder="Where from?"
                            value={filters.origin}
                            onChange={(e) => setFilters({ ...filters, origin: e.target.value })}
                        />
                    </div>
                    <div>
                        <label className="label-text">Destination</label>
                        <input
                            className="input-field"
                            placeholder="Where to?"
                            value={filters.destination}
                            onChange={(e) => setFilters({ ...filters, destination: e.target.value })}
                        />
                    </div>
                    <div className="flex items-end">
                        <button type="submit" className="btn-primary w-full">
                            🔍 Search
                        </button>
                    </div>
                </div>
            </form>

            {/* Results */}
            {loading ? (
                <div className="flex items-center justify-center h-40">
                    <div className="text-3xl animate-spin">⏳</div>
                </div>
            ) : trips.length > 0 ? (
                <div className="space-y-4">
                    <p className="text-sm text-dark-400">{trips.length} ride(s) available</p>
                    {trips.map((trip) => (
                        <TripCard key={trip.id} trip={trip} />
                    ))}
                </div>
            ) : (
                <div className="glass-card p-12 rounded-2xl text-center">
                    <span className="text-5xl mb-4 block">🚗</span>
                    <h3 className="text-lg font-semibold text-white mb-2">No rides found</h3>
                    <p className="text-dark-400 text-sm">
                        No active trips match your search. Try broader terms or check back later.
                    </p>
                </div>
            )}
        </div>
    );
}
