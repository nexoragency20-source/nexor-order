import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import { DashboardService } from './dashboard.service.js';

@Controller('dashboard')
@UseGuards(JwtAuthGuard)
export class DashboardController {
  constructor(private readonly dashboardService: DashboardService) {}

  @Get('overview')
  overview(
    @CurrentUser() user: AccessTokenPayload,
    @Query('date') date?: string,
    @Query('utcOffsetMinutes') utcOffsetMinutes?: string,
  ) {
    return this.dashboardService.overview(user, date, utcOffsetMinutes);
  }
}
