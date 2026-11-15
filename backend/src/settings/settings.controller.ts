import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import { UpdateStoreSettingsDto } from './dto/settings.dto.js';
import { SettingsService } from './settings.service.js';

@Controller('settings')
@UseGuards(JwtAuthGuard)
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get('store')
  getStoreSettings(@CurrentUser() user: AccessTokenPayload) {
    return this.settingsService.getStoreSettings(user);
  }

  @Patch('store')
  updateStoreSettings(
    @CurrentUser() user: AccessTokenPayload,
    @Body() dto: UpdateStoreSettingsDto,
  ) {
    return this.settingsService.updateStoreSettings(user, dto);
  }
}
