import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import type {
  CustomerAccountPaymentDto,
  CustomerDto,
} from './dto/customers.dto.js';

const asNumber = (value: unknown): number => {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && 'toString' in value) {
    return Number((value as { toString(): string }).toString());
  }
  return Number(value ?? 0);
};

const round6 = (value: number): number =>
  Math.round((value + Number.EPSILON) * 1_000_000) / 1_000_000;
const round2 = (value: number): number =>
  Math.round((value + Number.EPSILON) * 100) / 100;

@Injectable()
export class CustomersService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AccessTokenPayload) {
    const store = await this.getStore(user);
    const rows = await this.prisma.customer.findMany({
      where: { storeId: store.id, isActive: true },
      include: {
        orders: {
          where: { status: { not: 'CANCELLED' } },
          select: { totalUsd: true, totalSyp: true, createdAt: true },
        },
        payments: {
          select: { amountUsdEquivalent: true, amountSypEquivalent: true },
        },
        salesReturns: {
          where: { status: 'RECEIVED' },
          select: {
            amountUsdEquivalent: true,
            amountSypEquivalent: true,
            settlementType: true,
          },
        },
      },
      orderBy: [{ name: 'asc' }, { createdAt: 'desc' }],
    });

    return {
      exchangeRateSypPerUsd: asNumber(store.exchangeRateSypPerUsd),
      items: rows.map((row) => this.serializeCustomer(row)),
    };
  }

  async create(user: AccessTokenPayload, dto: CustomerDto) {
    const store = await this.getStore(user);
    await this.assertPhoneAvailable(store.id, dto.phone, undefined);
    const row = await this.prisma.customer.create({
      data: {
        storeId: store.id,
        name: dto.name.trim(),
        phone: this.optionalText(dto.phone),
        email: this.optionalText(dto.email),
        address: this.optionalText(dto.address),
        notes: this.optionalText(dto.notes),
      },
    });
    return this.serializeCustomer({ ...row, orders: [], payments: [], salesReturns: [] });
  }

  async update(user: AccessTokenPayload, id: string, dto: CustomerDto) {
    const store = await this.getStore(user);
    const existing = await this.prisma.customer.findFirst({
      where: { id, storeId: store.id, isActive: true },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('العميل غير موجود أو مؤرشف.');
    await this.assertPhoneAvailable(store.id, dto.phone, id);
    const row = await this.prisma.customer.update({
      where: { id },
      data: {
        name: dto.name.trim(),
        phone: this.optionalText(dto.phone),
        email: this.optionalText(dto.email),
        address: this.optionalText(dto.address),
        notes: this.optionalText(dto.notes),
      },
      include: {
        orders: {
          where: { status: { not: 'CANCELLED' } },
          select: { totalUsd: true, totalSyp: true, createdAt: true },
        },
        payments: {
          select: { amountUsdEquivalent: true, amountSypEquivalent: true },
        },
        salesReturns: {
          where: { status: 'RECEIVED' },
          select: {
            amountUsdEquivalent: true,
            amountSypEquivalent: true,
            settlementType: true,
          },
        },
      },
    });
    return this.serializeCustomer(row);
  }

  async archive(user: AccessTokenPayload, id: string) {
    const store = await this.getStore(user);
    const existing = await this.prisma.customer.findFirst({
      where: { id, storeId: store.id, isActive: true },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('العميل غير موجود أو مؤرشف مسبقاً.');
    const row = await this.prisma.customer.update({
      where: { id },
      data: { isActive: false },
    });
    return { id: row.id, isActive: row.isActive, message: 'تمت أرشفة العميل مع الاحتفاظ بسجلاته.' };
  }

  async statement(user: AccessTokenPayload, id: string) {
    const store = await this.getStore(user);
    const row = await this.prisma.customer.findFirst({
      where: { id, storeId: store.id },
      include: {
        orders: {
          where: { status: { not: 'CANCELLED' } },
          include: { payments: { select: { amountUsdEquivalent: true, amountSypEquivalent: true } } },
          orderBy: { createdAt: 'asc' },
        },
        payments: {
          include: { order: { select: { orderNumber: true } } },
          orderBy: { paidAt: 'asc' },
        },
        salesReturns: {
          where: { status: 'RECEIVED' },
          include: { order: { select: { orderNumber: true } } },
          orderBy: { receivedAt: 'asc' },
        },
      },
    });
    if (!row) throw new NotFoundException('العميل غير موجود في هذا المتجر.');

    const rate = asNumber(store.exchangeRateSypPerUsd);
    const customer = this.serializeCustomer(row);
    const orders = row.orders.map((order) => {
      const paidUsd = order.payments.reduce(
        (sum, payment) => sum + asNumber(payment.amountUsdEquivalent),
        0,
      );
      const paidSyp = order.payments.reduce(
        (sum, payment) => sum + asNumber(payment.amountSypEquivalent),
        0,
      );
      const orderReturns = (row.salesReturns ?? []).filter((item) => item.orderId === order.id);
      const returnedUsd = orderReturns.reduce((sum, item) => sum + asNumber(item.amountUsdEquivalent), 0);
      const returnedSyp = orderReturns.reduce((sum, item) => sum + asNumber(item.amountSypEquivalent), 0);
      const cashRefundUsd = orderReturns.filter((item) => item.settlementType === 'CASH')
        .reduce((sum, item) => sum + asNumber(item.amountUsdEquivalent), 0);
      const cashRefundSyp = orderReturns.filter((item) => item.settlementType === 'CASH')
        .reduce((sum, item) => sum + asNumber(item.amountSypEquivalent), 0);
      const totalUsd = asNumber(order.totalUsd);
      const totalSyp = asNumber(order.totalSyp);
      const netTotalUsd = Math.max(0, totalUsd - returnedUsd);
      const netTotalSyp = Math.max(0, totalSyp - returnedSyp);
      const netPaidUsd = Math.min(netTotalUsd, Math.max(0, paidUsd - cashRefundUsd));
      const netPaidSyp = Math.min(netTotalSyp, Math.max(0, paidSyp - cashRefundSyp));
      return {
        id: order.id,
        orderNumber: order.orderNumber,
        status: order.status,
        createdAt: order.createdAt.toISOString(),
        totalUsd,
        totalSyp,
        returnedUsd: round6(returnedUsd),
        returnedSyp: round2(returnedSyp),
        netTotalUsd: round6(netTotalUsd),
        netTotalSyp: round2(netTotalSyp),
        paidUsd: round6(netPaidUsd),
        paidSyp: round2(netPaidSyp),
        remainingUsd: round6(Math.max(0, netTotalUsd - netPaidUsd)),
        remainingSyp: round2(Math.max(0, netTotalSyp - netPaidSyp)),
      };
    });

    const movements: Array<Record<string, unknown> & { sortAt: number }> = [];
    for (const order of row.orders) {
      movements.push({
        id: `ORDER-${order.id}`,
        type: 'ORDER',
        title: `فاتورة طلب ${order.orderNumber}`,
        reference: order.orderNumber,
        date: order.createdAt.toISOString(),
        debitSyp: asNumber(order.totalSyp),
        creditSyp: 0,
        note: order.status,
        sortAt: order.createdAt.getTime(),
      });
    }
    for (const payment of row.payments) {
      movements.push({
        id: `PAYMENT-${payment.id}`,
        type: 'PAYMENT',
        title: payment.order?.orderNumber
          ? `دفعة على الطلب ${payment.order.orderNumber}`
          : 'دفعة على الحساب',
        reference: payment.order?.orderNumber ?? 'دفعة عامة',
        date: payment.paidAt.toISOString(),
        debitSyp: 0,
        creditSyp: asNumber(payment.amountSypEquivalent),
        amount: asNumber(payment.amount),
        currency: payment.currency,
        method: payment.method,
        note: payment.note ?? '',
        sortAt: payment.paidAt.getTime(),
      });
    }
    for (const salesReturn of row.salesReturns ?? []) {
      const orderNumber = salesReturn.order?.orderNumber ?? '—';
      const returnedAt = salesReturn.receivedAt ?? salesReturn.createdAt;
      movements.push({
        id: `RETURN-${salesReturn.id}`,
        type: 'RETURN',
        title: `مرتجع من الطلب ${orderNumber}`,
        reference: salesReturn.returnNumber,
        date: returnedAt.toISOString(),
        debitSyp: 0,
        creditSyp: asNumber(salesReturn.amountSypEquivalent),
        amount: asNumber(salesReturn.amount),
        currency: salesReturn.currency,
        method: salesReturn.settlementType,
        note: salesReturn.reason ?? salesReturn.notes ?? '',
        sortAt: returnedAt.getTime(),
      });
      if (salesReturn.settlementType === 'CASH') {
        movements.push({
          id: `REFUND-${salesReturn.id}`,
          type: 'REFUND',
          title: `رد نقدي للعميل — ${salesReturn.returnNumber}`,
          reference: salesReturn.returnNumber,
          date: returnedAt.toISOString(),
          debitSyp: asNumber(salesReturn.amountSypEquivalent),
          creditSyp: 0,
          amount: asNumber(salesReturn.amount),
          currency: salesReturn.currency,
          method: 'CASH',
          note: 'تم صرف قيمة المرتجع نقداً من الصندوق',
          sortAt: returnedAt.getTime() + 1,
        });
      }
    }
    movements.sort((a, b) => a.sortAt - b.sortAt);
    let runningBalance = 0;
    const chronological = movements.map(({ sortAt: _sortAt, ...movement }) => {
      runningBalance += asNumber(movement.debitSyp) - asNumber(movement.creditSyp);
      return { ...movement, balanceAfterSyp: round2(runningBalance) };
    });

    return {
      exchangeRateSypPerUsd: rate,
      customer,
      orders: orders.sort((a, b) => b.createdAt.localeCompare(a.createdAt)),
      movements: chronological.reverse(),
      summary: {
        orderCount: customer.orderCount,
        totalPurchasesUsd: customer.totalPurchasesUsd,
        totalPurchasesSyp: customer.totalPurchasesSyp,
        paidUsd: customer.paidUsd,
        paidSyp: customer.paidSyp,
        balanceUsd: customer.balanceUsd,
        balanceSyp: customer.balanceSyp,
      },
    };
  }

  async recordPayment(
    user: AccessTokenPayload,
    customerId: string,
    dto: CustomerAccountPaymentDto,
  ) {
    const store = await this.getStore(user);
    return this.prisma.$transaction(
      async (tx) => {
        const customer = await tx.customer.findFirst({
          where: { id: customerId, storeId: store.id },
          select: { id: true, name: true },
        });
        if (!customer) throw new NotFoundException('العميل غير موجود في هذا المتجر.');

        const rateRow = await tx.store.findFirst({
          where: { id: store.id, organizationId: user.organizationId },
          select: { exchangeRateSypPerUsd: true },
        });
        if (!rateRow) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');
        const rate = asNumber(rateRow.exchangeRateSypPerUsd);
        if (!Number.isFinite(dto.amount) || dto.amount <= 0) {
          throw new BadRequestException('أدخل مبلغاً أكبر من صفر.');
        }
        const amountUsd = round6(dto.currency === 'USD' ? dto.amount : dto.amount / rate);
        const amountSyp = dto.currency === 'SYP'
          ? round2(dto.amount)
          : round2(dto.amount * rate);

        const [ordersAggregate, paymentsAggregate, returnRows] = await Promise.all([
          tx.order.aggregate({
            where: { storeId: store.id, customerId, status: { not: 'CANCELLED' } },
            _sum: { totalUsd: true },
          }),
          tx.customerPayment.aggregate({
            where: { storeId: store.id, customerId },
            _sum: { amountUsdEquivalent: true },
          }),
          tx.salesReturn.findMany({
            where: { storeId: store.id, customerId, status: 'RECEIVED' },
            select: { amountUsdEquivalent: true, settlementType: true },
          }),
        ]);
        const returnedUsd = returnRows.reduce((sum, item) => sum + asNumber(item.amountUsdEquivalent), 0);
        const cashRefundUsd = returnRows.filter((item) => item.settlementType === 'CASH')
          .reduce((sum, item) => sum + asNumber(item.amountUsdEquivalent), 0);
        const customerBalanceUsd = asNumber(ordersAggregate._sum.totalUsd) - returnedUsd +
          cashRefundUsd - asNumber(paymentsAggregate._sum.amountUsdEquivalent);
        if (amountUsd > customerBalanceUsd + 0.000001) {
          throw new BadRequestException('قيمة الدفعة أكبر من رصيد العميل المستحق.');
        }

        if (dto.orderId) {
          const order = await tx.order.findFirst({
            where: {
              id: dto.orderId,
              storeId: store.id,
              customerId,
              status: { not: 'CANCELLED' },
            },
            include: {
              payments: { select: { amountUsdEquivalent: true } },
              returns: {
                where: { status: 'RECEIVED' },
                select: { amountUsdEquivalent: true, settlementType: true },
              },
            },
          });
          if (!order) throw new NotFoundException('الطلب المحدد غير موجود لهذا العميل.');
          const paidOnOrder = order.payments.reduce(
            (sum, payment) => sum + asNumber(payment.amountUsdEquivalent),
            0,
          );
          const returnedOnOrder = order.returns.reduce((sum, item) => sum + asNumber(item.amountUsdEquivalent), 0);
          const cashRefundOnOrder = order.returns.filter((item) => item.settlementType === 'CASH')
            .reduce((sum, item) => sum + asNumber(item.amountUsdEquivalent), 0);
          const netOrderTotal = asNumber(order.totalUsd) - returnedOnOrder + cashRefundOnOrder;
          if (paidOnOrder + amountUsd > netOrderTotal + 0.000001) {
            throw new BadRequestException('قيمة الدفعة أكبر من المبلغ المتبقي على الطلب.');
          }
        }

        const payment = await tx.customerPayment.create({
          data: {
            storeId: store.id,
            customerId,
            orderId: dto.orderId ?? null,
            amount: dto.amount,
            currency: dto.currency as any,
            exchangeRateSypPerUsd: rate,
            amountUsdEquivalent: amountUsd,
            amountSypEquivalent: amountSyp,
            method: (dto.method ?? 'CASH') as any,
            note: dto.note?.trim() || null,
            paidAt: dto.paidAt ? new Date(dto.paidAt) : new Date(),
          },
        });

        if (dto.orderId) {
          const [order, payments, returns] = await Promise.all([
            tx.order.findUnique({ where: { id: dto.orderId }, select: { totalUsd: true } }),
            tx.customerPayment.findMany({
              where: { orderId: dto.orderId },
              select: { amountUsdEquivalent: true },
            }),
            tx.salesReturn.findMany({
              where: { orderId: dto.orderId, status: 'RECEIVED' },
              select: { amountUsdEquivalent: true, settlementType: true },
            }),
          ]);
          const returnedUsd = returns.reduce((sum, item) => sum + asNumber(item.amountUsdEquivalent), 0);
          const cashRefundUsd = returns.filter((item) => item.settlementType === 'CASH')
            .reduce((sum, item) => sum + asNumber(item.amountUsdEquivalent), 0);
          const totalUsd = Math.max(0, asNumber(order?.totalUsd) - returnedUsd);
          const paidUsd = Math.max(0, payments.reduce(
            (sum, item) => sum + asNumber(item.amountUsdEquivalent),
            0,
          ) - cashRefundUsd);
          const paymentStatus = totalUsd <= 0.000001
            ? 'PAID'
            : paidUsd <= 0.000001
              ? 'UNPAID'
              : paidUsd + 0.000001 >= totalUsd
                ? 'PAID'
                : 'PARTIALLY_PAID';
          await tx.order.update({
            where: { id: dto.orderId },
            data: { paymentStatus: paymentStatus as any },
          });
        }
        return {
          id: payment.id,
          amount: asNumber(payment.amount),
          currency: payment.currency,
          amountUsdEquivalent: asNumber(payment.amountUsdEquivalent),
          amountSypEquivalent: asNumber(payment.amountSypEquivalent),
          method: payment.method,
          orderId: payment.orderId,
          note: payment.note ?? '',
          paidAt: payment.paidAt.toISOString(),
        };
      },
      { isolationLevel: 'Serializable' },
    );
  }

  private async getStore(user: AccessTokenPayload) {
    const store = await this.prisma.store.findFirst({
      where: { id: user.storeId, organizationId: user.organizationId },
      select: { id: true, exchangeRateSypPerUsd: true },
    });
    if (!store) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');
    return store;
  }

  private async assertPhoneAvailable(storeId: string, rawPhone: string | undefined, exceptId?: string) {
    const phone = rawPhone?.trim();
    if (!phone) return;
    const existing = await this.prisma.customer.findFirst({
      where: {
        storeId,
        phone,
        isActive: true,
        ...(exceptId ? { id: { not: exceptId } } : {}),
      },
      select: { id: true },
    });
    if (existing) throw new ConflictException('رقم الهاتف مسجل لعميل آخر في هذا المتجر.');
  }

  private serializeCustomer(row: any) {
    const orders = row.orders ?? [];
    const payments = row.payments ?? [];
    const salesReturns = (row.salesReturns ?? []).filter((item: any) => item.status === undefined || item.status === 'RECEIVED');
    const grossUsd = orders.reduce((sum: number, order: any) => sum + asNumber(order.totalUsd), 0);
    const grossSyp = orders.reduce((sum: number, order: any) => sum + asNumber(order.totalSyp), 0);
    const returnedUsd = salesReturns.reduce((sum: number, item: any) => sum + asNumber(item.amountUsdEquivalent), 0);
    const returnedSyp = salesReturns.reduce((sum: number, item: any) => sum + asNumber(item.amountSypEquivalent), 0);
    const cashRefunds = salesReturns.filter((item: any) => item.settlementType === 'CASH');
    const cashRefundUsd = cashRefunds.reduce((sum: number, item: any) => sum + asNumber(item.amountUsdEquivalent), 0);
    const cashRefundSyp = cashRefunds.reduce((sum: number, item: any) => sum + asNumber(item.amountSypEquivalent), 0);
    const totalUsd = grossUsd - returnedUsd;
    const totalSyp = grossSyp - returnedSyp;
    const paidUsd = payments.reduce((sum: number, payment: any) => sum + asNumber(payment.amountUsdEquivalent), 0) - cashRefundUsd;
    const paidSyp = payments.reduce((sum: number, payment: any) => sum + asNumber(payment.amountSypEquivalent), 0) - cashRefundSyp;
    const lastOrderAt = orders.reduce((latest: Date | null, order: any) =>
      !latest || order.createdAt > latest ? order.createdAt : latest, null);
    return {
      id: row.id,
      name: row.name,
      phone: row.phone ?? '',
      email: row.email ?? '',
      address: row.address ?? '',
      notes: row.notes ?? '',
      isActive: row.isActive ?? true,
      createdAt: row.createdAt.toISOString(),
      orderCount: orders.length,
      totalPurchasesUsd: round6(totalUsd),
      totalPurchasesSyp: round2(totalSyp),
      returnedUsd: round6(returnedUsd),
      returnedSyp: round2(returnedSyp),
      paidUsd: round6(paidUsd),
      paidSyp: round2(paidSyp),
      balanceUsd: round6(totalUsd - paidUsd),
      balanceSyp: round2(totalSyp - paidSyp),
      lastOrderAt: lastOrderAt?.toISOString() ?? null,
    };
  }

  private optionalText(value?: string): string | null {
    const normalized = value?.trim();
    return normalized ? normalized : null;
  }
}
