# Campus Ride-Share with Algorand Crypto Settlement

A web-based ride-sharing coordination platform for students. Drivers post trips, riders book seats, and payments are automatically settled in ALGO cryptocurrency on the **Algorand TestNet**.

---

## ✨ Features

| Feature | Description |
|---|---|
| **Authentication** | Simple email-based login / registration |
| **Driver Dashboard** | Create trips, view passengers, mark trips complete |
| **Rider Search** | Search trips by origin / destination, book seats |
| **Maps Integration** | Mapbox GL for interactive location selection & distance calculation |
| **ALGO Payments** | Pera Wallet integration for TestNet ALGO payments |
| **Escrow Logic** | Backend escrow account — funds held until trip completion |
| **Rating System** | Riders rate drivers, running average updated automatically |
| **Wallet Balance** | Live ALGO balance display in navbar |
| **Transaction History** | View payment tx IDs with links to AlgoExplorer |

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 18 + Vite, TailwindCSS, Zustand, react-map-gl (Mapbox) |
| Backend | Node.js + Express, Prisma ORM + SQLite |
| Blockchain | Algorand JS SDK (`algosdk`), Pera Wallet (`@perawallet/connect`) |
| Network | Algorand **TestNet** via [AlgoNode](https://algonode.cloud) |

---

## 📁 Project Structure

```
├── backend/
│   ├── controllers/       # Route handlers
│   ├── models/            # Prisma client
│   ├── prisma/            # Schema & migrations
│   ├── routes/            # Express routes
│   ├── server.js          # Entry point
│   └── .env               # Backend environment vars
│
├── blockchain/
│   ├── algorandClient.js  # Algod client & helpers
│   ├── escrow.js          # Escrow account logic
│   └── paymentService.js  # Payment transaction helpers
│
├── frontend/
│   ├── src/
│   │   ├── components/    # Reusable UI components
│   │   ├── hooks/         # Custom hooks (useWallet)
│   │   ├── pages/         # Route pages
│   │   ├── services/      # API & Algorand helpers
│   │   ├── store/         # Zustand global state
│   │   ├── App.jsx        # Root component
│   │   └── main.jsx       # Entry point
│   ├── index.html
│   ├── tailwind.config.js
│   └── .env               # Frontend environment vars
│
└── docs/
    └── README.md
```

---

## 🚀 Quick Start

### Prerequisites

- **Node.js** ≥ 18
- **npm** ≥ 9
- **Pera Wallet** mobile app (for TestNet ALGO payments)
- **Mapbox API Key** (optional — text inputs used as fallback)

### 1. Clone & Install

```bash
# Backend
cd backend
npm install
npx prisma db push       # Create SQLite database

# Frontend
cd ../frontend
npm install
```

### 2. Environment Variables

**Backend** (`backend/.env`):
```env
PORT=5000
DATABASE_URL="file:./dev.db"
ALGOD_SERVER=https://testnet-api.algonode.cloud
ALGOD_PORT=443
ALGOD_TOKEN=
```

**Frontend** (`frontend/.env`):
```env
VITE_BACKEND_URL=http://localhost:5000
VITE_MAP_API_KEY=your_mapbox_public_token_here
```

> Get a free Mapbox token at [mapbox.com](https://account.mapbox.com/). The app works without it (fallback to text inputs).

### 3. Run

```bash
# Terminal 1 — Backend
cd backend
npm run dev           # Starts on http://localhost:5000

# Terminal 2 — Frontend
cd frontend
npm run dev           # Starts on http://localhost:3000
```

Open **http://localhost:3000** in your browser.

---

## 💸 Algorand Payment Flow

```
1. Rider books seats → booking created (status: pending)
2. Rider clicks "Pay Now" → Pera Wallet opens
3. ALGO sent from rider → driver's wallet (or escrow)
4. Transaction ID recorded in backend
5. Driver marks trip complete → bookings finalized
6. Escrow release (if used) sends funds to driver
```

### TestNet Setup

1. Install **Pera Wallet** on your phone
2. Switch to **TestNet** in Pera settings
3. Get free test ALGO from the [TestNet Dispenser](https://bank.testnet.algorand.network/)

---

## 📡 API Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| POST   | `/api/users` | Register user |
| POST   | `/api/users/login` | Login by email |
| GET    | `/api/users/:id` | Get user profile |
| PUT    | `/api/users/:id` | Update profile |
| POST   | `/api/trips` | Create trip |
| GET    | `/api/trips` | List active trips |
| GET    | `/api/trips/:id` | Get trip detail |
| GET    | `/api/trips/driver/:driverId` | Get driver's trips |
| PATCH  | `/api/trips/:id/status` | Update trip status |
| POST   | `/api/bookings` | Book seats |
| GET    | `/api/bookings/:userId` | Get user's bookings |
| PATCH  | `/api/bookings/:id/status` | Update booking |
| POST   | `/api/ratings` | Submit rating |
| GET    | `/api/ratings/:userId` | Get user ratings |
| POST   | `/api/payments/initiate` | Record payment (escrow) |
| POST   | `/api/payments/complete` | Release payment |
| GET    | `/api/payments/booking/:bookingId` | Get payments |

---

## 🗄️ Database Schema

| Model | Key Fields |
|-------|-----------|
| **User** | id, name, email, walletAddress, rating, totalTrips |
| **Trip** | id, driverId, origin, destination, distance, departureTime, seatsAvailable, pricePerKm, status |
| **Booking** | id, tripId, riderId, seatsBooked, totalFare, paymentTxId, status |
| **Rating** | id, fromUserId, toUserId, rating, comment |
| **Payment** | id, bookingId, userId, txId, amount, status |

---

## 📝 License

MIT — Built for educational purposes.
