import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import {
  HealthCheck,
  HealthCheckService,
  HttpHealthIndicator,
  MemoryHealthIndicator,
  DiskHealthIndicator,
} from '@nestjs/terminus';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private http: HttpHealthIndicator,
    private memory: MemoryHealthIndicator,
    private disk: DiskHealthIndicator,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Health check endpoint' })
  @ApiResponse({ status: 200, description: 'Service is healthy' })
  @ApiResponse({ status: 503, description: 'Service is unhealthy' })
  @HealthCheck()
  check() {
    return this.health.check([
      // Memory check: fails if used memory exceeds 400MB (higher for processing service)
      () => this.memory.checkHeap('memory_heap', 400 * 1024 * 1024),
      // Memory check: fails if RSS memory exceeds 400MB
      () => this.memory.checkRSS('memory_rss', 400 * 1024 * 1024),
      // Disk check: fails if used disk space exceeds 85%
      () => this.disk.checkStorage('storage', {
        path: '/',
        thresholdPercent: 0.85
      }),
    ]);
  }

  @Get('ready')
  @ApiOperation({ summary: 'Readiness check endpoint' })
  @ApiResponse({ status: 200, description: 'Service is ready' })
  @ApiResponse({ status: 503, description: 'Service is not ready' })
  @HealthCheck()
  readiness() {
    return this.health.check([
      // Basic memory check for readiness
      () => this.memory.checkHeap('memory_heap', 600 * 1024 * 1024),
      // Add database connectivity check here when applicable
      // () => this.db.pingCheck('database'),
      // Add external service dependency checks
      // () => this.http.pingCheck('service-a', 'http://service-a/api/v1/health/live'),
    ]);
  }

  @Get('live')
  @ApiOperation({ summary: 'Liveness check endpoint' })
  @ApiResponse({ status: 200, description: 'Service is alive' })
  @HealthCheck()
  liveness() {
    // Simple liveness check - just return OK if the process is running
    return this.health.check([]);
  }
}
