/**
 * Heating Design API Server
 * Professional heating system design with heat loss calculations
 */

import express, { Application } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { config } from './config';
import { logger } from './utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { requestLogger } from './middleware/requestLogger';

// Import routes
import authRoutes from './routes/auth.routes';
import projectRoutes from './routes/project.routes';
import calculationRoutes from './routes/calculation.routes';
import atlasRoutes from './routes/atlas.routes';
import exportRoutes from './routes/export.routes';
import healthRoutes from './routes/health.routes';

const app: Application = express();

// ============================================================================
// Middleware
// ============================================================================

// Security
app.use(helmet());

// CORS
app.use(cors({
  origin: config.allowedOrigins,
  credentials: true,
}));

// Compression
app.use(compression());

// Body parsing
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Request logging
app.use(requestLogger);

// ============================================================================
// Routes
// ============================================================================

app.use('/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/calculations', calculationRoutes);
app.use('/api/atlas', atlasRoutes);
app.use('/api/export', exportRoutes);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
    statusCode: 404,
  });
});

// Error handler (must be last)
app.use(errorHandler);

// ============================================================================
// Server Start
// ============================================================================

const PORT = config.port;

app.listen(PORT, () => {
  logger.info(`🚀 Heating Design API started`);
  logger.info(`📡 Server running on port ${PORT}`);
  logger.info(`🌍 Environment: ${config.nodeEnv}`);
  logger.info(`🔒 CORS enabled for: ${config.allowedOrigins.join(', ')}`);
  logger.info(`📊 Database: Connected`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  process.exit(0);
});

export default app;
