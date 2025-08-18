// Common types used across services

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  message?: string;
  timestamp: string;
  service: string;
}

export interface HealthStatus {
  status: 'ok' | 'error';
  timestamp: string;
  uptime: number;
  version: string;
  environment: string;
  checks?: Record<string, any>;
}

export interface LogContext {
  service: string;
  version: string;
  environment: string;
  correlationId?: string;
  userId?: string;
  traceId?: string;
  spanId?: string;
}

export interface ServiceInfo {
  name: string;
  version: string;
  description: string;
  environment: string;
  startTime: string;
  region?: string;
}

export interface MetricData {
  name: string;
  value: number;
  unit: string;
  timestamp: string;
  tags?: Record<string, string>;
}

export enum LogLevel {
  ERROR = 'error',
  WARN = 'warn',
  INFO = 'info',
  DEBUG = 'debug',
  VERBOSE = 'verbose'
}

export enum Environment {
  DEVELOPMENT = 'development',
  STAGING = 'staging',
  PRODUCTION = 'production',
  TEST = 'test'
}
