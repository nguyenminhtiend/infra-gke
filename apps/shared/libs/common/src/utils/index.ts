import { randomBytes } from 'crypto';
import { ApiResponse, MetricData } from '../types';

/**
 * Generate a unique correlation ID for request tracing
 */
export function generateCorrelationId(): string {
  return randomBytes(16).toString('hex');
}

/**
 * Generate a timestamp in ISO format
 */
export function generateTimestamp(): string {
  return new Date().toISOString();
}

/**
 * Create a standardized API response
 */
export function createApiResponse<T>(
  data: T,
  message?: string,
  service = 'unknown'
): ApiResponse<T> {
  return {
    success: true,
    data,
    message,
    timestamp: generateTimestamp(),
    service
  };
}

/**
 * Create a standardized error response
 */
export function createErrorResponse(message: string, service = 'unknown'): ApiResponse {
  return {
    success: false,
    message,
    timestamp: generateTimestamp(),
    service
  };
}

/**
 * Sleep utility for async operations
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Retry utility with exponential backoff
 */
export async function retry<T>(fn: () => Promise<T>, maxRetries = 3, baseDelay = 1000): Promise<T> {
  let lastError: Error;

  for (let i = 0; i <= maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      if (i === maxRetries) {
        throw lastError;
      }

      const delay = baseDelay * Math.pow(2, i);
      await sleep(delay);
    }
  }

  throw lastError!;
}

/**
 * Parse memory usage and return in human readable format
 */
export function formatMemoryUsage(bytes: number): string {
  const units = ['B', 'KB', 'MB', 'GB'];
  let value = bytes;
  let unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  return `${value.toFixed(2)} ${units[unitIndex]}`;
}

/**
 * Create metric data structure
 */
export function createMetric(
  name: string,
  value: number,
  unit: string,
  tags?: Record<string, string>
): MetricData {
  return {
    name,
    value,
    unit,
    timestamp: generateTimestamp(),
    tags
  };
}

/**
 * Sanitize string for logging (remove sensitive data)
 */
export function sanitizeForLogging(obj: any): any {
  const sensitiveFields = ['password', 'token', 'secret', 'key', 'authorization'];

  if (typeof obj !== 'object' || obj === null) {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map(sanitizeForLogging);
  }

  const sanitized: any = {};
  for (const [key, value] of Object.entries(obj)) {
    if (sensitiveFields.some((field) => key.toLowerCase().includes(field))) {
      sanitized[key] = '[REDACTED]';
    } else if (typeof value === 'object') {
      sanitized[key] = sanitizeForLogging(value);
    } else {
      sanitized[key] = value;
    }
  }

  return sanitized;
}
