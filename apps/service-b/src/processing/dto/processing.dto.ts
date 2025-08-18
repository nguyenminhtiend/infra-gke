import { ApiProperty } from '@nestjs/swagger';
import { IsArray, IsString, IsOptional, IsEnum, IsNumber, Min, Max } from 'class-validator';

export enum ProcessingType {
  TRANSFORM = 'transform',
  VALIDATE = 'validate',
  AGGREGATE = 'aggregate',
  FILTER = 'filter',
}

export class ProcessDataDto {
  @ApiProperty({ description: 'Type of processing to perform', enum: ProcessingType })
  @IsEnum(ProcessingType)
  type: ProcessingType;

  @ApiProperty({ description: 'Array of data items to process' })
  @IsArray()
  data: any[];

  @ApiProperty({ description: 'Processing options', required: false })
  @IsOptional()
  options?: Record<string, any>;

  @ApiProperty({ description: 'Priority level (1-5)', minimum: 1, maximum: 5, required: false })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(5)
  priority?: number;
}

export class ProcessingJobDto {
  @ApiProperty({ description: 'Job ID' })
  @IsString()
  id: string;

  @ApiProperty({ description: 'Job status' })
  @IsString()
  status: string;

  @ApiProperty({ description: 'Processing type' })
  type: ProcessingType;

  @ApiProperty({ description: 'Number of items processed' })
  @IsNumber()
  itemsProcessed: number;

  @ApiProperty({ description: 'Total number of items' })
  @IsNumber()
  totalItems: number;

  @ApiProperty({ description: 'Job creation timestamp' })
  createdAt: Date;

  @ApiProperty({ description: 'Job completion timestamp', required: false })
  @IsOptional()
  completedAt?: Date;

  @ApiProperty({ description: 'Processing result', required: false })
  @IsOptional()
  result?: any;

  @ApiProperty({ description: 'Error message if failed', required: false })
  @IsOptional()
  error?: string;
}
