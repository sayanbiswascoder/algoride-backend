import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { nodePolyfills } from 'vite-plugin-node-polyfills';

export default defineConfig({
    plugins: [
        react(),
        nodePolyfills({
            // Polyfill all needed modules for algosdk / @perawallet/connect
            include: ['buffer', 'crypto', 'stream', 'util', 'process', 'events', 'string_decoder'],
            globals: {
                Buffer: true,
                global: true,
                process: true,
            },
            // Don't externalize — actually polyfill them
            overrides: {
                fs: 'empty',
            },
            protocolImports: true,
        }),
    ],
    define: {
        // Ensure global is defined even if the plugin misses it
        global: 'globalThis',
    },
    resolve: {
        alias: {
            // Force buffer to resolve to the polyfill
            buffer: 'buffer',
        },
    },
    server: {
        port: 3000,
        proxy: {
            '/api': {
                target: 'http://localhost:5000',
                changeOrigin: true,
            },
        },
    },
    optimizeDeps: {
        esbuildOptions: {
            // Define global for esbuild (pre-bundling phase)
            define: {
                global: 'globalThis',
            },
        },
    },
});
