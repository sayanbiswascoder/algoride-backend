/**
 * App — Root component with routing.
 * Listens to Firebase onAuthStateChanged for auth persistence.
 * Handles Google redirect results for first-time sign-ups.
 */
import { useEffect } from "react";
import { Routes, Route, Navigate } from "react-router-dom";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { auth } from "./services/firebase";
import { getUser, registerUserProfile } from "./services/api";
import useStore from "./store/useStore";
import Navbar from "./components/Navbar";
import Notification from "./components/Notification";
import Login from "./pages/Login";
import Register from "./pages/Register";
import Dashboard from "./pages/Dashboard";
import SearchTrips from "./pages/SearchTrips";
import TripDetail from "./pages/TripDetail";
import CreateTrip from "./pages/CreateTrip";
import MyTrips from "./pages/MyTrips";
import MyBookings from "./pages/MyBookings";

function ProtectedRoute({ children }) {
  const user = useStore((s) => s.user);
  const authLoading = useStore((s) => s.authLoading);

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-dark-950">
        <div className="text-center">
          <span className="text-4xl animate-pulse">🚗</span>
          <p className="text-dark-400 mt-4">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user) return <Navigate to="/login" replace />;
  return children;
}

export default function App() {
  const user = useStore((s) => s.user);
  const authLoading = useStore((s) => s.authLoading);
  const setUser = useStore((s) => s.setUser);
  const setAuthLoading = useStore((s) => s.setAuthLoading);
  const logout = useStore((s) => s.logout);
  const showNotification = useStore((s) => s.showNotification);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        try {
          // Fetch the full user profile from the backend
          const { data } = await getUser(firebaseUser.uid);
          setUser(data);
        } catch (err) {
          // If 404, the profile doesn't exist yet (first-time Google sign-in)
          if (err.response?.status === 404) {
            // Small delay to let Login/Register pages handle profile creation first
            await new Promise((r) => setTimeout(r, 1500));

            // Re-check: profile might have been created by Login/Register page
            try {
              const { data } = await getUser(firebaseUser.uid);
              setUser(data);
            } catch (retryErr) {
              if (retryErr.response?.status === 404) {
                // Still 404 — this is a Google redirect sign-in, create profile
                try {
                  const { data } = await registerUserProfile({
                    name: firebaseUser.displayName || "Google User",
                    email: firebaseUser.email,
                    walletAddress: null,
                  });
                  setUser(data);
                  showNotification(
                    "Account created with Google! Welcome 🎉",
                    "success",
                  );
                } catch (createErr) {
                  // 409 = profile was just created by another flow, fetch it
                  if (createErr.response?.status === 409) {
                    const profileData = createErr.response.data.user;
                    setUser(profileData);
                  } else {
                    console.error("Failed to create user profile:", createErr);
                    await signOut(auth);
                    logout();
                    setAuthLoading(false);
                  }
                }
              } else {
                console.error("Failed to fetch user profile:", retryErr);
                await signOut(auth);
                logout();
                setAuthLoading(false);
              }
            }
          } else {
            console.error("Failed to fetch user profile:", err);
            await signOut(auth);
            logout();
            setAuthLoading(false);
          }
        }
      } else {
        setUser(null);
      }
    });

    return () => unsubscribe();
  }, []);

  return (
    <div className="min-h-screen bg-dark-950">
      {user && <Navbar />}
      <Notification />

      <main className={user ? "pt-20 pb-8" : ""}>
        <Routes>
          {/* Public */}
          <Route
            path="/login"
            element={
              authLoading ? null : user ? (
                <Navigate to="/" replace />
              ) : (
                <Login />
              )
            }
          />
          <Route
            path="/register"
            element={
              authLoading ? null : user ? (
                <Navigate to="/" replace />
              ) : (
                <Register />
              )
            }
          />

          {/* Protected */}
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/trips"
            element={
              <ProtectedRoute>
                <SearchTrips />
              </ProtectedRoute>
            }
          />
          <Route
            path="/trips/create"
            element={
              <ProtectedRoute>
                <CreateTrip />
              </ProtectedRoute>
            }
          />
          <Route
            path="/trips/:id"
            element={
              <ProtectedRoute>
                <TripDetail />
              </ProtectedRoute>
            }
          />
          <Route
            path="/my-trips"
            element={
              <ProtectedRoute>
                <MyTrips />
              </ProtectedRoute>
            }
          />
          <Route
            path="/my-bookings"
            element={
              <ProtectedRoute>
                <MyBookings />
              </ProtectedRoute>
            }
          />

          {/* Fallback */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </div>
  );
}
