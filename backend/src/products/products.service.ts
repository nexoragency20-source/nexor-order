import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import type { ProductDto, ExchangeRateDto } from './dto/product.dto.js';

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AccessTokenPayload) {
    const store = await this.getStore(user);
    const rows = await this.prisma.product.findMany({
      where: { storeId: store.id },
      include: { category: true },
      orderBy: [{ isActive: 'desc' }, { createdAt: 'desc' }],
    });
    const rate = Number(store.exchangeRateSypPerUsd.toString());

    return {
      exchangeRateSypPerUsd: rate,
      items: rows.map((row) => this.serializeProduct(row, rate)),
    };
  }

  async create(user: AccessTokenPayload, dto: ProductDto) {
    const store = await this.getStore(user);
    const category = await this.resolveCategory(store.id, dto.category);

    try {
      const row = await this.prisma.product.create({
        data: {
          storeId: store.id,
          categoryId: category?.id ?? null,
          name: dto.name.trim(),
          barcode: dto.barcode?.trim() || null,
          purchasePriceUsd: dto.purchasePriceUsd,
          sellingPriceUsd: dto.sellingPriceUsd,
          stockQuantity: dto.stockQuantity,
          minimumStock: dto.minimumStock,
          description: dto.description?.trim() || null,
          isActive: dto.isActive ?? true,
        },
        include: { category: true },
      });
      return this.serializeProduct(row, Number(store.exchangeRateSypPerUsd.toString()));
    } catch (error) {
      this.handleUniqueConstraint(error);
      throw error;
    }
  }

  async update(user: AccessTokenPayload, id: string, dto: ProductDto) {
    const store = await this.getStore(user);
    const existing = await this.prisma.product.findFirst({
      where: { id, storeId: store.id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('المنتج غير موجود في هذا المتجر.');

    const category = await this.resolveCategory(store.id, dto.category);

    try {
      const row = await this.prisma.product.update({
        where: { id },
        data: {
          categoryId: category?.id ?? null,
          name: dto.name.trim(),
          barcode: dto.barcode?.trim() || null,
          purchasePriceUsd: dto.purchasePriceUsd,
          sellingPriceUsd: dto.sellingPriceUsd,
          stockQuantity: dto.stockQuantity,
          minimumStock: dto.minimumStock,
          description: dto.description?.trim() || null,
          isActive: dto.isActive ?? true,
        },
        include: { category: true },
      });
      return this.serializeProduct(row, Number(store.exchangeRateSypPerUsd.toString()));
    } catch (error) {
      this.handleUniqueConstraint(error);
      throw error;
    }
  }

  /** Archive instead of hard-delete so historical order/purchase references remain valid. */
  async archive(user: AccessTokenPayload, id: string) {
    const store = await this.getStore(user);
    const existing = await this.prisma.product.findFirst({
      where: { id, storeId: store.id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('المنتج غير موجود في هذا المتجر.');

    const row = await this.prisma.product.update({
      where: { id },
      data: { isActive: false },
      include: { category: true },
    });
    return this.serializeProduct(row, Number(store.exchangeRateSypPerUsd.toString()));
  }

  async updateExchangeRate(user: AccessTokenPayload, dto: ExchangeRateDto) {
    const store = await this.getStore(user);
    const oldRate = Number(store.exchangeRateSypPerUsd.toString());

    const updated = await this.prisma.$transaction(async (tx) => {
      const nextStore = await tx.store.update({
        where: { id: store.id },
        data: { exchangeRateSypPerUsd: dto.exchangeRateSypPerUsd },
        select: { id: true, exchangeRateSypPerUsd: true },
      });

      await tx.exchangeRateHistory.create({
        data: {
          storeId: store.id,
          oldRateSypPerUsd: oldRate,
          newRateSypPerUsd: dto.exchangeRateSypPerUsd,
          changedByUserId: user.sub,
          note: 'تحديث سعر الصرف من شاشة المنتجات',
        },
      });

      return nextStore;
    });

    return {
      storeId: updated.id,
      exchangeRateSypPerUsd: Number(updated.exchangeRateSypPerUsd.toString()),
    };
  }

  private async getStore(user: AccessTokenPayload) {
    const store = await this.prisma.store.findFirst({
      where: { id: user.storeId, organizationId: user.organizationId },
      select: { id: true, exchangeRateSypPerUsd: true },
    });
    if (!store) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');
    return store;
  }

  private async resolveCategory(storeId: string, rawName?: string) {
    const name = rawName?.trim();
    if (!name) return null;
    return this.prisma.category.upsert({
      where: { storeId_name: { storeId, name } },
      create: { storeId, name },
      update: { isActive: true },
      select: { id: true, name: true },
    });
  }

  private serializeProduct(row: any, rate: number) {
    const purchasePriceUsd = Number(row.purchasePriceUsd.toString());
    const sellingPriceUsd = Number(row.sellingPriceUsd.toString());
    const stockQuantity = Number(row.stockQuantity.toString());
    const minimumStock = Number(row.minimumStock.toString());

    return {
      id: row.id,
      name: row.name,
      barcode: row.barcode ?? '',
      category: row.category?.name ?? '',
      purchasePriceUsd,
      purchasePriceSyp: Math.round(purchasePriceUsd * rate),
      sellingPriceUsd,
      sellingPriceSyp: Math.round(sellingPriceUsd * rate),
      exchangeRateSypPerUsd: rate,
      stockQuantity,
      minimumStock,
      description: row.description ?? '',
      isActive: row.isActive,
      createdAt: row.createdAt.toISOString(),
    };
  }

  private handleUniqueConstraint(error: unknown): void {
    if (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      (error as { code?: string }).code === 'P2002'
    ) {
      throw new ConflictException('هذا الباركود مستخدم لمنتج آخر في المتجر.');
    }
  }
}
