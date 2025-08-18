import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

@Injectable()
export class AppService {
  private readonly logger = new Logger(AppService.name);

  constructor(private configService: ConfigService) {
    this.logger.log("AppService initialized");
  }

  getServiceInfo(): { name: string; version: string; description: string } {
    return {
      name: "Service B - Product Catalog",
      version: "1.0.0",
      description: "Product catalog service for the GKE infrastructure",
    };
  }
}
