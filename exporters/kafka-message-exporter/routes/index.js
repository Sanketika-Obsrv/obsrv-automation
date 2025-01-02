const express = require('express');
const router = express.Router();

const { register } = require('../services/prometheus')

router.get('/metrics', async (request, response, next) => {
  try {
    response.set('Content-Type', register.contentType);
    const metrics = await register.metrics()
    response.status(200).send(metrics);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
