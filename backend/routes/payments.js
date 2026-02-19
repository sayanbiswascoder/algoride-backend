const router = require('express').Router();
const verifyToken = require('../middleware/auth');
const {
    initiatePayment, completePayment, getPaymentsByBooking,
} = require('../controllers/paymentController');

router.post('/initiate', verifyToken, initiatePayment);
router.post('/complete', verifyToken, completePayment);
router.get('/booking/:bookingId', verifyToken, getPaymentsByBooking);

module.exports = router;
