import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import {
  CustomerAccountPaymentDto,
  CustomerDto,
} from './dto/customers.dto.js';
import { CustomersService } from './customers.service.js';

@Controller('customers')
@UseGuards(JwtAuthGuard)
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @Get()
  list(@CurrentUser() user: AccessTokenPayload) {
    return this.customersService.list(user);
  }

  @Post()
  create(@CurrentUser() user: AccessTokenPayload, @Body() dto: CustomerDto) {
    return this.customersService.create(user, dto);
  }

  @Put(':id')
  update(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: CustomerDto,
  ) {
    return this.customersService.update(user, id, dto);
  }

  @Delete(':id')
  archive(@CurrentUser() user: AccessTokenPayload, @Param('id') id: string) {
    return this.customersService.archive(user, id);
  }

  @Get(':id/statement')
  statement(@CurrentUser() user: AccessTokenPayload, @Param('id') id: string) {
    return this.customersService.statement(user, id);
  }

  @Post(':id/payments')
  recordPayment(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: CustomerAccountPaymentDto,
  ) {
    return this.customersService.recordPayment(user, id, dto);
  }
}
