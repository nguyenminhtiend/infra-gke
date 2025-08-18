import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Logger } from '../common/logger/logger.service';
import { ProcessDataDto, ProcessingJobDto, ProcessingType } from './dto/processing.dto';

@Injectable()
export class ProcessingService {
  private jobs: Map<string, ProcessingJobDto> = new Map();
  private stats = {
    totalJobs: 0,
    completedJobs: 0,
    failedJobs: 0,
    averageProcessingTime: 0,
  };

  constructor(
    private readonly configService: ConfigService,
    private readonly logger: Logger,
  ) {}

  async processBatch(data: ProcessDataDto): Promise<{ jobId: string; status: string }> {
    const jobId = this.generateJobId();
    const batchSize = this.configService.get('BATCH_SIZE') || 100;
    const maxProcessingTime = this.configService.get('MAX_PROCESSING_TIME') || 30000;

    const job: ProcessingJobDto = {
      id: jobId,
      status: 'processing',
      type: data.type,
      itemsProcessed: 0,
      totalItems: data.data.length,
      createdAt: new Date(),
    };

    this.jobs.set(jobId, job);
    this.stats.totalJobs++;

    this.logger.logProcessingEvent('batch_started', {
      jobId,
      type: data.type,
      totalItems: data.data.length,
      batchSize,
      priority: data.priority || 3,
    });

    // Process in background
    this.processInBackground(jobId, data, batchSize, maxProcessingTime);

    return {
      jobId,
      status: 'accepted',
    };
  }

  private async processInBackground(
    jobId: string,
    data: ProcessDataDto,
    batchSize: number,
    maxProcessingTime: number,
  ): Promise<void> {
    const startTime = Date.now();
    const job = this.jobs.get(jobId);
    if (!job) return;

    try {
      const chunks = this.chunkArray(data.data, batchSize);
      const results: any[] = [];

      for (const [index, chunk] of chunks.entries()) {
        // Check timeout
        if (Date.now() - startTime > maxProcessingTime) {
          throw new Error('Processing timeout exceeded');
        }

        const chunkResult = await this.processChunk(chunk, data.type, data.options);
        results.push(...chunkResult);

        // Update progress
        job.itemsProcessed = Math.min((index + 1) * batchSize, data.data.length);
        this.jobs.set(jobId, job);

        this.logger.logProcessingEvent('chunk_processed', {
          jobId,
          chunkIndex: index,
          chunkSize: chunk.length,
          progress: (job.itemsProcessed / job.totalItems) * 100,
        });
      }

      // Job completed successfully
      job.status = 'completed';
      job.completedAt = new Date();
      job.result = results;
      this.jobs.set(jobId, job);
      this.stats.completedJobs++;

      const processingTime = Date.now() - startTime;
      this.updateAverageProcessingTime(processingTime);

      this.logger.logProcessingEvent('batch_completed', {
        jobId,
        totalItems: job.totalItems,
        processingTime,
        throughput: job.totalItems / (processingTime / 1000),
      });
    } catch (error) {
      // Job failed
      job.status = 'failed';
      job.completedAt = new Date();
      job.error = error.message;
      this.jobs.set(jobId, job);
      this.stats.failedJobs++;

      this.logger.error('Processing job failed', error.stack, 'ProcessingService', {
        jobId,
        error: error.message,
      });
    }
  }

  private async processChunk(chunk: any[], type: ProcessingType, options?: Record<string, any>): Promise<any[]> {
    // Simulate processing time
    await this.sleep(100);

    switch (type) {
      case ProcessingType.TRANSFORM:
        return chunk.map(item => this.transformItem(item, options));
      case ProcessingType.VALIDATE:
        return chunk.filter(item => this.validateItem(item, options));
      case ProcessingType.AGGREGATE:
        return [this.aggregateItems(chunk, options)];
      case ProcessingType.FILTER:
        return chunk.filter(item => this.filterItem(item, options));
      default:
        return chunk;
    }
  }

  private transformItem(item: any, options?: Record<string, any>): any {
    // Simple transformation example
    return {
      ...item,
      processed: true,
      processedAt: new Date().toISOString(),
      transformedBy: 'service-b',
      ...(options?.additionalFields || {}),
    };
  }

  private validateItem(item: any, options?: Record<string, any>): boolean {
    // Simple validation example
    const requiredFields = options?.requiredFields || ['id'];
    return requiredFields.every(field => item[field] !== undefined);
  }

  private aggregateItems(items: any[], options?: Record<string, any>): any {
    // Simple aggregation example
    const field = options?.field || 'value';
    const operation = options?.operation || 'sum';

    const values = items.map(item => item[field]).filter(val => typeof val === 'number');

    switch (operation) {
      case 'sum':
        return { [field]: values.reduce((sum, val) => sum + val, 0) };
      case 'avg':
        return { [field]: values.reduce((sum, val) => sum + val, 0) / values.length };
      case 'max':
        return { [field]: Math.max(...values) };
      case 'min':
        return { [field]: Math.min(...values) };
      default:
        return { [field]: values.length };
    }
  }

  private filterItem(item: any, options?: Record<string, any>): boolean {
    // Simple filter example
    const conditions = options?.conditions || {};
    return Object.entries(conditions).every(([key, value]) => item[key] === value);
  }

  getJobs(): ProcessingJobDto[] {
    return Array.from(this.jobs.values()).sort((a, b) =>
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }

  getJob(id: string): ProcessingJobDto | undefined {
    return this.jobs.get(id);
  }

  getStats() {
    return {
      ...this.stats,
      activeJobs: Array.from(this.jobs.values()).filter(job => job.status === 'processing').length,
      totalJobsInMemory: this.jobs.size,
    };
  }

  private generateJobId(): string {
    return `job_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private chunkArray<T>(array: T[], size: number): T[][] {
    const chunks: T[][] = [];
    for (let i = 0; i < array.length; i += size) {
      chunks.push(array.slice(i, i + size));
    }
    return chunks;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  private updateAverageProcessingTime(processingTime: number): void {
    const totalCompletedJobs = this.stats.completedJobs;
    this.stats.averageProcessingTime =
      (this.stats.averageProcessingTime * (totalCompletedJobs - 1) + processingTime) / totalCompletedJobs;
  }
}
