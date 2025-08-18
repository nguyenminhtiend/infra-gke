import { Injectable, NotFoundException, Logger } from "@nestjs/common";
import { CreateUserDto, UpdateUserDto, UserResponseDto } from "./dto/user.dto";

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);
  private users: UserResponseDto[] = [
    {
      id: "1",
      email: "john.doe@example.com",
      name: "John Doe",
      role: "admin",
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: "2",
      email: "jane.smith@example.com",
      name: "Jane Smith",
      role: "user",
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  ];

  create(createUserDto: CreateUserDto): UserResponseDto {
    const user: UserResponseDto = {
      id: Date.now().toString(),
      ...createUserDto,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    this.users.push(user);
    this.logger.log(`User created with ID: ${user.id}`);
    return user;
  }

  findAll(): UserResponseDto[] {
    this.logger.log(`Retrieved ${this.users.length} users`);
    return this.users;
  }

  findOne(id: string): UserResponseDto {
    const user = this.users.find((u) => u.id === id);
    if (!user) {
      this.logger.warn(`User with ID ${id} not found`);
      throw new NotFoundException(`User with ID ${id} not found`);
    }
    return user;
  }

  update(id: string, updateUserDto: UpdateUserDto): UserResponseDto {
    const userIndex = this.users.findIndex((u) => u.id === id);
    if (userIndex === -1) {
      this.logger.warn(`User with ID ${id} not found for update`);
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    this.users[userIndex] = {
      ...this.users[userIndex],
      ...updateUserDto,
      updatedAt: new Date(),
    };

    this.logger.log(`User with ID ${id} updated`);
    return this.users[userIndex];
  }

  remove(id: string): void {
    const userIndex = this.users.findIndex((u) => u.id === id);
    if (userIndex === -1) {
      this.logger.warn(`User with ID ${id} not found for deletion`);
      throw new NotFoundException(`User with ID ${id} not found`);
    }

    this.users.splice(userIndex, 1);
    this.logger.log(`User with ID ${id} deleted`);
  }
}
