import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import { FinanceTransactionDto, FinanceTransferDto } from './dto/finance.dto.js';
import { FinanceService } from './finance.service.js';

@Controller('finance')
@UseGuards(JwtAuthGuard)
export class FinanceController {
  constructor(private readonly financeService: FinanceService) {}

  @Get('overview')
  overview(
    @CurrentUser() user: AccessTokenPayload,
    @Query('date') date?: string,
  ) {
    return this.financeService.overview(user, date);
  }

  @Post('transactions')
  createTransaction(
    @CurrentUser() user: AccessTokenPayload,
    @Body() dto: FinanceTransactionDto,
  ) {
    return this.financeService.createTransaction(user, dto);
  }

  @Post('transfers')
  createTransfer(
    @CurrentUser() user: AccessTokenPayload,
    @Body() dto: FinanceTransferDto,
  ) {
    return this.financeService.createTransfer(user, dto);
  }
}
