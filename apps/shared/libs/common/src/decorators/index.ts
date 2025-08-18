import { SetMetadata } from '@nestjs/common';

// Custom decorators for common functionality

/**
 * Decorator to mark endpoints that should be excluded from logging
 */
export const NoLogging = () => SetMetadata('no-logging', true);

/**
 * Decorator to mark endpoints that require correlation ID
 */
export const RequireCorrelationId = () => SetMetadata('require-correlation-id', true);

/**
 * Decorator to set custom timeout for endpoints
 */
export const Timeout = (ms: number) => SetMetadata('timeout', ms);

/**
 * Decorator to mark endpoints for rate limiting
 */
export const RateLimit = (requests: number, windowMs: number) =>
  SetMetadata('rate-limit', { requests, windowMs });

/**
 * Decorator to mark endpoints as public (no auth required)
 */
export const Public = () => SetMetadata('is-public', true);

/**
 * Decorator to mark endpoints that should be cached
 */
export const Cacheable = (ttl: number) => SetMetadata('cache-ttl', ttl);
