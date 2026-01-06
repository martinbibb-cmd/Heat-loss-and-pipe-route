/**
 * Application Configuration
 */

import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config();

export const config = {
  // Server
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3001', 10),

  // Database
  databaseUrl: process.env.DATABASE_URL || '',

  // Security
  jwtSecret: process.env.JWT_SECRET || 'change-me-in-production',
  jwtExpiry: process.env.JWT_EXPIRY || '7d',
  apiKey: process.env.API_KEY || '',

  // CORS
  allowedOrigins: (process.env.ALLOWED_ORIGINS || '*').split(','),

  // File uploads
  uploadDir: process.env.UPLOAD_DIR || path.join(__dirname, '../../uploads'),
  exportDir: process.env.EXPORT_DIR || path.join(__dirname, '../../exports'),
  tempDir: process.env.TEMP_DIR || path.join(__dirname, '../../temp'),
  maxFileSize: parseInt(process.env.MAX_FILE_SIZE || '52428800', 10), // 50MB
  maxFilesPerProject: parseInt(process.env.MAX_FILES_PER_PROJECT || '10', 10),

  // Calculation settings
  calcTimeout: parseInt(process.env.CALC_TIMEOUT || '30000', 10), // 30s
  calcPrecision: parseInt(process.env.CALC_PRECISION || '2', 10),

  // Atlas integration
  atlasWebhookUrl: process.env.ATLAS_WEBHOOK_URL || '',
  enableWebhooks: process.env.ENABLE_WEBHOOKS === 'true',

  // Logging
  logLevel: process.env.LOG_LEVEL || 'info',
  logFormat: process.env.LOG_FORMAT || 'json',
};

// Validation
if (config.nodeEnv === 'production') {
  if (!config.databaseUrl) {
    throw new Error('DATABASE_URL is required in production');
  }
  if (config.jwtSecret === 'change-me-in-production') {
    throw new Error('JWT_SECRET must be changed in production');
  }
}

export default config;
