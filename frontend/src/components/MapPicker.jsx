/**
 * MapPicker — Google Maps with address search (uses Geocoding API, no Places API needed).
 * Users can search for places by name OR click on the map.
 * Falls back to text inputs if no Google Maps API key is set.
 *
 * Env var: VITE_GOOGLE_MAPS_KEY  (only Maps JavaScript API + Geocoding API needed)
 */
import { useState, useCallback, useRef } from "react";
import {
  GoogleMap,
  useJsApiLoader,
  Marker,
  Polyline,
} from "@react-google-maps/api";

const GOOGLE_MAPS_KEY = import.meta.env.VITE_GOOGLE_MAPS_KEY || "";

const MAP_CONTAINER = { width: "100%", height: "350px" };
const DEFAULT_CENTER = { lat: 28.76, lng: 80.99 };
const MAP_OPTIONS = {
  disableDefaultUI: false,
  zoomControl: true,
  mapTypeControl: false,
  streetViewControl: false,
  fullscreenControl: false,
  styles: [
    { elementType: "geometry", stylers: [{ color: "#1a1a2e" }] },
    { elementType: "labels.text.stroke", stylers: [{ color: "#1a1a2e" }] },
    { elementType: "labels.text.fill", stylers: [{ color: "#8b8fa3" }] },
    {
      featureType: "road",
      elementType: "geometry",
      stylers: [{ color: "#2a2a4a" }],
    },
    {
      featureType: "road",
      elementType: "labels.text.fill",
      stylers: [{ color: "#9ca5b3" }],
    },
    {
      featureType: "water",
      elementType: "geometry",
      stylers: [{ color: "#0e1626" }],
    },
    {
      featureType: "water",
      elementType: "labels.text.fill",
      stylers: [{ color: "#515c6d" }],
    },
    {
      featureType: "poi",
      elementType: "geometry",
      stylers: [{ color: "#1e1e3a" }],
    },
    {
      featureType: "poi.park",
      elementType: "geometry",
      stylers: [{ color: "#1a2e1a" }],
    },
    {
      featureType: "transit",
      elementType: "geometry",
      stylers: [{ color: "#2a2a4a" }],
    },
  ],
};

// ── Haversine distance (km) ──────────────────────
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function reportDistance(oM, dM, cb) {
  if (oM && dM)
    cb?.(
      parseFloat(haversineDistance(oM.lat, oM.lng, dM.lat, dM.lng).toFixed(2)),
    );
}

// ── Text-input fallback ──────────────────────────
function TextFallback({
  origin,
  destination,
  onOriginChange,
  onDestinationChange,
  onDistanceCalculated,
}) {
  return (
    <div className="space-y-4">
      <div className="glass-card p-4 border border-yellow-500/30 bg-yellow-500/5 rounded-xl">
        <p className="text-xs text-yellow-400">
          ⚠️ Set{" "}
          <code className="bg-dark-700 px-1 rounded">VITE_GOOGLE_MAPS_KEY</code>{" "}
          in <code className="bg-dark-700 px-1 rounded">frontend/.env</code> for
          the interactive map.
        </p>
      </div>
      <div>
        <label className="label-text">Origin</label>
        <input
          className="input-field"
          placeholder="e.g. Campus Main Gate"
          value={origin?.name || ""}
          onChange={(e) =>
            onOriginChange?.({ name: e.target.value, lat: null, lng: null })
          }
        />
      </div>
      <div>
        <label className="label-text">Destination</label>
        <input
          className="input-field"
          placeholder="e.g. City Center Mall"
          value={destination?.name || ""}
          onChange={(e) =>
            onDestinationChange?.({
              name: e.target.value,
              lat: null,
              lng: null,
            })
          }
        />
      </div>
      <div>
        <label className="label-text">Distance (km)</label>
        <input
          className="input-field"
          type="number"
          step="0.1"
          min="0.1"
          placeholder="Enter distance manually"
          onChange={(e) =>
            onDistanceCalculated?.(parseFloat(e.target.value) || 0)
          }
        />
      </div>
    </div>
  );
}

