import { IsEmail, IsString, IsIn } from 'class-validator';
import { ApiProperty, PartialType } from '@nestjs/swagger';

export class CreateUserDto {
  @ApiProperty({
    example: 'john.doe@example.com',
    description: 'User email address'
  })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'John Doe', description: 'Full name of the user' })
  @IsString()
  name: string;

  @ApiProperty({
    example: 'user',
    description: 'User role',
    enum: ['admin', 'user']
  })
  @IsString()
  @IsIn(['admin', 'user'])
  role: string;
}

export class UpdateUserDto extends PartialType(CreateUserDto) {}

export class UserResponseDto {
  @ApiProperty({ example: '1', description: 'Unique user identifier' })
  id: string;

  @ApiProperty({
    example: 'john.doe@example.com',
    description: 'User email address'
  })
  email: string;

  @ApiProperty({ example: 'John Doe', description: 'Full name of the user' })
  name: string;

  @ApiProperty({ example: 'user', description: 'User role' })
  role: string;

  @ApiProperty({
    example: '2024-01-01T00:00:00.000Z',
    description: 'User creation timestamp'
  })
  createdAt: Date;

  @ApiProperty({
    example: '2024-01-01T00:00:00.000Z',
    description: 'User last update timestamp'
  })
  updatedAt: Date;
}
