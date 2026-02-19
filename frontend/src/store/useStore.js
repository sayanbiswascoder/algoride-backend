/**
 * Zustand store — Global app state for auth, wallet, and UI.
 * Auth persistence is now handled by Firebase onAuthStateChanged.
 */
import { create } from 'zustand';

const useStore = create((set, get) => ({
    // ── Auth ────────────────────────────────────────
    user: null,
    authLoading: true, // true until Firebase auth state is resolved
    setUser: (user) => {
        set({ user, authLoading: false });
    },
    setAuthLoading: (loading) => set({ authLoading: loading }),
    logout: () => {
        set({ user: null, walletAddress: null, walletBalance: 0 });
    },

    // ── Wallet ──────────────────────────────────────
    walletAddress: null,
    walletBalance: 0,
    walletConnected: false,
    setWallet: (address, balance = 0) =>
        set({ walletAddress: address, walletBalance: balance, walletConnected: !!address }),
    setWalletBalance: (balance) => set({ walletBalance: balance }),
    disconnectWallet: () =>
        set({ walletAddress: null, walletBalance: 0, walletConnected: false }),

    // ── UI ──────────────────────────────────────────
    loading: false,
    setLoading: (loading) => set({ loading }),
    notification: null,
    showNotification: (message, type = 'info') => {
        set({ notification: { message, type } });
        setTimeout(() => set({ notification: null }), 4000);
    },
}));

export default useStore;
