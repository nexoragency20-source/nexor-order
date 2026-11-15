import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import type { AccessTokenPayload } from '../interfaces/access-token-payload.interface.js';
import { PrismaService } from '../../prisma/prisma.service.js';

type AuthenticatedRequest = Request & { user?: AccessTokenPayload };

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authorization = request.headers.authorization;

    if (!authorization || Array.isArray(authorization)) {
      throw new UnauthorizedException('يجب تسجيل الدخول أولاً.');
    }

    const [scheme, token] = authorization.split(' ');
    if (scheme?.toLowerCase() !== 'bearer' || !token) {
      throw new UnauthorizedException('رمز الدخول غير صالح.');
    }

    let payload: AccessTokenPayload;
    try {
      payload = await this.jwtService.verifyAsync<AccessTokenPayload>(token);
    } catch {
      throw new UnauthorizedException('انتهت صلاحية الجلسة أو أن رمز الدخول غير صالح.');
    }

    if (!payload.sub || !payload.organizationId || !payload.storeId || !payload.role) {
      throw new UnauthorizedException('بيانات رمز الدخول غير مكتملة.');
    }

    const store = await this.prisma.store.findFirst({
      where: { id: payload.storeId, organizationId: payload.organizationId },
      select: { subscriptionRequired: true, isSuspended: true },
    });
    if (!store) throw new UnauthorizedException('المحل المرتبط بالجلسة غير موجود.');
    if (store.isSuspended) {
      throw new ForbiddenException('تم إيقاف هذا المحل مؤقتاً. يرجى التواصل مع إدارة NEXOR.');
    }
    if (store.subscriptionRequired) {
      const now = new Date();
      const activeSubscription = await this.prisma.storeSubscription.findFirst({
        where: {
          storeId: payload.storeId,
          status: 'ACTIVE',
          startsAt: { lte: now },
          endsAt: { gt: now },
        },
        select: { id: true },
      });
      if (!activeSubscription) {
        throw new ForbiddenException('انتهى اشتراك NEXOR أو لم يعد فعالاً. يرجى التواصل مع إدارة NEXOR للتجديد.');
      }
    }

    request.user = payload;
    return true;
  }
}
