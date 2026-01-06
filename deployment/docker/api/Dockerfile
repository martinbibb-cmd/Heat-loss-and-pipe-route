# ============================================================================
# HEATING DESIGN API - Production Dockerfile
# ============================================================================
# Multi-stage build for optimized image size

# Stage 1: Build stage
FROM node:20-alpine AS builder

LABEL maintainer="Heating Design Team"
LABEL description="Heating Design API - Build Stage"

# Set working directory
WORKDIR /build

# Install build dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    cairo-dev \
    jpeg-dev \
    pango-dev \
    giflib-dev \
    pixman-dev

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies (including dev dependencies for build)
RUN npm ci --legacy-peer-deps

# Copy source code
COPY src ./src
COPY prisma ./prisma

# Generate Prisma client
RUN npx prisma generate

# Build TypeScript to JavaScript
RUN npm run build

# Remove dev dependencies
RUN npm prune --production

# ============================================================================
# Stage 2: Production stage
FROM node:20-alpine

LABEL maintainer="Heating Design Team"
LABEL description="Heating Design API - Production"
LABEL version="1.0.0"

# Install runtime dependencies
RUN apk add --no-cache \
    dumb-init \
    cairo \
    jpeg \
    pango \
    giflib \
    pixman \
    curl \
    wget \
    postgresql-client \
    tzdata

# Create app user for security
RUN addgroup -g 1001 -S appuser && \
    adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G appuser appuser

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=appuser:appuser /build/dist ./dist
COPY --from=builder --chown=appuser:appuser /build/node_modules ./node_modules
COPY --from=builder --chown=appuser:appuser /build/package*.json ./
COPY --from=builder --chown=appuser:appuser /build/prisma ./prisma

# Create necessary directories with proper permissions
RUN mkdir -p /app/uploads /app/exports /app/temp /app/logs && \
    chown -R appuser:appuser /app

# Set environment variables
ENV NODE_ENV=production \
    PORT=3001 \
    TZ=UTC

# Expose API port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

# Switch to non-root user
USER appuser

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "dist/server.js"]
