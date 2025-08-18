# Multi-stage build for optimal image size
FROM node:22-alpine AS base
WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@9

# Install dependencies (leverage Docker cache)
FROM base AS deps
COPY package.json ./
RUN pnpm install --prod

# Build stage
FROM base AS builder
COPY package.json ./
RUN pnpm install
COPY . .
RUN pnpm run build

# Production stage
FROM node:22-alpine AS production
WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@9

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nestjs -u 1001

# Copy built application and dependencies
COPY --from=deps --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /app/package.json ./package.json

# Create logs directory
RUN mkdir -p logs && chown nestjs:nodejs logs

# Switch to non-root user
USER nestjs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/v1/health/live || exit 1

# Expose port
EXPOSE 3000

# Start the application
CMD ["node", "dist/main.js"]
