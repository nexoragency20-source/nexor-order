import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';

const asNumber = (value: unknown): number => {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && 'toString' in value) {
    return Number((value as { toString(): string }).toString());
  }
  return Number(value ?? 0);
};
const round2 = (value: number) => Math.round((value + Number.EPSILON) * 100) / 100;

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(user: AccessTokenPayload, requestedDate?: string, offsetValue?: string) {
    const store = await this.prisma.store.findFirst({
      where: { id: user.storeId, organizationId: user.organizationId },
      select: { id: true },
    });
    if (!store) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');

    const utcOffsetMinutes = this.parseOffset(offsetValue);
    const date = this.normalizeDate(requestedDate, utcOffsetMinutes);
    const day = this.dayBounds(date, utcOffsetMinutes);
    const firstTrendDate = this.shiftDate(date, -6);
    const trendStart = this.dayBounds(firstTrendDate, utcOffsetMinutes).start;

    const [
      ordersTodayCount,
      salesToday,
      receivedReturnsToday,
      pendingReturnsCount,
      activeCustomersCount,
      products,
      groupedStatuses,
      recentOrders,
      trendOrders,
      trendReturns,
    ] = await Promise.all([
      this.prisma.order.count({
        where: { storeId: store.id, createdAt: { gte: day.start, lt: day.end }, status: { not: 'CANCELLED' } },
      }),
      this.prisma.order.aggregate({
        where: { storeId: store.id, createdAt: { gte: day.start, lt: day.end }, status: { not: 'CANCELLED' } },
        _sum: { totalSyp: true, totalUsd: true },
      }),
      this.prisma.salesReturn.findMany({
        where: { storeId: store.id, status: 'RECEIVED', receivedAt: { gte: day.start, lt: day.end } },
        select: { amountSypEquivalent: true, amountUsdEquivalent: true },
      }),
      this.prisma.salesReturn.count({ where: { storeId: store.id, status: 'REQUESTED' } }),
      this.prisma.customer.count({ where: { storeId: store.id, isActive: true } }),
      this.prisma.product.findMany({
        where: { storeId: store.id, isActive: true },
        select: { stockQuantity: true, minimumStock: true },
      }),
      this.prisma.order.groupBy({
        by: ['status'],
        where: { storeId: store.id },
        _count: { _all: true },
      }),
      this.prisma.order.findMany({
        where: { storeId: store.id },
        orderBy: { createdAt: 'desc' },
        take: 6,
        select: {
          orderNumber: true,
          status: true,
          totalSyp: true,
          createdAt: true,
          customerNameSnapshot: true,
          customer: { select: { name: true } },
        },
      }),
      this.prisma.order.findMany({
        where: { storeId: store.id, status: { not: 'CANCELLED' }, createdAt: { gte: trendStart, lt: day.end } },
        select: { createdAt: true, totalSyp: true },
      }),
      this.prisma.salesReturn.findMany({
        where: { storeId: store.id, status: 'RECEIVED', receivedAt: { gte: trendStart, lt: day.end } },
        select: { receivedAt: true, amountSypEquivalent: true },
      }),
    ]);

    const returnedTodaySyp = round2(receivedReturnsToday.reduce((sum, row) => sum + asNumber(row.amountSypEquivalent), 0));
    const grossSalesTodaySyp = round2(asNumber(salesToday._sum.totalSyp));
    const activeProductsCount = products.length;
    const lowStockProductsCount = products.filter((product) =>
      asNumber(product.stockQuantity) <= asNumber(product.minimumStock),
    ).length;

    const counts = new Map<string, number>();
    let totalOrdersCount = 0;
    for (const row of groupedStatuses) {
      const count = row._count._all;
      counts.set(row.status, count);
      totalOrdersCount += count;
    }
    const statuses = ['PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'COMPLETED', 'CANCELLED'];
    const orderStatuses = statuses.map((status) => {
      const count = counts.get(status) ?? 0;
      return {
        status,
        count,
        percentage: totalOrdersCount > 0 ? round2((count / totalOrdersCount) * 100) : 0,
      };
    });

    const trend = new Map<string, { grossSalesSyp: number; returnedSyp: number; ordersCount: number }>();
    for (let i = 0; i < 7; i++) {
      const key = this.shiftDate(firstTrendDate, i);
      trend.set(key, { grossSalesSyp: 0, returnedSyp: 0, ordersCount: 0 });
    }
    for (const row of trendOrders) {
      const key = this.utcToLocalDate(row.createdAt, utcOffsetMinutes);
      const point = trend.get(key);
      if (point) {
        point.grossSalesSyp += asNumber(row.totalSyp);
        point.ordersCount += 1;
      }
    }
    for (const row of trendReturns) {
      if (!row.receivedAt) continue;
      const key = this.utcToLocalDate(row.receivedAt, utcOffsetMinutes);
      const point = trend.get(key);
      if (point) point.returnedSyp += asNumber(row.amountSypEquivalent);
    }
    const salesTrend = [...trend.entries()].map(([dayKey, value]) => ({
      date: dayKey,
      grossSalesSyp: round2(value.grossSalesSyp),
      returnedSyp: round2(value.returnedSyp),
      netSalesSyp: round2(value.grossSalesSyp - value.returnedSyp),
      ordersCount: value.ordersCount,
    }));

    return {
      date,
      timezoneOffsetMinutes: utcOffsetMinutes,
      summary: {
        ordersTodayCount,
        grossSalesTodaySyp,
        returnedTodaySyp,
        netSalesTodaySyp: round2(grossSalesTodaySyp - returnedTodaySyp),
        receivedReturnsTodayCount: receivedReturnsToday.length,
        pendingReturnsCount,
        activeCustomersCount,
        activeProductsCount,
        lowStockProductsCount,
        totalOrdersCount,
      },
      salesTrend,
      orderStatuses,
      recentOrders: recentOrders.map((row) => ({
        orderNumber: row.orderNumber,
        customerName: row.customerNameSnapshot || row.customer?.name || 'عميل غير محدد',
        status: row.status,
        totalSyp: asNumber(row.totalSyp),
        createdAt: row.createdAt.toISOString(),
      })),
    };
  }

  private parseOffset(value?: string): number {
    if (value === undefined || value.trim() === '') return 0;
    const offset = Number(value);
    if (!Number.isInteger(offset) || offset < -840 || offset > 840) {
      throw new BadRequestException('إعداد المنطقة الزمنية غير صالح.');
    }
    return offset;
  }

  private normalizeDate(value: string | undefined, offset: number): string {
    if (value === undefined || value.trim() === '') {
      return this.utcToLocalDate(new Date(), offset);
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw new BadRequestException('تاريخ لوحة التحكم غير صالح.');
    }
    const parsed = new Date(`${value}T00:00:00.000Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
      throw new BadRequestException('تاريخ لوحة التحكم غير صالح.');
    }
    return value;
  }

  private dayBounds(localDate: string, offset: number) {
    const [year, month, day] = localDate.split('-').map(Number);
    const startMs = Date.UTC(year, month - 1, day) - offset * 60_000;
    return { start: new Date(startMs), end: new Date(startMs + 24 * 60 * 60 * 1000) };
  }

  private shiftDate(localDate: string, days: number): string {
    const [year, month, day] = localDate.split('-').map(Number);
    return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
  }

  private utcToLocalDate(value: Date, offset: number): string {
    return new Date(value.getTime() + offset * 60_000).toISOString().slice(0, 10);
  }
}
