import { Injectable } from "@nestjs/common";
import {
  HealthIndicator,
  HealthIndicatorResult,
  HealthCheckError,
} from "@nestjs/terminus";

@Injectable()
export class HealthService extends HealthIndicator {
  async checkApplication(key: string): Promise<HealthIndicatorResult> {
    const isHealthy = true; // Add your application-specific health checks here

    const result = this.getStatus(key, isHealthy, {
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
      version: "1.0.0",
    });

    if (isHealthy) {
      return result;
    }

    throw new HealthCheckError("Application health check failed", result);
  }
}
