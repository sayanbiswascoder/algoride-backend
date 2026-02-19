const router = require('express').Router();
const verifyToken = require('../middleware/auth');
const { createRating, getRatings } = require('../controllers/ratingController');

router.post('/', verifyToken, createRating);
router.get('/:userId', verifyToken, getRatings);

module.exports = router;
