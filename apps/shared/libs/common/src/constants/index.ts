// Common constants used across services

export const HTTP_STATUS_CODES = {
  OK: 200,
  CREATED: 201,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503
} as const;

export const HEADER_NAMES = {
  CORRELATION_ID: 'x-correlation-id',
  USER_ID: 'x-user-id',
  REQUEST_ID: 'x-request-id',
  TRACE_ID: 'x-trace-id',
  CONTENT_TYPE: 'content-type',
  AUTHORIZATION: 'authorization'
} as const;

export const MIME_TYPES = {
  JSON: 'application/json',
  XML: 'application/xml',
  TEXT: 'text/plain',
  HTML: 'text/html',
  FORM_DATA: 'multipart/form-data',
  URL_ENCODED: 'application/x-www-form-urlencoded'
} as const;

export const CACHE_KEYS = {
  USER_PROFILE: 'user:profile:',
  SERVICE_CONFIG: 'service:config:',
  HEALTH_STATUS: 'health:status:'
} as const;

export const METRICS = {
  HTTP_REQUESTS_TOTAL: 'http_requests_total',
  HTTP_REQUEST_DURATION: 'http_request_duration_seconds',
  MEMORY_USAGE: 'memory_usage_bytes',
  CPU_USAGE: 'cpu_usage_percent',
  ACTIVE_CONNECTIONS: 'active_connections',
  ERROR_RATE: 'error_rate'
} as const;

export const ENVIRONMENTS = {
  DEVELOPMENT: 'development',
  STAGING: 'staging',
  PRODUCTION: 'production',
  TEST: 'test'
} as const;

export const LOG_LEVELS = {
  ERROR: 'error',
  WARN: 'warn',
  INFO: 'info',
  DEBUG: 'debug',
  VERBOSE: 'verbose'
} as const;
