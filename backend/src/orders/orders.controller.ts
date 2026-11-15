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
import {
  CustomerPaymentDto,
  OrderDto,
  OrderStatusDto,
} from './dto/orders.dto.js';
import { OrdersService } from './orders.service.js';

@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Get('customers')
  listCustomers(@CurrentUser() user: AccessTokenPayload) {
    return this.ordersService.listCustomers(user);
  }

  @Get()
  list(@CurrentUser() user: AccessTokenPayload) {
    return this.ordersService.list(user);
  }

  @Post()
  create(@CurrentUser() user: AccessTokenPayload, @Body() dto: OrderDto) {
    return this.ordersService.create(user, dto);
  }

  @Put(':id')
  update(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: OrderDto,
  ) {
    return this.ordersService.update(user, id, dto);
  }

  @Patch(':id/status')
  updateStatus(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: OrderStatusDto,
  ) {
    return this.ordersService.updateStatus(user, id, dto.status);
  }

  @Post(':id/payments')
  recordPayment(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: CustomerPaymentDto,
  ) {
    return this.ordersService.recordPayment(user, id, dto);
  }

  @Delete(':id')
  cancel(@CurrentUser() user: AccessTokenPayload, @Param('id') id: string) {
    return this.ordersService.updateStatus(user, id, 'CANCELLED');
  }
}
