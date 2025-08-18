import { Injectable, NotFoundException, Logger } from "@nestjs/common";
import {
  CreateProductDto,
  UpdateProductDto,
  ProductResponseDto,
} from "./dto/product.dto";

@Injectable()
export class ProductsService {
  private readonly logger = new Logger(ProductsService.name);
  private products: ProductResponseDto[] = [
    {
      id: "1",
      name: "Wireless Headphones",
      description:
        "High-quality wireless Bluetooth headphones with noise cancellation",
      price: 299.99,
      category: "electronics",
      stock: 50,
      sku: "WH-001",
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: "2",
      name: "Smart Watch",
      description:
        "Advanced fitness tracking smartwatch with heart rate monitor",
      price: 199.99,
      category: "electronics",
      stock: 30,
      sku: "SW-002",
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    {
      id: "3",
      name: "Coffee Maker",
      description: "Programmable drip coffee maker with thermal carafe",
      price: 89.99,
      category: "appliances",
      stock: 25,
      sku: "CM-003",
      createdAt: new Date(),
      updatedAt: new Date(),
    },
  ];

  create(createProductDto: CreateProductDto): ProductResponseDto {
    const product: ProductResponseDto = {
      id: Date.now().toString(),
      ...createProductDto,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    this.products.push(product);
    this.logger.log(`Product created with ID: ${product.id}`);
    return product;
  }

  findAll(category?: string): ProductResponseDto[] {
    let filteredProducts = this.products;

    if (category) {
      filteredProducts = this.products.filter(
        (p) => p.category.toLowerCase() === category.toLowerCase(),
      );
    }

    this.logger.log(
      `Retrieved ${filteredProducts.length} products${category ? ` in category: ${category}` : ""}`,
    );
    return filteredProducts;
  }

  findOne(id: string): ProductResponseDto {
    const product = this.products.find((p) => p.id === id);
    if (!product) {
      this.logger.warn(`Product with ID ${id} not found`);
      throw new NotFoundException(`Product with ID ${id} not found`);
    }
    return product;
  }

  findByCategory(category: string): ProductResponseDto[] {
    const products = this.products.filter(
      (p) => p.category.toLowerCase() === category.toLowerCase(),
    );
    this.logger.log(
      `Retrieved ${products.length} products in category: ${category}`,
    );
    return products;
  }

  update(id: string, updateProductDto: UpdateProductDto): ProductResponseDto {
    const productIndex = this.products.findIndex((p) => p.id === id);
    if (productIndex === -1) {
      this.logger.warn(`Product with ID ${id} not found for update`);
      throw new NotFoundException(`Product with ID ${id} not found`);
    }

    this.products[productIndex] = {
      ...this.products[productIndex],
      ...updateProductDto,
      updatedAt: new Date(),
    };

    this.logger.log(`Product with ID ${id} updated`);
    return this.products[productIndex];
  }

  remove(id: string): void {
    const productIndex = this.products.findIndex((p) => p.id === id);
    if (productIndex === -1) {
      this.logger.warn(`Product with ID ${id} not found for deletion`);
      throw new NotFoundException(`Product with ID ${id} not found`);
    }

    this.products.splice(productIndex, 1);
    this.logger.log(`Product with ID ${id} deleted`);
  }
}
