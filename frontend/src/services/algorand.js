/**
 * Algorand Frontend Service
 * Build transactions for Pera Wallet signing.
 */
import algosdk from 'algosdk';

const ALGOD_SERVER = 'https://testnet-api.algonode.cloud';
const ALGOD_PORT = 443;
const ALGOD_TOKEN = '';

export function getAlgodClient() {
    return new algosdk.Algodv2(ALGOD_TOKEN, ALGOD_SERVER, ALGOD_PORT);
}

/**
 * Get the ALGO balance for an address (in ALGOs).
 */
export async function getBalance(address) {
    try {
        const client = getAlgodClient();
        const info = await client.accountInformation(address).do();
        return info.amount / 1e6;
    } catch (err) {
        console.error('getBalance error:', err);
        return 0;
    }
}

/**
 * Build an unsigned payment transaction.
 * Returns the transaction object ready for Pera Wallet signing.
 */
export async function buildPaymentTxn(senderAddress, receiverAddress, amountInAlgos, note = '') {
    const client = getAlgodClient();
    const suggestedParams = await client.getTransactionParams().do();
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
 * Submit a signed transaction to the network.
 */
export async function submitTransaction(signedTxn) {
    const client = getAlgodClient();
    const { txId } = await client.sendRawTransaction(signedTxn).do();
    const result = await algosdk.waitForConfirmation(client, txId, 10);
    return { txId, confirmedRound: result['confirmed-round'] };
}

/**
 * Convert microAlgos to ALGOs display string.
 */
export function microAlgosToAlgos(microAlgos) {
    return (microAlgos / 1e6).toFixed(6);
}

/**
 * Format ALGO amount for display.
 */
export function formatAlgo(amount) {
    return parseFloat(amount).toFixed(4);
}
