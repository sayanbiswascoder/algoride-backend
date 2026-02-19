const router = require('express').Router();
const verifyToken = require('../middleware/auth');
const {
    createBooking, getBookingsByUser, updateBookingStatus,
} = require('../controllers/bookingController');

router.post('/', verifyToken, createBooking);
router.get('/:userId', verifyToken, getBookingsByUser);
router.patch('/:id/status', verifyToken, updateBookingStatus);

module.exports = router;
