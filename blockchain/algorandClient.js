/**
 * Algorand Client Utility
 * Connects to the Algorand TestNet using the official JS SDK.
 * Uses AlgoNode's free public API (no token required).
 */
const algosdk = require('algosdk');

// Default to AlgoNode's public TestNet endpoint
const ALGOD_SERVER = process.env.ALGOD_SERVER || 'https://testnet-api.algonode.cloud';
const ALGOD_PORT = process.env.ALGOD_PORT || 443;
const ALGOD_TOKEN = process.env.ALGOD_TOKEN || '';

/**
 * Create and return an Algod client instance.
 */
function getAlgodClient() {
    return new algosdk.Algodv2(ALGOD_TOKEN, ALGOD_SERVER, ALGOD_PORT);
}

/**
 * Get suggested transaction parameters from the network.
 */
async function getSuggestedParams() {
    const client = getAlgodClient();
    return await client.getTransactionParams().do();
}

/**
 * Look up an account's balance and info.
 */
async function getAccountInfo(address) {
    const client = getAlgodClient();
    return await client.accountInformation(address).do();
}

/**
 * Wait for a transaction to be confirmed.
 * @param {string} txId - The transaction ID to wait for
 * @param {number} timeout - Max rounds to wait (default 10)
 */
async function waitForConfirmation(txId, timeout = 10) {
    const client = getAlgodClient();
    return await algosdk.waitForConfirmation(client, txId, timeout);
}

module.exports = {
    getAlgodClient,
    getSuggestedParams,
    getAccountInfo,
    waitForConfirmation,
    algosdk,
};
