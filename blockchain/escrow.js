/**
 * Escrow Logic for Campus Ride-Share
 *
 * This module implements a simple account-based escrow pattern:
 *   1. Generate a fresh escrow account (keypair).
 *   2. Rider sends ALGO to the escrow account (held until trip completion).
 *   3. On trip completion, the escrow account sends ALGO to the driver.
 *
 * For production, replace with an Algorand Smart Contract (Application)
 * that enforces on-chain rules. This MVP uses a custodial approach where
 * the backend holds the escrow secret key.
 *
 * ⚠️  Never expose escrow secret keys to the frontend.
 */
const { algosdk, getAlgodClient, getSuggestedParams, waitForConfirmation } = require('./algorandClient');

/**
 * Generate a new escrow account (keypair).
 * Returns { address, secretKey } — store secretKey securely on the server.
 */
function generateEscrowAccount() {
    const account = algosdk.generateAccount();
    return {
        address: account.addr,
        secretKey: account.sk,              // Uint8Array
        mnemonic: algosdk.secretKeyToMnemonic(account.sk),
    };
}

/**
 * Build a payment transaction from sender → receiver.
 * This returns an UNSIGNED transaction object that can be:
 *   • Signed on the backend (escrow release), or
 *   • Serialized and sent to the frontend for Pera Wallet signing.
 *
 * @param {string}  senderAddress   - Sender wallet address
 * @param {string}  receiverAddress - Receiver wallet address
 * @param {number}  amountInAlgos   - Amount in ALGOs (will be converted to microAlgos)
 * @param {string}  [note]          - Optional note
 */
async function buildPaymentTxn(senderAddress, receiverAddress, amountInAlgos, note = '') {
    const suggestedParams = await getSuggestedParams();
    const amountInMicroAlgos = Math.floor(amountInAlgos * 1e6);

    const txn = algosdk.makePaymentTxnWithSuggestedParamsFromObject({
        from: senderAddress,
        to: receiverAddress,
        amount: amountInMicroAlgos,
        note: new Uint8Array(Buffer.from(note)),
        suggestedParams,
    });

    return txn;
}

/**
 * Release escrowed funds to the driver.
 * Called by the backend when a trip is marked as completed.
 *
 * @param {Uint8Array} escrowSecretKey   - The escrow account's secret key
 * @param {string}     escrowAddress     - The escrow account's address
 * @param {string}     driverAddress     - The driver's wallet address
 * @param {number}     amountInAlgos     - Amount to release (in ALGOs)
 */
async function releaseEscrow(escrowSecretKey, escrowAddress, driverAddress, amountInAlgos) {
    const client = getAlgodClient();
    const note = `CampusRideShare: Trip payment release to ${driverAddress}`;

    const txn = await buildPaymentTxn(escrowAddress, driverAddress, amountInAlgos, note);

    // Sign with the escrow's secret key (server-side only)
    const signedTxn = txn.signTxn(escrowSecretKey);

    // Submit to the network
    const { txId } = await client.sendRawTransaction(signedTxn).do();
    console.log(`Escrow release txn submitted: ${txId}`);

    // Wait for confirmation
    const confirmed = await waitForConfirmation(txId);
    console.log(`Escrow release confirmed in round ${confirmed['confirmed-round']}`);

    return { txId, confirmedRound: confirmed['confirmed-round'] };
}

module.exports = {
    generateEscrowAccount,
    buildPaymentTxn,
    releaseEscrow,
};
