/**
 * Payment Service — High-level helpers for Algorand payments.
 *
 * Used by the backend to:
 *   1. Build unsigned transactions for the frontend (Pera Wallet signing).
 *   2. Verify submitted transactions on-chain.
 *   3. Get account balances.
 */
const { getAlgodClient, getAccountInfo, waitForConfirmation, algosdk } = require('./algorandClient');
const { buildPaymentTxn } = require('./escrow');

/**
 * Create an unsigned payment transaction for the frontend.
 * The frontend will serialize this → send to Pera Wallet for signing → submit.
 *
 * @param {string} senderAddress
 * @param {string} receiverAddress
 * @param {number} amountInAlgos
 * @param {string} note
 * @returns {{ txnBase64: string, txId: string }} - Base64-encoded unsigned txn
 */
async function createPaymentTransaction(senderAddress, receiverAddress, amountInAlgos, note = '') {
    const txn = await buildPaymentTxn(senderAddress, receiverAddress, amountInAlgos, note);
    const encodedTxn = Buffer.from(algosdk.encodeUnsignedTransaction(txn)).toString('base64');

    return {
        txnBase64: encodedTxn,
        txId: txn.txID(),
    };
}

/**
 * Submit a signed transaction (from frontend) to the Algorand network.
 *
 * @param {string} signedTxnBase64 - Base64-encoded signed transaction
 * @returns {{ txId: string, confirmedRound: number }}
 */
async function submitSignedTransaction(signedTxnBase64) {
    const client = getAlgodClient();
    const signedTxnBytes = new Uint8Array(Buffer.from(signedTxnBase64, 'base64'));

    const { txId } = await client.sendRawTransaction(signedTxnBytes).do();
    const confirmed = await waitForConfirmation(txId);

    return {
        txId,
        confirmedRound: confirmed['confirmed-round'],
    };
}

/**
 * Check the status/details of a confirmed transaction.
 *
 * @param {string} txId
 */
async function checkTransactionStatus(txId) {
    try {
        const client = getAlgodClient();
        const result = await client.pendingTransactionInformation(txId).do();
        return {
            txId,
            confirmed: result['confirmed-round'] > 0,
            confirmedRound: result['confirmed-round'],
            poolError: result['pool-error'] || null,
        };
    } catch (err) {
        return { txId, confirmed: false, error: err.message };
    }
}

/**
 * Get the ALGO balance of an account (in ALGOs, not microAlgos).
 *
 * @param {string} address
 * @returns {number} Balance in ALGOs
 */
async function getBalance(address) {
    const info = await getAccountInfo(address);
    return info.amount / 1e6; // microAlgos → ALGOs
}

module.exports = {
    createPaymentTransaction,
    submitSignedTransaction,
    checkTransactionStatus,
    getBalance,
};
