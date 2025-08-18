import * as Joi from 'joi';

export const configValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test', 'staging')
    .default('development'),
  PORT: Joi.number().port().default(3000),
  LOG_LEVEL: Joi.string()
    .valid('error', 'warn', 'info', 'debug')
    .default('info'),
  CORS_ORIGINS: Joi.string().default('http://localhost:3000'),

  // Google Cloud specific
  GOOGLE_CLOUD_PROJECT: Joi.string().optional(),
  GOOGLE_CLOUD_REGION: Joi.string().default('asia-southeast1'),

  // Observability
  OTEL_SERVICE_NAME: Joi.string().default('service-a'),
  OTEL_EXPORTER_OTLP_ENDPOINT: Joi.string().optional(),

  // Health check intervals (in seconds)
  HEALTH_CHECK_INTERVAL: Joi.number().default(30),
  READINESS_CHECK_INTERVAL: Joi.number().default(10),
});
