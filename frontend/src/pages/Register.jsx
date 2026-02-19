/**
 * Register Page — Create account with Firebase Auth + Firestore profile.
 * Supports email/password and Google Sign-In (popup with redirect fallback).
 */
import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  createUserWithEmailAndPassword,
  signInWithPopup,
  signInWithRedirect,
} from "firebase/auth";
import { auth, googleProvider } from "../services/firebase";
import useStore from "../store/useStore";
import { registerUserProfile, getUser } from "../services/api";

export default function Register() {
  const [form, setForm] = useState({
    name: "",
    email: "",
    password: "",
    walletAddress: "",
  });
  const [loading, setLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [error, setError] = useState("");
  const { setUser, showNotification } = useStore();
  const navigate = useNavigate();

  const handleChange = (e) =>
    setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.name || !form.email)
      return setError("Name and email are required");
    if (!form.password || form.password.length < 6)
      return setError("Password must be at least 6 characters");
    setLoading(true);
    setError("");

    try {
      // 1. Create Firebase Auth account
      await createUserWithEmailAndPassword(auth, form.email, form.password);

      // 2. Create user profile in Firestore via backend API
      const { data } = await registerUserProfile({
        name: form.name,
        email: form.email,
        walletAddress: form.walletAddress || null,
      });

      setUser(data);
      showNotification("Account created! Welcome to CampusRide 🎉", "success");
      navigate("/");
    } catch (err) {
      const code = err.code;
      if (code === "auth/email-already-in-use") {
        setError("This email is already registered. Try logging in instead.");
      } else if (code === "auth/weak-password") {
        setError("Password should be at least 6 characters.");
      } else if (code === "auth/invalid-email") {
        setError("Invalid email address.");
      } else {
        const msg =
          err.response?.data?.error || err.message || "Registration failed";
        setError(msg);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleResult = async (user) => {
    const uid = user.uid;
    try {
      const { data } = await getUser(uid);
      setUser(data);
      showNotification(`Welcome back, ${data.name}!`, "success");
    } catch (fetchErr) {
      if (fetchErr.response?.status === 404) {
        const { data } = await registerUserProfile({
          name: user.displayName || "Google User",
          email: user.email,
          walletAddress: null,
        });
        setUser(data);
        showNotification("Account created with Google! Welcome 🎉", "success");
      } else {
        throw fetchErr;
      }
    }
    navigate("/");
  };

  const handleGoogleSignUp = async () => {
    setGoogleLoading(true);
    setError("");

    try {
      // Try popup first
      const result = await signInWithPopup(auth, googleProvider);
      await handleGoogleResult(result.user);
    } catch (err) {
      // If popup blocked by COOP or browser, fall back to redirect
      if (
        err.code === "auth/popup-blocked" ||
        err.code === "auth/popup-closed-by-user" ||
        err.code === "auth/cancelled-popup-request" ||
        err.message?.includes("Cross-Origin-Opener-Policy")
      ) {
        signInWithRedirect(auth, googleProvider);
        return;
      }
      setError(
        err.response?.data?.error || err.message || "Google sign-up failed",
      );
      setGoogleLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center px-4 relative overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 bg-gradient-to-br from-dark-950 via-accent-900/20 to-dark-950"></div>
      <div className="absolute top-1/3 right-1/4 w-96 h-96 bg-accent-600/10 rounded-full blur-3xl animate-pulse-slow"></div>
      <div className="absolute bottom-1/3 left-1/4 w-96 h-96 bg-primary-600/10 rounded-full blur-3xl animate-pulse-slow"></div>

      <div className="relative z-10 w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8 animate-fade-in">
          <span className="text-6xl">🚗</span>
          <h1 className="text-3xl font-bold gradient-text mt-4">
            Join CampusRide
          </h1>
          <p className="text-dark-400 mt-2">
            Create your account and start sharing rides
          </p>
        </div>

        {/* Form */}
        <form
          onSubmit={handleSubmit}
          className="glass-card p-8 rounded-2xl space-y-5 animate-slide-up"
        >
          <h2 className="text-xl font-semibold text-white">Create Account</h2>

          {error && (
            <div className="bg-red-500/10 border border-red-500/30 text-red-400 text-sm px-4 py-2 rounded-xl">
              {error}
            </div>
          )}

          {/* Google Sign-Up Button */}
          <button
            type="button"
            onClick={handleGoogleSignUp}
            disabled={loading || googleLoading}
            className="w-full flex items-center justify-center gap-3 px-4 py-3 rounded-xl border border-dark-600 bg-dark-800/50 hover:bg-dark-700/70 hover:border-dark-500 text-white font-medium transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {googleLoading ? (
              "⏳ Signing up with Google..."
            ) : (
              <>
                <svg className="w-5 h-5" viewBox="0 0 24 24">
                  <path
                    fill="#4285F4"
                    d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
                  />
                  <path
                    fill="#34A853"
                    d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                  />
                  <path
                    fill="#FBBC05"
                    d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                  />
                  <path
                    fill="#EA4335"
                    d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                  />
                </svg>
                Sign up with Google
              </>
            )}
          </button>

          {/* Divider */}
          <div className="flex items-center gap-3">
            <div className="flex-1 h-px bg-dark-700"></div>
            <span className="text-dark-500 text-xs uppercase tracking-wider">
              or register with email
            </span>
            <div className="flex-1 h-px bg-dark-700"></div>
          </div>

          <div>
            <label className="label-text">Full Name</label>
            <input
              name="name"
              className="input-field"
              placeholder="John Doe"
              value={form.name}
              onChange={handleChange}
              autoFocus
            />
          </div>

          <div>
            <label className="label-text">Email Address</label>
            <input
              name="email"
              type="email"
              className="input-field"
              placeholder="student@campus.edu"
              value={form.email}
              onChange={handleChange}
            />
          </div>

          <div>
            <label className="label-text">Password</label>
            <input
              name="password"
              type="password"
              className="input-field"
              placeholder="••••••••  (min 6 characters)"
              value={form.password}
              onChange={handleChange}
            />
          </div>

          <div>
            <label className="label-text">
              Algorand Wallet Address{" "}
              <span className="text-dark-500">(optional)</span>
            </label>
            <input
              name="walletAddress"
              className="input-field font-mono text-sm"
              placeholder="ALGO..."
              value={form.walletAddress}
              onChange={handleChange}
            />
            <p className="text-xs text-dark-500 mt-1">
              You can connect your wallet later from the navbar.
            </p>
          </div>

          <button
            type="submit"
            className="btn-accent w-full"
            disabled={loading || googleLoading}
          >
            {loading ? "⏳ Creating Account..." : "🎉 Create Account"}
          </button>

          <p className="text-center text-sm text-dark-400">
            Already have an account?{" "}
            <Link
              to="/login"
              className="text-primary-400 hover:text-primary-300 font-medium"
            >
              Sign In
            </Link>
          </p>
        </form>
      </div>
    </div>
  );
}
