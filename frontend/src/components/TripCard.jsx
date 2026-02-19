/**
 * TripCard — Displays a trip summary in search results and lists.
 */
import { Link } from 'react-router-dom';
import RatingStars from './RatingStars';

const statusColors = {
    active: 'badge-active',
    in_progress: 'badge-pending',
    completed: 'badge-completed',
    cancelled: 'badge-cancelled',
};

export default function TripCard({ trip, showDriver = true }) {
    const fareEstimate = (trip.distance * trip.pricePerKm).toFixed(4);

    return (
        <Link to={`/trips/${trip.id}`} className="block">
            <div className="glass-card-hover p-5 space-y-3">
                {/* Header */}
                <div className="flex items-start justify-between">
                    <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 text-sm text-dark-400 mb-1">
                            <span className={statusColors[trip.status] || 'badge'}>{trip.status}</span>
                            <span>•</span>
                            <span>{new Date(trip.departureTime).toLocaleDateString()}</span>
                        </div>
                    </div>
                    <div className="text-right flex-shrink-0">
                        <p className="text-lg font-bold text-accent-400">{fareEstimate} <span className="text-xs text-dark-400">ALGO</span></p>
                        <p className="text-xs text-dark-500">per seat</p>
                    </div>
                </div>

                {/* Route */}
                <div className="flex items-center gap-3">
                    <div className="flex flex-col items-center gap-1">
                        <div className="w-3 h-3 rounded-full bg-accent-500 ring-2 ring-accent-500/30"></div>
                        <div className="w-px h-8 bg-dark-600"></div>
                        <div className="w-3 h-3 rounded-full bg-primary-500 ring-2 ring-primary-500/30"></div>
                    </div>
                    <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-white truncate">{trip.origin}</p>
                        <p className="text-xs text-dark-500 my-1">{trip.distance?.toFixed(1)} km</p>
                        <p className="text-sm font-medium text-white truncate">{trip.destination}</p>
                    </div>
                </div>

                {/* Footer */}
                <div className="flex items-center justify-between pt-2 border-t border-dark-700/50">
                    <div className="flex items-center gap-3">
                        {showDriver && trip.driver && (
                            <div className="flex items-center gap-2">
                                <div className="w-6 h-6 rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-xs font-bold">
                                    {trip.driver.name?.charAt(0)?.toUpperCase()}
                                </div>
                                <span className="text-xs text-dark-300">{trip.driver.name}</span>
                                <RatingStars rating={trip.driver.rating} size="sm" />
                            </div>
                        )}
                    </div>
                    <div className="flex items-center gap-1 text-xs text-dark-400">
                        <span>🪑</span>
                        <span>{trip.seatsAvailable} seats left</span>
                    </div>
                </div>

                {/* Departure time */}
                <div className="text-xs text-dark-500">
                    🕐 {new Date(trip.departureTime).toLocaleString()}
                </div>
            </div>
        </Link>
    );
}
