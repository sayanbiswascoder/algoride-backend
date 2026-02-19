const router = require('express').Router();
const verifyToken = require('../middleware/auth');
const {
    createTrip, getTrips, getTrip, getTripsByDriver, updateTripStatus,
} = require('../controllers/tripController');

router.post('/', verifyToken, createTrip);
router.get('/', verifyToken, getTrips);
router.get('/:id', verifyToken, getTrip);
router.get('/driver/:driverId', verifyToken, getTripsByDriver);
router.patch('/:id/status', verifyToken, updateTripStatus);

module.exports = router;
