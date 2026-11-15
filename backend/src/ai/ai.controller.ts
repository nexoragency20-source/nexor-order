import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import { AiChatDto } from './dto/ai-chat.dto.js';
import { AiService } from './ai.service.js';

@Controller('ai')
@UseGuards(JwtAuthGuard)
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Get('status')
  status() {
    return this.aiService.status();
  }

  @Post('chat')
  chat(@CurrentUser() user: AccessTokenPayload, @Body() dto: AiChatDto) {
    return this.aiService.chat(user, dto);
  }
}
