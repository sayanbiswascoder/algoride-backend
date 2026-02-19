/**
 * Navbar — Top navigation bar with wallet connection.
 */
import { Link, useLocation } from "react-router-dom";
import { signOut } from "firebase/auth";
import { auth } from "../services/firebase";
import useStore from "../store/useStore";
import useWallet from "../hooks/useWallet";
import { formatAlgo } from "../services/algorand";

export default function Navbar() {
  const { user, logout } = useStore();
  const { walletAddress, walletConnected, connect, disconnect } = useWallet();
  const { walletBalance } = useStore();
  const location = useLocation();

  const navLinks = [
    { path: "/", label: "Dashboard", icon: "🏠" },
    { path: "/trips", label: "Find Rides", icon: "🔍" },
    { path: "/trips/create", label: "Offer Ride", icon: "🚗" },
    { path: "/my-trips", label: "My Trips", icon: "📋" },
    { path: "/my-bookings", label: "My Bookings", icon: "🎫" },
  ];

  const truncateAddress = (addr) =>
    addr ? `${addr.slice(0, 4)}...${addr.slice(-4)}` : "";

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 glass-card border-b border-dark-700/50 backdrop-blur-2xl">
      <div className="max-w-7xl mx-auto px-4 sm:px-6">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link to="/" className="flex items-center gap-2 group">
            <span className="text-2xl">🚗</span>
            <span className="text-lg font-bold gradient-text hidden sm:inline">
              CampusRide
            </span>
          </Link>

          {/* Nav Links */}
          <div className="hidden md:flex items-center gap-1">
            {navLinks.map((link) => (
              <Link
                key={link.path}
                to={link.path}
                className={`px-3 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${
                  location.pathname === link.path
                    ? "bg-primary-600/20 text-primary-400"
                    : "text-dark-300 hover:text-white hover:bg-dark-700/50"
                }`}
              >
                <span className="mr-1.5">{link.icon}</span>
                {link.label}
              </Link>
            ))}
          </div>

          {/* Right side: Wallet + User */}
          <div className="flex items-center gap-3">
            {/* Wallet */}
            {walletConnected ? (
              <div className="flex items-center gap-2">
                <div className="hidden sm:flex flex-col items-end text-xs">
                  <span className="text-accent-400 font-semibold">
                    {formatAlgo(walletBalance)} ALGO
                  </span>
                  <span className="text-dark-400">
                    {truncateAddress(walletAddress)}
                  </span>
                </div>
                <button
                  onClick={disconnect}
                  className="p-2 rounded-lg bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-colors"
                  title="Disconnect Wallet"
                >
                  ⛓️‍💥
                </button>
              </div>
            ) : (
              <button
                onClick={connect}
                className="flex items-center gap-1.5 px-3 py-2 rounded-lg bg-accent-600/20 text-accent-400 text-sm font-medium hover:bg-accent-600/30 transition-colors"
              >
                <span>🔗</span>
                <span className="hidden sm:inline">Connect Wallet</span>
              </button>
            )}

            {/* User Menu */}
            <div className="flex items-center gap-2 pl-3 border-l border-dark-700">
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-sm font-bold">
                {user?.name?.charAt(0)?.toUpperCase() || "?"}
              </div>
              <span className="text-sm font-medium hidden sm:inline">
                {user?.name}
              </span>
              <button
                onClick={() => {
                  signOut(auth);
                  logout();
                }}
                className="p-2 rounded-lg text-dark-400 hover:text-red-400 hover:bg-dark-700/50 transition-colors"
                title="Logout"
              >
                🚪
              </button>
            </div>
          </div>
        </div>

        {/* Mobile Nav */}
        <div className="flex md:hidden items-center gap-1 pb-2 overflow-x-auto">
          {navLinks.map((link) => (
            <Link
              key={link.path}
              to={link.path}
              className={`flex-shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium transition-all ${
                location.pathname === link.path
                  ? "bg-primary-600/20 text-primary-400"
                  : "text-dark-400 hover:text-white"
              }`}
            >
              {link.icon} {link.label}
            </Link>
          ))}
        </div>
      </div>
    </nav>
  );
}
