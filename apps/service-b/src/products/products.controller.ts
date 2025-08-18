import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Delete,
  Put,
  Logger,
  Query,
} from "@nestjs/common";
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiQuery,
} from "@nestjs/swagger";
import { ProductsService } from "./products.service";
import {
  CreateProductDto,
  UpdateProductDto,
  ProductResponseDto,
} from "./dto/product.dto";

@ApiTags("products")
@Controller("products")
export class ProductsController {
  private readonly logger = new Logger(ProductsController.name);

  constructor(private readonly productsService: ProductsService) {}

  @Post()
  @ApiOperation({ summary: "Create a new product" })
  @ApiResponse({
    status: 201,
    description: "Product created successfully.",
    type: ProductResponseDto,
  })
  create(@Body() createProductDto: CreateProductDto): ProductResponseDto {
    this.logger.log(`Creating product: ${createProductDto.name}`);
    return this.productsService.create(createProductDto);
  }

  @Get()
  @ApiOperation({ summary: "Get all products" })
  @ApiQuery({
    name: "category",
    required: false,
    description: "Filter by category",
  })
  @ApiResponse({
    status: 200,
    description: "Products retrieved successfully.",
    type: [ProductResponseDto],
  })
  findAll(@Query("category") category?: string): ProductResponseDto[] {
    this.logger.log(
      `Retrieving products${category ? ` in category: ${category}` : ""}`,
    );
    return this.productsService.findAll(category);
  }

  @Get(":id")
  @ApiOperation({ summary: "Get product by ID" })
  @ApiParam({ name: "id", description: "Product ID" })
  @ApiResponse({
    status: 200,
    description: "Product retrieved successfully.",
    type: ProductResponseDto,
  })
  findOne(@Param("id") id: string): ProductResponseDto {
    this.logger.log(`Retrieving product with ID: ${id}`);
    return this.productsService.findOne(id);
  }

  @Put(":id")
  @ApiOperation({ summary: "Update product by ID" })
  @ApiParam({ name: "id", description: "Product ID" })
  @ApiResponse({
    status: 200,
    description: "Product updated successfully.",
    type: ProductResponseDto,
  })
  update(
    @Param("id") id: string,
    @Body() updateProductDto: UpdateProductDto,
  ): ProductResponseDto {
    this.logger.log(`Updating product with ID: ${id}`);
    return this.productsService.update(id, updateProductDto);
  }

  @Delete(":id")
  @ApiOperation({ summary: "Delete product by ID" })
  @ApiParam({ name: "id", description: "Product ID" })
  @ApiResponse({ status: 200, description: "Product deleted successfully." })
  remove(@Param("id") id: string): { message: string } {
    this.logger.log(`Deleting product with ID: ${id}`);
    this.productsService.remove(id);
    return { message: `Product with ID ${id} deleted successfully` };
  }

  @Get("category/:category")
  @ApiOperation({ summary: "Get products by category" })
  @ApiParam({ name: "category", description: "Product category" })
  @ApiResponse({
    status: 200,
    description: "Products in category retrieved successfully.",
    type: [ProductResponseDto],
  })
  findByCategory(@Param("category") category: string): ProductResponseDto[] {
    this.logger.log(`Retrieving products in category: ${category}`);
    return this.productsService.findByCategory(category);
  }
}
