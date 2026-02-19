/**
 * PaymentModal — Modal for sending ALGO payment via Pera Wallet.
 */
import { useState } from 'react';
import useWallet from '../hooks/useWallet';
import useStore from '../store/useStore';
import { buildPaymentTxn, submitTransaction, formatAlgo } from '../services/algorand';
import { initiatePayment } from '../services/api';

export default function PaymentModal({ booking, driverWallet, onClose, onSuccess }) {
    const { walletAddress, walletConnected, connect, signTransactions, refreshBalance } = useWallet();
    const { showNotification } = useStore();
    const [step, setStep] = useState('confirm'); // confirm | processing | done | error
    const [txId, setTxId] = useState(null);
    const [error, setError] = useState(null);

    const handlePay = async () => {
        if (!walletConnected) {
            const addr = await connect();
            if (!addr) return;
        }

        try {
            setStep('processing');
            setError(null);

            // Build the payment transaction
            const txn = await buildPaymentTxn(
                walletAddress,
                driverWallet,
                booking.totalFare,
                `CampusRideShare: Booking ${booking.id}`
            );

            // Sign with Pera Wallet
            const signedTxns = await signTransactions([txn]);

            // Submit to network
            const result = await submitTransaction(signedTxns[0]);
            setTxId(result.txId);

            // Record payment in backend
            await initiatePayment({
                bookingId: booking.id,
                userId: booking.riderId,
                txId: result.txId,
                amount: booking.totalFare,
            });

            await refreshBalance();
            setStep('done');
            showNotification('Payment sent successfully!', 'success');
            onSuccess?.(result.txId);
        } catch (err) {
            console.error('Payment error:', err);
            setError(err.message || 'Payment failed');
            setStep('error');
            showNotification('Payment failed. Please try again.', 'error');
        }
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in">
            <div className="glass-card border border-dark-600 p-6 rounded-2xl max-w-md w-full mx-4 space-y-5 shadow-2xl">
                {/* Header */}
                <div className="flex items-center justify-between">
                    <h3 className="text-lg font-bold text-white">
                        {step === 'done' ? '✅ Payment Complete' : '💸 Send Payment'}
                    </h3>
                    <button onClick={onClose} className="text-dark-400 hover:text-white transition-colors text-xl">✕</button>
                </div>

                {/* Payment Details */}
                <div className="glass-card p-4 rounded-xl space-y-2 bg-dark-900/50">
                    <div className="flex justify-between text-sm">
                        <span className="text-dark-400">Amount</span>
                        <span className="text-accent-400 font-bold text-lg">{formatAlgo(booking.totalFare)} ALGO</span>
                    </div>
                    <div className="flex justify-between text-xs">
                        <span className="text-dark-500">To (Driver)</span>
                        <span className="text-dark-300 font-mono">
                            {driverWallet ? `${driverWallet.slice(0, 8)}...${driverWallet.slice(-6)}` : 'N/A'}
                        </span>
                    </div>
                    <div className="flex justify-between text-xs">
                        <span className="text-dark-500">From (You)</span>
                        <span className="text-dark-300 font-mono">
                            {walletAddress ? `${walletAddress.slice(0, 8)}...${walletAddress.slice(-6)}` : 'Not connected'}
                        </span>
                    </div>
                    <div className="flex justify-between text-xs">
                        <span className="text-dark-500">Network</span>
                        <span className="text-primary-400">Algorand TestNet</span>
                    </div>
                </div>

                {/* Status */}
                {step === 'processing' && (
                    <div className="text-center py-4">
                        <div className="animate-spin text-3xl mb-2">⏳</div>
                        <p className="text-sm text-dark-300">Processing payment... Please confirm in Pera Wallet</p>
                    </div>
                )}

                {step === 'done' && txId && (
                    <div className="glass-card p-3 rounded-xl bg-accent-500/5 border border-accent-500/20">
                        <p className="text-xs text-dark-400 mb-1">Transaction ID</p>
                        <a
                            href={`https://testnet.algoexplorer.io/tx/${txId}`}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-xs text-accent-400 font-mono break-all hover:underline"
                        >
                            {txId}
                        </a>
                    </div>
                )}

                {step === 'error' && (
                    <div className="glass-card p-3 rounded-xl bg-red-500/5 border border-red-500/20">
                        <p className="text-xs text-red-400">{error}</p>
                    </div>
                )}

                {/* Actions */}
                <div className="flex gap-3">
                    {step === 'confirm' && (
                        <>
                            <button onClick={onClose} className="btn-secondary flex-1">Cancel</button>
                            <button onClick={handlePay} className="btn-accent flex-1" disabled={!driverWallet}>
                                {walletConnected ? '💸 Pay Now' : '🔗 Connect & Pay'}
                            </button>
                        </>
                    )}
                    {step === 'error' && (
                        <>
                            <button onClick={onClose} className="btn-secondary flex-1">Cancel</button>
                            <button onClick={handlePay} className="btn-primary flex-1">🔄 Retry</button>
                        </>
                    )}
                    {step === 'done' && (
                        <button onClick={onClose} className="btn-primary w-full">Done</button>
                    )}
                </div>
            </div>
        </div>
    );
}
