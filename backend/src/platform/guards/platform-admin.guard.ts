import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service.js';

type PlatformAdminRequest = Request & { platformAdminId?: string };

@Injectable()
export class PlatformAdminGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<PlatformAdminRequest>();
    const authorization = request.headers.authorization;
    if (!authorization || Array.isArray(authorization)) {
      throw new UnauthorizedException('يجب تسجيل الدخول إلى إدارة NEXOR.');
    }

    const [scheme, token] = authorization.split(' ');
    if (scheme?.toLowerCase() !== 'bearer' || !token) {
      throw new UnauthorizedException('رمز دخول إدارة NEXOR غير صالح.');
    }

    let payload: { sub?: string; tokenType?: string };
    try {
      payload = await this.jwtService.verifyAsync(token);
    } catch {
      throw new UnauthorizedException('انتهت جلسة إدارة NEXOR. سجّل الدخول مجدداً.');
    }

    if (!payload.sub || payload.tokenType !== 'platform_admin') {
      throw new ForbiddenException('هذه الصفحة مخصصة لإدارة NEXOR فقط.');
    }

    const admin = await this.prisma.platformAdmin.findFirst({
      where: { id: payload.sub, isActive: true },
      select: { id: true },
    });
    if (!admin) {
      throw new UnauthorizedException('حساب إدارة NEXOR غير فعال.');
    }

    request.platformAdminId = admin.id;
    return true;
  }
}
