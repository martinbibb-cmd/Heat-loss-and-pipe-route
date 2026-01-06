/**
 * Calculation Routes
 */

import { Router } from 'express';

const router = Router();

/**
 * POST /api/calculations/room
 * Calculate heat loss for a single room
 */
router.post('/room', async (req, res) => {
  res.status(200).json({
    message: 'Room calculation endpoint - to be implemented',
  });
});

/**
 * POST /api/calculations/building
 * Calculate heat loss for entire building
 */
router.post('/building', async (req, res) => {
  res.status(200).json({
    message: 'Building calculation endpoint - to be implemented',
  });
});

export default router;
