import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import { ExchangeRateDto, ProductDto } from './dto/product.dto.js';
import { ProductsService } from './products.service.js';

@Controller('products')
@UseGuards(JwtAuthGuard)
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @Get()
  list(@CurrentUser() user: AccessTokenPayload) {
    return this.productsService.list(user);
  }

  @Post()
  create(@CurrentUser() user: AccessTokenPayload, @Body() dto: ProductDto) {
    return this.productsService.create(user, dto);
  }

  @Put(':id')
  update(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: ProductDto,
  ) {
    return this.productsService.update(user, id, dto);
  }

  @Delete(':id')
  archive(@CurrentUser() user: AccessTokenPayload, @Param('id') id: string) {
    return this.productsService.archive(user, id);
  }

  @Patch('exchange-rate')
  updateExchangeRate(
    @CurrentUser() user: AccessTokenPayload,
    @Body() dto: ExchangeRateDto,
  ) {
    return this.productsService.updateExchangeRate(user, dto);
  }
}
