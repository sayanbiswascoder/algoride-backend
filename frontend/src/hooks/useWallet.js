/**
 * Pera Wallet hook — manages connect/disconnect with Pera Wallet.
 */
import { useCallback, useEffect, useRef } from 'react';
import { PeraWalletConnect } from '@perawallet/connect';
import useStore from '../store/useStore';
import { getBalance } from '../services/algorand';

const peraWallet = new PeraWalletConnect();

export default function useWallet() {
    const { walletAddress, walletConnected, setWallet, disconnectWallet, setWalletBalance, showNotification } = useStore();
    const reconnectAttempted = useRef(false);

    // Try to reconnect on mount
    useEffect(() => {
        if (reconnectAttempted.current) return;
        reconnectAttempted.current = true;

        peraWallet.reconnectSession()
            .then(async (accounts) => {
                if (accounts.length > 0) {
                    const balance = await getBalance(accounts[0]);
                    setWallet(accounts[0], balance);
                }
            })
            .catch(() => { /* no prior session */ });
    }, []);

    const connect = useCallback(async () => {
        try {
            const accounts = await peraWallet.connect();
            const address = accounts[0];
            const balance = await getBalance(address);
            setWallet(address, balance);
            showNotification('Wallet connected!', 'success');

            peraWallet.connector?.on('disconnect', () => {
                disconnectWallet();
            });

            return address;
        } catch (err) {
            if (err?.data?.type !== 'CONNECT_MODAL_CLOSED') {
                console.error('Wallet connect error:', err);
                showNotification('Failed to connect wallet', 'error');
            }
            return null;
        }
    }, []);

    const disconnect = useCallback(async () => {
        try {
            await peraWallet.disconnect();
            disconnectWallet();
            showNotification('Wallet disconnected', 'info');
        } catch (err) {
            console.error('Wallet disconnect error:', err);
        }
    }, []);

    const refreshBalance = useCallback(async () => {
        if (!walletAddress) return;
        const balance = await getBalance(walletAddress);
        setWalletBalance(balance);
    }, [walletAddress]);

    /**
     * Sign transactions using Pera Wallet.
     * @param {Array} txns   Array of unsigned transaction objects
     * @returns {Array} Array of signed transaction Uint8Arrays
     */
    const signTransactions = useCallback(async (txns) => {
        const txnGroups = txns.map((txn) => ({ txn, signers: [walletAddress] }));
        const signedTxns = await peraWallet.signTransaction([txnGroups]);
        return signedTxns;
    }, [walletAddress]);

    return {
        walletAddress,
        walletConnected,
        connect,
        disconnect,
        refreshBalance,
        signTransactions,
        peraWallet,
    };
}
