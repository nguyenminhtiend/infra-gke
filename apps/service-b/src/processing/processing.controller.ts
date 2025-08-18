import { Controller, Post, Body, Get, Param } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBody } from '@nestjs/swagger';
import { ProcessingService } from './processing.service';
import { ProcessDataDto, ProcessingJobDto } from './dto/processing.dto';

@ApiTags('processing')
@Controller('processing')
export class ProcessingController {
  constructor(private readonly processingService: ProcessingService) {}

  @Post('batch')
  @ApiOperation({ summary: 'Process data in batch' })
  @ApiResponse({ status: 201, description: 'Batch processing started' })
  @ApiBody({ type: ProcessDataDto })
  async processBatch(@Body() data: ProcessDataDto) {
    return this.processingService.processBatch(data);
  }

  @Get('jobs')
  @ApiOperation({ summary: 'Get all processing jobs' })
  @ApiResponse({ status: 200, description: 'List of processing jobs' })
  async getJobs() {
    return this.processingService.getJobs();
  }

  @Get('jobs/:id')
  @ApiOperation({ summary: 'Get processing job by ID' })
  @ApiResponse({ status: 200, description: 'Processing job details' })
  async getJob(@Param('id') id: string) {
    return this.processingService.getJob(id);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Get processing statistics' })
  @ApiResponse({ status: 200, description: 'Processing statistics' })
  async getStats() {
    return this.processingService.getStats();
  }
}
