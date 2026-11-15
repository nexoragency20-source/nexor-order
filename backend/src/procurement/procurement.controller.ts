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
  CreatePurchaseDto,
  SupplierDto,
  SupplierPaymentDto,
} from './dto/procurement.dto.js';
import { ProcurementService } from './procurement.service.js';

@Controller()
@UseGuards(JwtAuthGuard)
export class ProcurementController {
  constructor(private readonly procurementService: ProcurementService) {}

  @Get('suppliers')
  listSuppliers(@CurrentUser() user: AccessTokenPayload) {
    return this.procurementService.listSuppliers(user);
  }

  @Post('suppliers')
  createSupplier(@CurrentUser() user: AccessTokenPayload, @Body() dto: SupplierDto) {
    return this.procurementService.createSupplier(user, dto);
  }

  @Put('suppliers/:id')
  updateSupplier(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: SupplierDto,
  ) {
    return this.procurementService.updateSupplier(user, id, dto);
  }

  @Delete('suppliers/:id')
  archiveSupplier(@CurrentUser() user: AccessTokenPayload, @Param('id') id: string) {
    return this.procurementService.archiveSupplier(user, id);
  }

  @Post('suppliers/:id/payments')
  recordSupplierPayment(
    @CurrentUser() user: AccessTokenPayload,
    @Param('id') id: string,
    @Body() dto: SupplierPaymentDto,
  ) {
    return this.procurementService.recordSupplierPayment(user, id, dto);
  }

  @Get('supplier-payments')
  listSupplierPayments(@CurrentUser() user: AccessTokenPayload) {
    return this.procurementService.listSupplierPayments(user);
  }

  @Get('purchases')
  listPurchases(@CurrentUser() user: AccessTokenPayload) {
    return this.procurementService.listPurchases(user);
  }

  @Post('purchases')
  createPurchase(@CurrentUser() user: AccessTokenPayload, @Body() dto: CreatePurchaseDto) {
    return this.procurementService.createPurchase(user, dto);
  }
}