// ── Address Search Bar (uses Geocoding API) ──────
function AddressSearch({ label, icon, accentColor, onPlaceSelected }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [showResults, setShowResults] = useState(false);
  const geocoderRef = useRef(null);
  const timeoutRef = useRef(null);

  const search = useCallback((value) => {
    setQuery(value);
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    if (!value.trim() || value.length < 3) {
      setResults([]);
      setShowResults(false);
      return;
    }

    timeoutRef.current = setTimeout(async () => {
      if (!window.google) return;
      setSearching(true);
      try {
        if (!geocoderRef.current)
          geocoderRef.current = new window.google.maps.Geocoder();
        const response = await geocoderRef.current.geocode({ address: value });
        const items = (response.results || []).slice(0, 5).map((r) => ({
          name: r.formatted_address,
          lat: r.geometry.location.lat(),
          lng: r.geometry.location.lng(),
        }));
        setResults(items);
        setShowResults(items.length > 0);
      } catch {
        setResults([]);
        setShowResults(false);
      }
      setSearching(false);
    }, 400);
  }, []);

  const selectResult = (place) => {
    setQuery(place.name);
    setShowResults(false);
    setResults([]);
    onPlaceSelected?.(place);
  };

  return (
    <div className="relative">
      <label className="label-text flex items-center gap-1.5">
        <span>{icon}</span> {label}
      </label>
      <div className="relative">
        <input
          type="text"
          className="input-field pr-8"
          placeholder={`Search ${label.toLowerCase().replace("search ", "")}…`}
          value={query}
          onChange={(e) => search(e.target.value)}
          onFocus={() => results.length > 0 && setShowResults(true)}
          onBlur={() => setTimeout(() => setShowResults(false), 200)}
          style={{ borderLeftColor: accentColor, borderLeftWidth: "3px" }}
        />
        {searching && (
          <div className="absolute right-3 top-1/2 -translate-y-1/2">
            <svg
              className="animate-spin h-4 w-4 text-dark-400"
              viewBox="0 0 24 24"
            >
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
                fill="none"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
          </div>
        )}
        {!searching && query && (
          <button
            type="button"
            className="absolute right-3 top-1/2 -translate-y-1/2 text-dark-400 hover:text-white text-xs"
            onClick={() => {
              setQuery("");
              setResults([]);
              setShowResults(false);
            }}
          >
            ✕
          </button>
        )}
      </div>

      {/* Dropdown results */}
      {showResults && (
        <div className="absolute z-50 w-full mt-1 glass-card rounded-xl border border-dark-600/50 shadow-2xl max-h-48 overflow-y-auto">
          {results.map((r, i) => (
            <button
              key={i}
              type="button"
              className="w-full text-left px-3 py-2.5 text-sm text-dark-200 hover:bg-dark-700/50 hover:text-white
                         transition-colors first:rounded-t-xl last:rounded-b-xl flex items-start gap-2"
              onMouseDown={() => selectResult(r)}
            >
              <span className="text-dark-500 mt-0.5 shrink-0">📌</span>
              <span className="truncate">{r.name}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Main component ───────────────────────────────
export default function MapPicker({
  origin,
  destination,
  onOriginChange,
  onDestinationChange,
  onDistanceCalculated,
}) {
  const [selecting, setSelecting] = useState(null);
  const [originMarker, setOriginMarker] = useState(
    origin?.lat ? { lat: origin.lat, lng: origin.lng } : null,
  );
  const [destMarker, setDestMarker] = useState(
    destination?.lat ? { lat: destination.lat, lng: destination.lng } : null,
  );
  const [mapCenter, setMapCenter] = useState(DEFAULT_CENTER);
  const geocoderRef = useRef(null);
  const mapRef = useRef(null);

  const { isLoaded, loadError } = useJsApiLoader({
    googleMapsApiKey: GOOGLE_MAPS_KEY,
    id: "campus-rideshare-map",
  });

  // Reverse geocode for map clicks
  const reverseGeocode = useCallback(async (lat, lng) => {
    if (!window.google) return `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
    try {
      if (!geocoderRef.current)
        geocoderRef.current = new window.google.maps.Geocoder();
      const res = await geocoderRef.current.geocode({ location: { lat, lng } });
      if (res.results?.[0]) return res.results[0].formatted_address;
    } catch {
      /* fallback */
    }
    return `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
  }, []);

  // Map click handler
  const handleMapClick = useCallback(
    async (event) => {
      if (!selecting) return;
      const lat = event.latLng.lat();
      const lng = event.latLng.lng();
      const placeName = await reverseGeocode(lat, lng);

      if (selecting === "origin") {
        setOriginMarker({ lat, lng });
        onOriginChange?.({ name: placeName, lat, lng });
        reportDistance({ lat, lng }, destMarker, onDistanceCalculated);
      } else {
        setDestMarker({ lat, lng });
        onDestinationChange?.({ name: placeName, lat, lng });
        reportDistance(originMarker, { lat, lng }, onDistanceCalculated);
      }
      setSelecting(null);
    },
    [selecting, originMarker, destMarker, reverseGeocode],
  );

  // Search result handlers
  const handleOriginSearch = useCallback(
    (place) => {
      const pos = { lat: place.lat, lng: place.lng };
      setOriginMarker(pos);
      setMapCenter(pos);
      onOriginChange?.(place);
      reportDistance(pos, destMarker, onDistanceCalculated);
      mapRef.current?.panTo(pos);
      mapRef.current?.setZoom(14);
    },
    [destMarker],
  );

  const handleDestSearch = useCallback(
    (place) => {
      const pos = { lat: place.lat, lng: place.lng };
      setDestMarker(pos);
      onDestinationChange?.(place);
      reportDistance(originMarker, pos, onDistanceCalculated);
      if (originMarker && mapRef.current) {
        const bounds = new window.google.maps.LatLngBounds();
        bounds.extend(originMarker);
        bounds.extend(pos);
        mapRef.current.fitBounds(bounds, 60);
      } else {
        mapRef.current?.panTo(pos);
        mapRef.current?.setZoom(14);
      }
    },
    [originMarker],
  );

  const onMapLoad = useCallback((map) => {
    mapRef.current = map;
  }, []);

  // ── Fallback ───────────────────────────────────
  if (!GOOGLE_MAPS_KEY || loadError) {
    return (
      <TextFallback
        origin={origin}
        destination={destination}
        onOriginChange={onOriginChange}
        onDestinationChange={onDestinationChange}
        onDistanceCalculated={onDistanceCalculated}
      />
    );
  }

  if (!isLoaded) {
    return (
      <div className="h-[350px] rounded-2xl bg-dark-800/50 flex items-center justify-center border border-dark-700/50">
        <div className="flex items-center gap-3 text-dark-400">
          <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
              fill="none"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
            />
          </svg>
          Loading Google Maps…
        </div>
      </div>
    );
  }

  // ── Full map with search ───────────────────────
  return (
    <div className="space-y-3">
      {/* 🔍 Search inputs */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <AddressSearch
          label="Search Origin"
          icon="📍"
          accentColor="#10b981"
          onPlaceSelected={handleOriginSearch}
        />
        <AddressSearch
          label="Search Destination"
          icon="🏁"
          accentColor="#6366f1"
          onPlaceSelected={handleDestSearch}
        />
      </div>

      <div className="flex items-center gap-2 text-xs text-dark-400">
        <div className="flex-1 h-px bg-dark-700" />
        or click on the map
        <div className="flex-1 h-px bg-dark-700" />
      </div>

      {/* Click-to-select buttons */}
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => setSelecting("origin")}
          className={`flex-1 px-3 py-2 rounded-xl text-sm font-medium transition-all ${
            selecting === "origin"
              ? "bg-accent-600 text-white ring-2 ring-accent-400"
              : "btn-secondary"
          }`}
        >
          📍 {originMarker ? "Change Origin" : "Click to Set Origin"}
        </button>
        <button
          type="button"
          onClick={() => setSelecting("destination")}
          className={`flex-1 px-3 py-2 rounded-xl text-sm font-medium transition-all ${
            selecting === "destination"
              ? "bg-primary-600 text-white ring-2 ring-primary-400"
              : "btn-secondary"
          }`}
        >
          🏁 {destMarker ? "Change Dest" : "Click to Set Dest"}
        </button>
      </div>

      {selecting && (
        <p className="text-xs text-yellow-400 animate-pulse">
          🖱️ Click on the map to set {selecting}…
        </p>
      )}

      {/* Map */}
      <div className="rounded-2xl overflow-hidden border border-dark-700/50">
        <GoogleMap
          mapContainerStyle={MAP_CONTAINER}
          center={mapCenter}
          zoom={originMarker ? 12 : 5}
          onClick={handleMapClick}
          onLoad={onMapLoad}
          restriction={{
            latLngBounds: {
              north: 26.787,
              south: 24.787,
              east: 80.99,
              west: 78.99,
            },
            strictBounds: true,
          }}
          options={{
            ...MAP_OPTIONS,
            draggableCursor: selecting ? "crosshair" : "grab",
          }}
        >
          {originMarker && (
            <Marker
              position={originMarker}
              label={{ text: "📍", fontSize: "24px" }}
            />
          )}
          {destMarker && (
            <Marker
              position={destMarker}
              label={{ text: "🏁", fontSize: "24px" }}
            />
          )}
          {originMarker && destMarker && (
            <Polyline
              path={[originMarker, destMarker]}
              options={{
                strokeColor: "#6366f1",
                strokeWeight: 3,
                strokeOpacity: 0.8,
                geodesic: true,
              }}
            />
          )}
        </GoogleMap>
      </div>

      {/* Selection summary */}
      <div className="grid grid-cols-2 gap-3 text-xs">
        <div className="glass-card p-2 rounded-lg">
          <span className="text-dark-400">Origin:</span>
          <p className="text-white truncate">{origin?.name || "Not set"}</p>
        </div>
        <div className="glass-card p-2 rounded-lg">
          <span className="text-dark-400">Destination:</span>
          <p className="text-white truncate">
            {destination?.name || "Not set"}
          </p>
        </div>
      </div>
    </div>
  );
}
