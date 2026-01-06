/**
 * Atlas Integration Routes
 * API endpoints for Atlas iOS app integration
 */

import { Router } from 'express';

const router = Router();

/**
 * POST /api/atlas/import
 * Import survey data from Atlas app
 */
router.post('/import', async (req, res) => {
  res.status(201).json({
    message: 'Atlas import endpoint - to be implemented',
    projectId: 'example-project-id',
  });
});

/**
 * GET /api/atlas/status
 * Check Atlas integration status
 */
router.get('/status', async (req, res) => {
  res.status(200).json({
    status: 'ok',
    integration: 'enabled',
    version: '1.0.0',
  });
});

export default router;
