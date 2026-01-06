# ============================================================================
# HEATING DESIGN WEB UI - Production Dockerfile
# ============================================================================
# Multi-stage build for optimized PWA bundle

# Stage 1: Build stage
FROM node:25-alpine AS builder

LABEL maintainer="Heating Design Team"
LABEL description="Heating Design Web UI - Build Stage"

# Set working directory
WORKDIR /build

# Install build dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++

# Copy package files
COPY package*.json ./
COPY vite.config.ts ./
COPY tsconfig.json ./
COPY tsconfig.node.json ./
COPY index.html ./

# Install dependencies
RUN npm ci --legacy-peer-deps

# Copy source code
COPY src ./src
COPY public ./public

# Build arguments for environment variables
ARG VITE_API_URL=http://localhost:3001
ARG VITE_APP_NAME="Heating Design Pro"
ARG VITE_ENABLE_OFFLINE=true

# Set build environment variables
ENV VITE_API_URL=${VITE_API_URL}
ENV VITE_APP_NAME=${VITE_APP_NAME}
ENV VITE_ENABLE_OFFLINE=${VITE_ENABLE_OFFLINE}

# Build production bundle with PWA support
RUN npm run build

# ============================================================================
# Stage 2: Production stage with NGINX
FROM nginx:alpine

LABEL maintainer="Heating Design Team"
LABEL description="Heating Design Web UI - Production"
LABEL version="1.0.0"

# Install runtime utilities
RUN apk add --no-cache \
    curl \
    wget \
    tzdata

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration
COPY deployment/docker/web/nginx.conf /etc/nginx/conf.d/heating-design.conf

# Copy built application from builder stage
COPY --from=builder /build/dist /usr/share/nginx/html

# Create cache directory for PWA
RUN mkdir -p /usr/share/nginx/html/cache && \
    chown -R nginx:nginx /usr/share/nginx/html

# Set timezone
ENV TZ=UTC

# Expose HTTP port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
