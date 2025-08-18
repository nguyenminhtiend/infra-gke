import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Delete,
  Put,
  Logger,
} from "@nestjs/common";
import { ApiTags, ApiOperation, ApiResponse, ApiParam } from "@nestjs/swagger";
import { UsersService } from "./users.service";
import { CreateUserDto, UpdateUserDto, UserResponseDto } from "./dto/user.dto";

@ApiTags("users")
@Controller("users")
export class UsersController {
  private readonly logger = new Logger(UsersController.name);

  constructor(private readonly usersService: UsersService) {}

  @Post()
  @ApiOperation({ summary: "Create a new user" })
  @ApiResponse({
    status: 201,
    description: "User created successfully.",
    type: UserResponseDto,
  })
  create(@Body() createUserDto: CreateUserDto): UserResponseDto {
    this.logger.log(`Creating user: ${createUserDto.email}`);
    return this.usersService.create(createUserDto);
  }

  @Get()
  @ApiOperation({ summary: "Get all users" })
  @ApiResponse({
    status: 200,
    description: "Users retrieved successfully.",
    type: [UserResponseDto],
  })
  findAll(): UserResponseDto[] {
    this.logger.log("Retrieving all users");
    return this.usersService.findAll();
  }

  @Get(":id")
  @ApiOperation({ summary: "Get user by ID" })
  @ApiParam({ name: "id", description: "User ID" })
  @ApiResponse({
    status: 200,
    description: "User retrieved successfully.",
    type: UserResponseDto,
  })
  findOne(@Param("id") id: string): UserResponseDto {
    this.logger.log(`Retrieving user with ID: ${id}`);
    return this.usersService.findOne(id);
  }

  @Put(":id")
  @ApiOperation({ summary: "Update user by ID" })
  @ApiParam({ name: "id", description: "User ID" })
  @ApiResponse({
    status: 200,
    description: "User updated successfully.",
    type: UserResponseDto,
  })
  update(
    @Param("id") id: string,
    @Body() updateUserDto: UpdateUserDto,
  ): UserResponseDto {
    this.logger.log(`Updating user with ID: ${id}`);
    return this.usersService.update(id, updateUserDto);
  }

  @Delete(":id")
  @ApiOperation({ summary: "Delete user by ID" })
  @ApiParam({ name: "id", description: "User ID" })
  @ApiResponse({ status: 200, description: "User deleted successfully." })
  remove(@Param("id") id: string): { message: string } {
    this.logger.log(`Deleting user with ID: ${id}`);
    this.usersService.remove(id);
    return { message: `User with ID ${id} deleted successfully` };
  }
}
