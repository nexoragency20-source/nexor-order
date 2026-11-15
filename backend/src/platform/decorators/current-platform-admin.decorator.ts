import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { Request } from 'express';

type PlatformAdminRequest = Request & { platformAdminId?: string };

export const CurrentPlatformAdmin = createParamDecorator(
  (_data: unknown, context: ExecutionContext): string => {
    const request = context.switchToHttp().getRequest<PlatformAdminRequest>();
    return request.platformAdminId ?? '';
  },
);
