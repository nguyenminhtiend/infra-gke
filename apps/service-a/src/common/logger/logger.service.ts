import { Injectable, LoggerService, ConsoleLogger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as winston from 'winston';
import { LoggingWinston } from '@google-cloud/logging-winston';

@Injectable()
export class Logger extends ConsoleLogger implements LoggerService {
  private readonly logger: winston.Logger;

  constructor(private readonly configService: ConfigService) {
    super();

    const logLevel = this.configService.get('LOG_LEVEL') || 'info';
    const nodeEnv = this.configService.get('NODE_ENV') || 'development';
    const serviceName = this.configService.get('OTEL_SERVICE_NAME') || 'service-a';

    const transports: winston.transport[] = [];

    if (nodeEnv === 'production') {
      // Google Cloud Logging in production
      const loggingWinston = new LoggingWinston({
        projectId: this.configService.get('GOOGLE_CLOUD_PROJECT'),
        keyFilename: this.configService.get('GOOGLE_APPLICATION_CREDENTIALS'),
        logName: serviceName,
      });
      transports.push(loggingWinston);
    } else {
      // Console logging for development
      transports.push(
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.timestamp(),
            winston.format.colorize(),
            winston.format.printf(({ timestamp, level, message, ...meta }) => {
              return `${timestamp} [${level}] ${message} ${
                Object.keys(meta).length ? JSON.stringify(meta, null, 2) : ''
              }`;
            }),
          ),
        }),
      );
    }

    this.logger = winston.createLogger({
      level: logLevel,
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
        winston.format.metadata({
          fillExcept: ['message', 'level', 'timestamp'],
        }),
      ),
      defaultMeta: {
        service: serviceName,
        version: '1.0.0',
        environment: nodeEnv,
      },
      transports,
    });
  }

  log(message: string, context?: string, meta?: any) {
    this.logger.info(message, { context, ...meta });
  }

  error(message: string, trace?: string, context?: string, meta?: any) {
    this.logger.error(message, { trace, context, ...meta });
  }

  warn(message: string, context?: string, meta?: any) {
    this.logger.warn(message, { context, ...meta });
  }

  debug(message: string, context?: string, meta?: any) {
    this.logger.debug(message, { context, ...meta });
  }

  verbose(message: string, context?: string, meta?: any) {
    this.logger.verbose(message, { context, ...meta });
  }

  // Structured logging methods for different types of events
  logHttpRequest(method: string, url: string, statusCode: number, responseTime: number, userId?: string) {
    this.logger.info('HTTP Request', {
      eventType: 'http_request',
      method,
      url,
      statusCode,
      responseTime,
      userId,
    });
  }

  logBusinessEvent(event: string, details: any, userId?: string) {
    this.logger.info('Business Event', {
      eventType: 'business_event',
      event,
      details,
      userId,
    });
  }

  logPerformanceMetric(metric: string, value: number, unit: string) {
    this.logger.info('Performance Metric', {
      eventType: 'performance_metric',
      metric,
      value,
      unit,
    });
  }

  logSecurityEvent(event: string, details: any, severity: 'low' | 'medium' | 'high' | 'critical' = 'medium') {
    this.logger.warn('Security Event', {
      eventType: 'security_event',
      event,
      details,
      severity,
    });
  }
}
