import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import type { UpdateStoreSettingsDto } from './dto/settings.dto.js';

const asNumber = (value: unknown): number => {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && 'toString' in value) {
    return Number((value as { toString(): string }).toString());
  }
  return Number(value ?? 0);
};

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async getStoreSettings(user: AccessTokenPayload) {
    const store = await this.prisma.store.findFirst({
      where: { id: user.storeId, organizationId: user.organizationId },
      select: {
        id: true,
        name: true,
        defaultCurrency: true,
        exchangeRateSypPerUsd: true,
        notifyNewOrders: true,
        notifyLowStock: true,
        notifyReturns: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!store) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');

    const exchangeRateHistory = await this.prisma.exchangeRateHistory.findMany({
      where: { storeId: store.id },
      orderBy: { changedAt: 'desc' },
      take: 8,
      select: {
        id: true,
        oldRateSypPerUsd: true,
        newRateSypPerUsd: true,
        note: true,
        changedAt: true,
      },
    });

    return {
      store: {
        id: store.id,
        name: store.name,
        defaultCurrency: store.defaultCurrency,
        exchangeRateSypPerUsd: asNumber(store.exchangeRateSypPerUsd),
        createdAt: store.createdAt.toISOString(),
        updatedAt: store.updatedAt.toISOString(),
      },
      preferences: {
        notifyNewOrders: store.notifyNewOrders,
        notifyLowStock: store.notifyLowStock,
        notifyReturns: store.notifyReturns,
      },
      exchangeRateHistory: exchangeRateHistory.map((row) => ({
        id: row.id,
        oldRateSypPerUsd: asNumber(row.oldRateSypPerUsd),
        newRateSypPerUsd: asNumber(row.newRateSypPerUsd),
        note: row.note ?? '',
        changedAt: row.changedAt.toISOString(),
      })),
    };
  }

  async updateStoreSettings(user: AccessTokenPayload, dto: UpdateStoreSettingsDto) {
    const current = await this.prisma.store.findFirst({
      where: { id: user.storeId, organizationId: user.organizationId },
      select: {
        id: true,
        name: true,
        defaultCurrency: true,
        exchangeRateSypPerUsd: true,
      },
    });
    if (!current) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');

    const oldRate = asNumber(current.exchangeRateSypPerUsd);
    const nextRate = dto.exchangeRateSypPerUsd ?? oldRate;
    const rateChanged = Math.abs(nextRate - oldRate) > 0.0000001;

    await this.prisma.$transaction(async (tx) => {
      await tx.store.update({
        where: { id: current.id },
        data: {
          ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
          ...(dto.defaultCurrency !== undefined
            ? { defaultCurrency: dto.defaultCurrency as any }
            : {}),
          ...(dto.exchangeRateSypPerUsd !== undefined
            ? { exchangeRateSypPerUsd: nextRate }
            : {}),
          ...(dto.notifyNewOrders !== undefined
            ? { notifyNewOrders: dto.notifyNewOrders }
            : {}),
          ...(dto.notifyLowStock !== undefined
            ? { notifyLowStock: dto.notifyLowStock }
            : {}),
          ...(dto.notifyReturns !== undefined
            ? { notifyReturns: dto.notifyReturns }
            : {}),
        },
      });

      if (rateChanged) {
        await tx.exchangeRateHistory.create({
          data: {
            storeId: current.id,
            oldRateSypPerUsd: oldRate,
            newRateSypPerUsd: nextRate,
            changedByUserId: user.sub,
            note: 'تحديث سعر الصرف من إعدادات المتجر',
          },
        });
      }
    }, { isolationLevel: 'Serializable' });

    return this.getStoreSettings(user);
  }
}
