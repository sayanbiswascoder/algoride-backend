/**
 * CreateTrip — Driver creates a trip with map selection.
 */
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import useStore from '../store/useStore';
import { createTrip } from '../services/api';
import MapPicker from '../components/MapPicker';

export default function CreateTrip() {
    const { user, showNotification } = useStore();
    const navigate = useNavigate();
    const [loading, setLoading] = useState(false);
    const [origin, setOrigin] = useState({ name: '', lat: null, lng: null });
    const [destination, setDestination] = useState({ name: '', lat: null, lng: null });
    const [distance, setDistance] = useState(0);
    const [form, setForm] = useState({
        departureTime: '',
        seatsAvailable: 3,
        pricePerKm: 0.01,
    });

    const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

    const fareEstimate = distance > 0 ? (distance * form.pricePerKm).toFixed(6) : '0';

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!origin.name || !destination.name) {
            return showNotification('Please set both origin and destination', 'warning');
        }
        if (!form.departureTime) return showNotification('Departure time is required', 'warning');
        if (distance <= 0) return showNotification('Distance must be greater than 0', 'warning');

        setLoading(true);
        try {
            await createTrip({
                driverId: user.id,
                origin: origin.name,
                originLat: origin.lat,
                originLng: origin.lng,
                destination: destination.name,
                destinationLat: destination.lat,
                destinationLng: destination.lng,
                distance,
                departureTime: form.departureTime,
                seatsAvailable: form.seatsAvailable,
                pricePerKm: form.pricePerKm,
            });
            showNotification('Trip created successfully! 🚗', 'success');
            navigate('/my-trips');
        } catch (err) {
            showNotification(err.response?.data?.error || 'Failed to create trip', 'error');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="max-w-3xl mx-auto px-4 sm:px-6 page-enter">
            <div className="mb-8">
                <h1 className="text-2xl sm:text-3xl font-bold text-white">🚗 Offer a Ride</h1>
                <p className="text-dark-400 mt-1">Post your trip and share your journey with students.</p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-6">
                {/* Map Section */}
                <div className="glass-card p-6 rounded-2xl">
                    <h2 className="text-lg font-semibold text-white mb-4">📍 Route</h2>
                    <MapPicker
                        origin={origin}
                        destination={destination}
                        onOriginChange={setOrigin}
                        onDestinationChange={setDestination}
                        onDistanceCalculated={setDistance}
                    />
                    {distance > 0 && (
                        <p className="mt-3 text-sm text-dark-300">
                            📏 Estimated distance: <span className="font-semibold text-accent-400">{distance} km</span>
                        </p>
                    )}
                </div>

                {/* Trip Details */}
                <div className="glass-card p-6 rounded-2xl space-y-4">
                    <h2 className="text-lg font-semibold text-white">📝 Trip Details</h2>

                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <div>
                            <label className="label-text">Departure Date & Time</label>
                            <input
                                name="departureTime"
                                type="datetime-local"
                                className="input-field"
                                value={form.departureTime}
                                onChange={handleChange}
                            />
                        </div>
                        <div>
                            <label className="label-text">Seats Available</label>
                            <input
                                name="seatsAvailable"
                                type="number"
                                min="1"
                                max="10"
                                className="input-field"
                                value={form.seatsAvailable}
                                onChange={handleChange}
                            />
                        </div>
                    </div>

                    <div>
                        <label className="label-text">Price per Kilometer (ALGO)</label>
                        <input
                            name="pricePerKm"
                            type="number"
                            step="0.001"
                            min="0.001"
                            className="input-field"
                            value={form.pricePerKm}
                            onChange={handleChange}
                        />
                        <p className="text-xs text-dark-500 mt-1">
                            Estimated fare per seat: <span className="text-accent-400 font-medium">{fareEstimate} ALGO</span>
                        </p>
                    </div>
                </div>

                {/* Submit */}
                <button type="submit" className="btn-primary w-full text-lg" disabled={loading}>
                    {loading ? '⏳ Creating...' : '🚗 Create Trip'}
                </button>
            </form>
        </div>
    );
}
