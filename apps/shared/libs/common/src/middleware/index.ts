import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { generateCorrelationId } from '../utils';
import { HEADER_NAMES } from '../constants';

/**
 * Middleware to add correlation ID to requests
 */
@Injectable()
export class CorrelationIdMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const correlationId = req.headers[HEADER_NAMES.CORRELATION_ID] || generateCorrelationId();

    // Set correlation ID in request
    req.headers[HEADER_NAMES.CORRELATION_ID] = correlationId as string;

    // Set correlation ID in response headers
    res.setHeader(HEADER_NAMES.CORRELATION_ID, correlationId);

    next();
  }
}
