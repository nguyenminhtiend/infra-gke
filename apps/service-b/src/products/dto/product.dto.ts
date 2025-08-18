import { IsString, IsNumber, Min } from 'class-validator';
import { ApiProperty, PartialType } from '@nestjs/swagger';

export class CreateProductDto {
  @ApiProperty({ example: 'Wireless Headphones', description: 'Product name' })
  @IsString()
  name: string;

  @ApiProperty({
    example: 'High-quality wireless Bluetooth headphones',
    description: 'Product description'
  })
  @IsString()
  description: string;

  @ApiProperty({ example: 299.99, description: 'Product price' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  price: number;

  @ApiProperty({ example: 'electronics', description: 'Product category' })
  @IsString()
  category: string;

  @ApiProperty({ example: 50, description: 'Stock quantity' })
  @IsNumber()
  @Min(0)
  stock: number;

  @ApiProperty({ example: 'WH-001', description: 'Product SKU' })
  @IsString()
  sku: string;
}

export class UpdateProductDto extends PartialType(CreateProductDto) {}

export class ProductResponseDto {
  @ApiProperty({ example: '1', description: 'Unique product identifier' })
  id: string;

  @ApiProperty({ example: 'Wireless Headphones', description: 'Product name' })
  name: string;

  @ApiProperty({
    example: 'High-quality wireless Bluetooth headphones',
    description: 'Product description'
  })
  description: string;

  @ApiProperty({ example: 299.99, description: 'Product price' })
  price: number;

  @ApiProperty({ example: 'electronics', description: 'Product category' })
  category: string;

  @ApiProperty({ example: 50, description: 'Stock quantity' })
  stock: number;

  @ApiProperty({ example: 'WH-001', description: 'Product SKU' })
  sku: string;

  @ApiProperty({
    example: '2024-01-01T00:00:00.000Z',
    description: 'Product creation timestamp'
  })
  createdAt: Date;

  @ApiProperty({
    example: '2024-01-01T00:00:00.000Z',
    description: 'Product last update timestamp'
  })
  updatedAt: Date;
}
