import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AppService {
  constructor(private readonly configService: ConfigService) {}

  getServiceInfo() {
    return {
      service: 'service-b',
      version: '1.0.0',
      description: 'Data processing service',
      environment: this.configService.get('NODE_ENV'),
      timestamp: new Date().toISOString(),
      capabilities: [
        'data-processing',
        'batch-operations',
        'file-transformation',
      ],
    };
  }
}
