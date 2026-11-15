import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import {
  CreateSalesReturnDto,
  ReceiveSalesReturnDto,
  RejectSalesReturnDto,
} from './dto/returns.dto.js';
import { ReturnsService } from './returns.service.js';

@Controller('returns')
@UseGuards(JwtAuthGuard)
export class ReturnsController {
  constructor(private readonly returnsService: ReturnsService) {}

  @Get('eligible-orders')
  eligibleOrders(@CurrentUser() user: AccessTokenPayload) {
    return this.returnsService.eligibleOrders(user);
  }

  @Get()
  list(@CurrentUser() user: AccessTokenPayload) {
    return this.returnsService.list(user);
  }

  @Post()
  create(@CurrentUser() user: AccessTokenPayload, @Body() dto: CreateSalesReturnDto) {
    return this.returnsService.create(user, dto);
  }

  @Post(':id/receive')
  receive(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: ReceiveSalesReturnDto,
  ) {
    return this.returnsService.receive(user, id, dto);
  }

  @Post(':id/reject')
  reject(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: RejectSalesReturnDto,
  ) {
    return this.returnsService.reject(user, id, dto);
  }
}
