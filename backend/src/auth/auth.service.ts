import {
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { compare, hash } from 'bcryptjs';
import { createHash } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import type { RegisterDto } from './dto/register.dto.js';
import type { LoginDto } from './dto/login.dto.js';
import type { AccessTokenPayload } from './interfaces/access-token-payload.interface.js';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();
    const existingUser = await this.prisma.user.findUnique({
      where: { email },
      select: { id: true },
    });
    if (existingUser) {
      throw new ConflictException('هذا البريد الإلكتروني مسجل مسبقاً.');
    }

    const normalizedCode = dto.activationCode.trim().toUpperCase().replace(/\s+/g, '');
    const codeHash = createHash('sha256').update(normalizedCode).digest('hex');
    const passwordHash = await hash(dto.password, 12);
    const now = new Date();

    try {
      const result = await this.prisma.$transaction(async (tx) => {
        const activationCode = await tx.activationCode.findUnique({
          where: { codeHash },
          include: {
            store: { include: { organization: true } },
            subscription: true,
          },
        });

        if (!activationCode || activationCode.status !== 'AVAILABLE') {
          throw new ForbiddenException('كود التفعيل غير صحيح أو تم استخدامه مسبقاً.');
        }
        if (activationCode.expiresAt && activationCode.expiresAt <= now) {
          throw new ForbiddenException('انتهت صلاحية كود التفعيل. تواصل مع NEXOR للحصول على كود جديد.');
        }
        if (!activationCode.store.subscriptionRequired || activationCode.store.isSuspended) {
          throw new ForbiddenException('هذا المحل غير متاح للتفعيل حالياً. تواصل مع إدارة NEXOR.');
        }
        if (activationCode.subscription.storeId !== activationCode.storeId) {
          throw new ForbiddenException('كود التفعيل غير مرتبط باشتراك المحل بشكل صحيح.');
        }
        if (activationCode.store.ownerActivatedAt) {
          throw new ConflictException('تم إنشاء حساب هذا المحل مسبقاً.');
        }
        if (activationCode.subscription.status !== 'PENDING') {
          throw new ForbiddenException('الاشتراك المرتبط بالكود غير جاهز للتفعيل.');
        }

        // Atomically claim the one-time code so concurrent sign-ups cannot reuse it.
        const claimed = await tx.activationCode.updateMany({
          where: { id: activationCode.id, status: 'AVAILABLE' },
          data: { status: 'USED', usedAt: now },
        });
        if (claimed.count !== 1) {
          throw new ConflictException('تم استخدام كود التفعيل في طلب آخر.');
        }

        const user = await tx.user.create({
          data: {
            email,
            fullName: dto.fullName.trim(),
            passwordHash,
          },
          select: { id: true, email: true, fullName: true },
        });

        await tx.membership.create({
          data: {
            organizationId: activationCode.store.organizationId,
            userId: user.id,
            role: 'OWNER',
          },
        });

        const endsAt = this.calculateSubscriptionEnd(
          now,
          activationCode.subscription.durationMonths,
          activationCode.subscription.durationDays,
        );

        const subscription = await tx.storeSubscription.update({
          where: { id: activationCode.subscriptionId },
          data: {
            status: 'ACTIVE',
            startsAt: now,
            endsAt,
            activatedAt: now,
          },
        });

        const store = await tx.store.update({
          where: { id: activationCode.storeId },
          data: { ownerActivatedAt: now },
        });

        await tx.activationCode.update({
          where: { id: activationCode.id },
          data: { usedByUserId: user.id },
        });

        await tx.platformAuditLog.create({
          data: {
            storeId: store.id,
            actorType: 'STORE_OWNER',
            actorId: user.id,
            action: 'ACTIVATION_CODE_REDEEMED',
            details: {
              activationCodeId: activationCode.id,
              subscriptionId: subscription.id,
              startsAt: now.toISOString(),
              endsAt: endsAt.toISOString(),
            },
          },
        });

        return {
          user,
          organization: activationCode.store.organization,
          store,
          role: 'OWNER',
        };
      });

      return this.createSession(result);
    } catch (error) {
      if (
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('هذا البريد الإلكتروني مسجل مسبقاً.');
      }
      throw error;
    }
  }

  async login(dto: LoginDto) {
    const email = dto.email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: {
        memberships: {
          include: {
            organization: {
              include: {
                stores: { orderBy: { createdAt: 'asc' } },
              },
            },
          },
        },
      },
    });

    if (!user || !user.isActive || !(await compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('البريد الإلكتروني أو كلمة المرور غير صحيحة.');
    }

    const membership = user.memberships.find(
      (item) => item.organization.stores.length > 0,
    );
    const store = membership?.organization.stores[0];

    if (!membership || !store) {
      throw new UnauthorizedException('الحساب غير مرتبط بمتجر فعال.');
    }
    await this.assertStoreAccess(store.id);

    return this.createSession({
      user: { id: user.id, email: user.email, fullName: user.fullName },
      organization: membership.organization,
      store,
      role: membership.role,
    });
  }

  async me(payload: AccessTokenPayload) {
    const [user, organization, store, membership] = await Promise.all([
      this.prisma.user.findFirst({
        where: {
          id: payload.sub,
          isActive: true,
          memberships: { some: { organizationId: payload.organizationId } },
        },
        select: { id: true, email: true, fullName: true },
      }),
      this.prisma.organization.findUnique({
        where: { id: payload.organizationId },
        select: { id: true, name: true, slug: true },
      }),
      this.prisma.store.findFirst({
        where: { id: payload.storeId, organizationId: payload.organizationId },
        select: {
          id: true,
          name: true,
          defaultCurrency: true,
          exchangeRateSypPerUsd: true,
        },
      }),
      this.prisma.membership.findUnique({
        where: {
          organizationId_userId: {
            organizationId: payload.organizationId,
            userId: payload.sub,
          },
        },
        select: { role: true },
      }),
    ]);

    if (!user || !organization || !store || !membership) {
      throw new UnauthorizedException('لم تعد هذه الجلسة مرتبطة بمتجر فعال.');
    }
    await this.assertStoreAccess(store.id);

    return { user, organization, store, role: membership.role };
  }

  private async assertStoreAccess(storeId: string): Promise<void> {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { subscriptionRequired: true, isSuspended: true },
    });
    if (!store) throw new UnauthorizedException('المحل المرتبط بالحساب غير موجود.');
    if (store.isSuspended) {
      throw new ForbiddenException('تم إيقاف هذا المحل مؤقتاً. يرجى التواصل مع إدارة NEXOR.');
    }
    if (!store.subscriptionRequired) return; // Existing stores remain compatible until enrolled by NEXOR.

    const now = new Date();
    const activeSubscription = await this.prisma.storeSubscription.findFirst({
      where: {
        storeId,
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

  private calculateSubscriptionEnd(start: Date, months: number, days: number): Date {
    const result = new Date(start);
    if (months > 0) {
      const originalDay = result.getUTCDate();
      result.setUTCDate(1);
      result.setUTCMonth(result.getUTCMonth() + months);
      const lastDay = new Date(
        Date.UTC(result.getUTCFullYear(), result.getUTCMonth() + 1, 0),
      ).getUTCDate();
      result.setUTCDate(Math.min(originalDay, lastDay));
      return result;
    }
    result.setUTCDate(result.getUTCDate() + days);
    return result;
  }

  private async createSession(input: {
    user: { id: string; email: string; fullName: string };
    organization: { id: string; name: string; slug: string };
    store: {
      id: string;
      name: string;
      defaultCurrency?: string;
      exchangeRateSypPerUsd?: unknown;
    };
    role: string;
  }) {
    const payload: AccessTokenPayload = {
      sub: input.user.id,
      organizationId: input.organization.id,
      storeId: input.store.id,
      role: input.role,
    };

    const accessToken = await this.jwtService.signAsync(payload);
    return {
      accessToken,
      tokenType: 'Bearer',
      expiresIn: '12h',
      user: input.user,
      organization: input.organization,
      store: input.store,
      role: input.role,
    };
  }

}
