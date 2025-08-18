import { Controller, Get } from "@nestjs/common";
import { ApiTags, ApiOperation, ApiResponse } from "@nestjs/swagger";
import {
  HealthCheckService,
  HealthCheck,
  MemoryHealthIndicator,
  DiskHealthIndicator,
} from "@nestjs/terminus";
import { HealthService } from "./health.service";

@ApiTags("health")
@Controller("health")
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private memory: MemoryHealthIndicator,
    private disk: DiskHealthIndicator,
    private healthService: HealthService,
  ) {}

  @Get()
  @ApiOperation({ summary: "Basic health check" })
  @ApiResponse({ status: 200, description: "Service is healthy." })
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.memory.checkHeap("memory_heap", 150 * 1024 * 1024),
      () => this.memory.checkRSS("memory_rss", 150 * 1024 * 1024),
      () =>
        this.disk.checkStorage("storage", { path: "/", thresholdPercent: 0.9 }),
      () => this.healthService.checkApplication("app"),
    ]);
  }

  @Get("ready")
  @ApiOperation({ summary: "Readiness check" })
  @ApiResponse({ status: 200, description: "Service is ready." })
  @HealthCheck()
  readiness() {
    return this.health.check([
      () => this.healthService.checkApplication("app"),
    ]);
  }

  @Get("live")
  @ApiOperation({ summary: "Liveness check" })
  @ApiResponse({ status: 200, description: "Service is alive." })
  @HealthCheck()
  liveness() {
    return this.health.check([
      () => this.memory.checkHeap("memory_heap", 200 * 1024 * 1024),
    ]);
  }
}
