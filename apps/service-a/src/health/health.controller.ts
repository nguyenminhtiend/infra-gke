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
      // Memory check: fails if used memory exceeds 300MB
      () => this.memory.checkHeap('memory_heap', 300 * 1024 * 1024),
      // Memory check: fails if RSS memory exceeds 300MB
      () => this.memory.checkRSS('memory_rss', 300 * 1024 * 1024),
      // Disk check: fails if used disk space exceeds 90%
      () => this.disk.checkStorage('storage', {
        path: '/',
        thresholdPercent: 0.9
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
      () => this.memory.checkHeap('memory_heap', 500 * 1024 * 1024),
      // Add database connectivity check here when applicable
      // () => this.db.pingCheck('database'),
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
