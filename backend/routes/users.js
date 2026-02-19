const router = require('express').Router();
const verifyToken = require('../middleware/auth');
const { createUser, getUser, updateUser } = require('../controllers/userController');

router.post('/', verifyToken, createUser);
router.get('/:id', verifyToken, getUser);
router.put('/:id', verifyToken, updateUser);

module.exports = router;
