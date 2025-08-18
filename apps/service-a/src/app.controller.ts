import { Controller, Get } from "@nestjs/common";
import { ApiTags, ApiOperation, ApiResponse } from "@nestjs/swagger";
import { AppService } from "./app.service";

@ApiTags("app")
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  @ApiOperation({ summary: "Get service information" })
  @ApiResponse({
    status: 200,
    description: "Service information retrieved successfully.",
  })
  getServiceInfo(): { name: string; version: string; description: string } {
    return this.appService.getServiceInfo();
  }
}
