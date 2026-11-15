import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { PlatformService } from './platform.service.js';
import { PlatformAdminGuard } from './guards/platform-admin.guard.js';
import { CurrentPlatformAdmin } from './decorators/current-platform-admin.decorator.js';
import { PlatformLoginDto } from './dto/platform-login.dto.js';
import { CreateStoreDto } from './dto/create-store.dto.js';
import { RenewSubscriptionDto } from './dto/renew-subscription.dto.js';
import { SetStoreSuspensionDto } from './dto/set-store-suspension.dto.js';

@Controller('platform')
export class PlatformController {
  constructor(private readonly platform: PlatformService) {}

  @Post('auth/login')
  login(@Body() dto: PlatformLoginDto) {
    return this.platform.login(dto);
  }

  @UseGuards(PlatformAdminGuard)
  @Get('auth/me')
  me(@CurrentPlatformAdmin() adminId: string) {
    return this.platform.me(adminId);
  }

  @UseGuards(PlatformAdminGuard)
  @Get('dashboard')
  dashboard() {
    return this.platform.dashboard();
  }

  @UseGuards(PlatformAdminGuard)
  @Get('stores')
  stores() {
    return this.platform.stores();
  }

  @UseGuards(PlatformAdminGuard)
  @Post('stores')
  createStore(@Body() dto: CreateStoreDto, @CurrentPlatformAdmin() adminId: string) {
    return this.platform.createStore(dto, adminId);
  }

  @UseGuards(PlatformAdminGuard)
  @Post('stores/:storeId/enroll')
  enrollStore(
    @Param('storeId') storeId: string,
    @Body() dto: RenewSubscriptionDto,
    @CurrentPlatformAdmin() adminId: string,
  ) {
    return this.platform.enrollExistingStore(storeId, dto, adminId);
  }

  @UseGuards(PlatformAdminGuard)
  @Post('stores/:storeId/reissue-code')
  reissueCode(@Param('storeId') storeId: string, @CurrentPlatformAdmin() adminId: string) {
    return this.platform.reissueActivationCode(storeId, adminId);
  }

  @UseGuards(PlatformAdminGuard)
  @Post('stores/:storeId/renew')
  renewStore(
    @Param('storeId') storeId: string,
    @Body() dto: RenewSubscriptionDto,
    @CurrentPlatformAdmin() adminId: string,
  ) {
    return this.platform.renewStore(storeId, dto, adminId);
  }

  @UseGuards(PlatformAdminGuard)
  @Patch('stores/:storeId/suspension')
  setSuspension(
    @Param('storeId') storeId: string,
    @Body() dto: SetStoreSuspensionDto,
    @CurrentPlatformAdmin() adminId: string,
  ) {
    return this.platform.setSuspension(storeId, dto.isSuspended, adminId);
  }

  @UseGuards(PlatformAdminGuard)
  @Get('audit-logs')
  auditLogs(@Query('limit') limit?: string) {
    return this.platform.auditLogs(Number(limit ?? 50));
  }
}
