import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { compare } from 'bcryptjs';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import type { PlatformLoginDto } from './dto/platform-login.dto.js';
import type { CreateStoreDto } from './dto/create-store.dto.js';
import type { RenewSubscriptionDto } from './dto/renew-subscription.dto.js';

const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const PLAN_LABELS: Record<string, string> = {
  MONTHLY: 'شهري',
  THREE_MONTHS: 'ثلاثة أشهر',
  SIX_MONTHS: 'ستة أشهر',
  YEARLY: 'سنوي',
  CUSTOM: 'مدة مخصصة',
};

@Injectable()
export class PlatformService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async login(dto: PlatformLoginDto) {
    const email = dto.email.trim().toLowerCase();
    const admin = await this.prisma.platformAdmin.findUnique({ where: { email } });
    if (!admin || !admin.isActive || !(await compare(dto.password, admin.passwordHash))) {
      throw new UnauthorizedException('بيانات دخول إدارة NEXOR غير صحيحة.');
    }

    const accessToken = await this.jwtService.signAsync({
      sub: admin.id,
      tokenType: 'platform_admin',
    });
    return {
      accessToken,
      tokenType: 'Bearer',
      expiresIn: '12h',
      admin: { id: admin.id, email: admin.email, fullName: admin.fullName },
    };
  }

  async me(adminId: string) {
    const admin = await this.prisma.platformAdmin.findFirst({
      where: { id: adminId, isActive: true },
      select: { id: true, email: true, fullName: true, createdAt: true },
    });
    if (!admin) throw new UnauthorizedException('حساب إدارة NEXOR غير موجود.');
    return admin;
  }

  async dashboard() {
    const stores = await this.loadStores();
    const now = new Date();
    let active = 0;
    let expired = 0;
    let awaitingActivation = 0;
    let suspended = 0;
    let legacy = 0;
    let expiringSoon = 0;

    for (const store of stores) {
      if (store.isSuspended) {
        suspended++;
        continue;
      }
      if (!store.subscriptionRequired) {
        legacy++;
        continue;
      }
      if (!store.ownerActivatedAt) {
        awaitingActivation++;
        continue;
      }
      const current = store.subscriptions.find(
        (item) =>
          item.status === 'ACTIVE' &&
          item.startsAt &&
          item.endsAt &&
          item.startsAt <= now &&
          item.endsAt > now,
      );
      if (current) {
        active++;
        const days = (current.endsAt!.getTime() - now.getTime()) / 86400000;
        if (days <= 7) expiringSoon++;
      } else {
        expired++;
      }
    }

    return {
      totalStores: stores.length,
      activeStores: active,
      expiredStores: expired,
      awaitingActivation,
      suspendedStores: suspended,
      legacyStores: legacy,
      expiringSoon,
    };
  }

  async stores() {
    const records = await this.loadStores();
    const now = new Date();
    return records.map((store) => {
      const ownerMembership = store.organization.memberships.find(
        (membership) => membership.role === 'OWNER',
      );
      const currentSubscription = store.subscriptions.find(
        (item) =>
          item.status === 'ACTIVE' &&
          item.startsAt &&
          item.endsAt &&
          item.startsAt <= now &&
          item.endsAt > now,
      );
      const nextSubscription = store.subscriptions.find(
        (item) =>
          item.status === 'ACTIVE' &&
          item.startsAt &&
          item.startsAt > now,
      );
      let status = 'EXPIRED';
      if (store.isSuspended) status = 'SUSPENDED';
      else if (!store.subscriptionRequired) status = 'LEGACY';
      else if (!store.ownerActivatedAt) status = 'AWAITING_ACTIVATION';
      else if (currentSubscription) status = 'ACTIVE';
      else if (nextSubscription) status = 'SCHEDULED';

      return {
        id: store.id,
        name: store.name,
        contactName: store.contactName,
        contactPhone: store.contactPhone,
        organizationName: store.organization.name,
        ownerName: ownerMembership?.user.fullName ?? null,
        ownerEmail: ownerMembership?.user.email ?? null,
        ownerActivatedAt: store.ownerActivatedAt,
        isSuspended: store.isSuspended,
        subscriptionRequired: store.subscriptionRequired,
        status,
        currentSubscription: currentSubscription ?? nextSubscription ?? null,
        latestSubscription: store.subscriptions[0] ?? null,
        latestActivationCode: store.activationCodes[0] ?? null,
      };
    });
  }

  async createStore(dto: CreateStoreDto, adminId: string) {
    this.validatePayment(dto.amount, dto.paidAmount);
    const plan = this.getPlan(dto.plan, dto.durationDays);
    const rawCode = this.generateActivationCode();
    const codeHash = this.hashCode(rawCode);
    const slugBase = this.toSlug(dto.storeName);
    const slug = `${slugBase}-${randomUUID().slice(0, 8)}`;

    try {
      const created = await this.prisma.$transaction(async (tx) => {
        const organization = await tx.organization.create({
          data: {
            name: dto.storeName.trim(),
            slug,
            stores: {
              create: {
                name: dto.storeName.trim(),
                contactName: dto.contactName?.trim() || null,
                contactPhone: dto.contactPhone?.trim() || null,
                subscriptionRequired: true,
              },
            },
          },
          include: { stores: true },
        });
        const store = organization.stores[0];
        if (!store) throw new Error('تعذر إنشاء سجل المحل.');

        const subscription = await tx.storeSubscription.create({
          data: {
            storeId: store.id,
            plan: dto.plan,
            planName: PLAN_LABELS[dto.plan],
            durationMonths: plan.durationMonths,
            durationDays: plan.durationDays,
            status: 'PENDING',
            amount: dto.amount,
            paidAmount: dto.paidAmount,
            currency: dto.currency,
            notes: dto.notes?.trim() || null,
            createdByAdminId: adminId,
          },
        });
        const codeRecord = await tx.activationCode.create({
          data: {
            storeId: store.id,
            subscriptionId: subscription.id,
            codeHash,
            codeHint: this.codeHint(rawCode),
            createdByAdminId: adminId,
          },
        });
        await tx.platformAuditLog.create({
          data: {
            adminId,
            storeId: store.id,
            actorType: 'PLATFORM_ADMIN',
            actorId: adminId,
            action: 'STORE_CREATED_WITH_ACTIVATION_CODE',
            details: {
              plan: dto.plan,
              amount: dto.amount,
              paidAmount: dto.paidAmount,
              currency: dto.currency,
              activationCodeId: codeRecord.id,
            },
          },
        });
        return { store, subscription, codeRecord };
      });

      return {
        store: {
          id: created.store.id,
          name: created.store.name,
          contactName: created.store.contactName,
          contactPhone: created.store.contactPhone,
        },
        subscription: created.subscription,
        activationCode: rawCode,
        activationCodeHint: created.codeRecord.codeHint,
        message: 'تم إنشاء المحل وكود التفعيل. يظهر الكود الكامل مرة واحدة فقط.',
      };
    } catch (error) {
      if (typeof error === 'object' && error !== null && 'code' in error && error.code === 'P2002') {
        throw new ConflictException('تعذر إنشاء المحل بسبب تعارض في البيانات. حاول مرة أخرى.');
      }
      throw error;
    }
  }

  async enrollExistingStore(storeId: string, dto: RenewSubscriptionDto, adminId: string) {
    this.validatePayment(dto.amount, dto.paidAmount);
    const plan = this.getPlan(dto.plan, dto.durationDays);
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      include: {
        organization: { include: { memberships: { where: { role: 'OWNER' }, select: { userId: true } } } },
      },
    });
    if (!store) throw new NotFoundException('المحل غير موجود.');
    if (store.subscriptionRequired) throw new ConflictException('هذا المحل مسجل بالفعل ضمن نظام الاشتراكات. استخدم التجديد.');
    if (store.isSuspended) throw new BadRequestException('المحل موقوف حالياً. ألغِ الإيقاف أولاً ثم فعّل الاشتراك.');
    if (store.organization.memberships.length === 0) {
      throw new BadRequestException('لا يوجد حساب مالك مرتبط بهذا المحل؛ لا يمكن تفعيله كاشتراك قديم تلقائياً.');
    }

    const now = new Date();
    const endsAt = this.calculateEndDate(now, plan.durationMonths, plan.durationDays);
    const subscription = await this.prisma.$transaction(async (tx) => {
      await tx.store.update({
        where: { id: storeId },
        data: { subscriptionRequired: true, ownerActivatedAt: store.ownerActivatedAt ?? now },
      });
      const created = await tx.storeSubscription.create({
        data: {
          storeId,
          plan: dto.plan,
          planName: PLAN_LABELS[dto.plan],
          durationMonths: plan.durationMonths,
          durationDays: plan.durationDays,
          status: 'ACTIVE',
          startsAt: now,
          endsAt,
          activatedAt: now,
          amount: dto.amount,
          paidAmount: dto.paidAmount,
          currency: dto.currency,
          notes: dto.notes?.trim() || null,
          createdByAdminId: adminId,
        },
      });
      await tx.platformAuditLog.create({
        data: {
          adminId,
          storeId,
          actorType: 'PLATFORM_ADMIN',
          actorId: adminId,
          action: 'LEGACY_STORE_ENROLLED',
          details: { plan: dto.plan, startsAt: now.toISOString(), endsAt: endsAt.toISOString() },
        },
      });
      return created;
    });
    return { storeName: store.name, subscription };
  }

  async reissueActivationCode(storeId: string, adminId: string) {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: {
        id: true,
        name: true,
        ownerActivatedAt: true,
        subscriptions: { where: { status: 'PENDING' }, orderBy: { createdAt: 'desc' }, take: 1 },
      },
    });
    if (!store) throw new NotFoundException('المحل غير موجود.');
    if (store.ownerActivatedAt) throw new BadRequestException('تم إنشاء حساب المحل بالفعل؛ لا يمكن إصدار كود تسجيل أولي جديد.');
    const subscription = store.subscriptions[0];
    if (!subscription) throw new BadRequestException('لا يوجد اشتراك معلّق لإصدار كود له.');

    const rawCode = this.generateActivationCode();
    const codeHash = this.hashCode(rawCode);
    const result = await this.prisma.$transaction(async (tx) => {
      await tx.activationCode.updateMany({
        where: { storeId, status: 'AVAILABLE' },
        data: { status: 'REVOKED' },
      });
      const code = await tx.activationCode.create({
        data: {
          storeId,
          subscriptionId: subscription.id,
          codeHash,
          codeHint: this.codeHint(rawCode),
          createdByAdminId: adminId,
        },
      });
      await tx.platformAuditLog.create({
        data: {
          adminId,
          storeId,
          actorType: 'PLATFORM_ADMIN',
          actorId: adminId,
          action: 'ACTIVATION_CODE_REISSUED',
          details: { activationCodeId: code.id },
        },
      });
      return code;
    });

    return {
      store: { id: store.id, name: store.name },
      activationCode: rawCode,
      activationCodeHint: result.codeHint,
      message: 'تم إلغاء الكود السابق وإصدار كود جديد. يظهر الكود الكامل مرة واحدة فقط.',
    };
  }

  async renewStore(storeId: string, dto: RenewSubscriptionDto, adminId: string) {
    this.validatePayment(dto.amount, dto.paidAmount);
    const plan = this.getPlan(dto.plan, dto.durationDays);
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { id: true, name: true, subscriptionRequired: true, ownerActivatedAt: true },
    });
    if (!store || !store.subscriptionRequired) throw new NotFoundException('المحل غير موجود.');
    if (!store.ownerActivatedAt) {
      throw new BadRequestException('يجب أن ينشئ صاحب المحل الحساب أولاً. استخدم كود التسجيل الأول.');
    }

    const now = new Date();
    const created = await this.prisma.$transaction(async (tx) => {
      const latestActive = await tx.storeSubscription.findFirst({
        where: { storeId, status: 'ACTIVE', endsAt: { not: null } },
        orderBy: { endsAt: 'desc' },
      });
      const previousEnd = latestActive?.endsAt ?? null;
      const startsAt = previousEnd && previousEnd > now ? previousEnd : now;
      const endsAt = this.calculateEndDate(startsAt, plan.durationMonths, plan.durationDays);
      const subscription = await tx.storeSubscription.create({
        data: {
          storeId,
          plan: dto.plan,
          planName: PLAN_LABELS[dto.plan],
          durationMonths: plan.durationMonths,
          durationDays: plan.durationDays,
          status: 'ACTIVE',
          startsAt,
          endsAt,
          activatedAt: now,
          amount: dto.amount,
          paidAmount: dto.paidAmount,
          currency: dto.currency,
          notes: dto.notes?.trim() || null,
          createdByAdminId: adminId,
        },
      });
      await tx.platformAuditLog.create({
        data: {
          adminId,
          storeId,
          actorType: 'PLATFORM_ADMIN',
          actorId: adminId,
          action: 'SUBSCRIPTION_RENEWED',
          details: { plan: dto.plan, startsAt: startsAt.toISOString(), endsAt: endsAt.toISOString() },
        },
      });
      return subscription;
    });
    return { storeName: store.name, subscription: created };
  }

  async setSuspension(storeId: string, isSuspended: boolean, adminId: string) {
    const store = await this.prisma.store.findUnique({ where: { id: storeId }, select: { id: true, name: true } });
    if (!store) throw new NotFoundException('المحل غير موجود.');
    await this.prisma.$transaction([
      this.prisma.store.update({ where: { id: storeId }, data: { isSuspended } }),
      this.prisma.platformAuditLog.create({
        data: {
          adminId,
          storeId,
          actorType: 'PLATFORM_ADMIN',
          actorId: adminId,
          action: isSuspended ? 'STORE_SUSPENDED' : 'STORE_REACTIVATED',
          details: { isSuspended },
        },
      }),
    ]);
    return { id: store.id, name: store.name, isSuspended };
  }

  async auditLogs(limit = 50) {
    return this.prisma.platformAuditLog.findMany({
      take: Math.min(Math.max(limit, 1), 100),
      orderBy: { createdAt: 'desc' },
      include: {
        store: { select: { id: true, name: true } },
        admin: { select: { id: true, fullName: true } },
      },
    });
  }

  private async loadStores() {
    // Keep the persisted status aligned with the clock for admin reporting.
    await this.prisma.storeSubscription.updateMany({
      where: { status: 'ACTIVE', endsAt: { lte: new Date() } },
      data: { status: 'EXPIRED' },
    });
    return this.prisma.store.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        organization: {
          include: {
            memberships: {
              where: { role: 'OWNER' },
              include: { user: { select: { id: true, fullName: true, email: true } } },
            },
          },
        },
        subscriptions: { orderBy: { createdAt: 'desc' }, take: 10 },
        activationCodes: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { id: true, codeHint: true, status: true, createdAt: true, usedAt: true, expiresAt: true },
        },
      },
    });
  }

  private getPlan(plan: string, durationDays?: number) {
    const months: Record<string, number> = {
      MONTHLY: 1,
      THREE_MONTHS: 3,
      SIX_MONTHS: 6,
      YEARLY: 12,
      CUSTOM: 0,
    };
    if (plan === 'CUSTOM') {
      if (!durationDays || durationDays < 1 || durationDays > 1095) {
        throw new BadRequestException('المدة المخصصة يجب أن تكون بين يوم و1095 يوماً.');
      }
      return { durationMonths: 0, durationDays };
    }
    return { durationMonths: months[plan] ?? 0, durationDays: 0 };
  }

  private calculateEndDate(start: Date, months: number, days: number): Date {
    const result = new Date(start);
    if (months > 0) {
      const originalDay = result.getUTCDate();
      result.setUTCDate(1);
      result.setUTCMonth(result.getUTCMonth() + months);
      const lastDay = new Date(Date.UTC(result.getUTCFullYear(), result.getUTCMonth() + 1, 0)).getUTCDate();
      result.setUTCDate(Math.min(originalDay, lastDay));
      return result;
    }
    result.setUTCDate(result.getUTCDate() + days);
    return result;
  }

  private validatePayment(amount: number, paidAmount: number) {
    if (paidAmount > amount) throw new BadRequestException('المبلغ المدفوع لا يمكن أن يتجاوز قيمة الاشتراك.');
  }

  private generateActivationCode(): string {
    const bytes = randomBytes(12);
    const chars = Array.from(bytes, (byte) => CODE_ALPHABET[byte % CODE_ALPHABET.length]);
    return `NX-${chars.slice(0, 4).join('')}-${chars.slice(4, 8).join('')}-${chars.slice(8, 12).join('')}`;
  }

  private hashCode(code: string): string {
    return createHash('sha256').update(code.trim().toUpperCase().replace(/\s+/g, '')).digest('hex');
  }

  private codeHint(code: string): string {
    return `${code.slice(0, 7)}-••••-••••`;
  }

  private toSlug(value: string): string {
    const slug = value.normalize('NFKC').trim().toLowerCase()
      .replace(/[^\p{L}\p{N}]+/gu, '-').replace(/^-+|-+$/g, '').slice(0, 48);
    return slug || 'store';
  }
}
