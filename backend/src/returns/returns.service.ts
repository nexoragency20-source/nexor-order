import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import type {
  CreateSalesReturnDto,
  ReceiveSalesReturnDto,
  RejectSalesReturnDto,
} from './dto/returns.dto.js';

const asNumber = (value: unknown): number => {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && 'toString' in value) {
    return Number((value as { toString(): string }).toString());
  }
  return Number(value ?? 0);
};
const round6 = (value: number) => Math.round((value + Number.EPSILON) * 1_000_000) / 1_000_000;
const round2 = (value: number) => Math.round((value + Number.EPSILON) * 100) / 100;
const RESERVED_STATUSES = ['REQUESTED', 'RECEIVED'];

@Injectable()
export class ReturnsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AccessTokenPayload) {
    const store = await this.getStore(user);
    const rows = await this.prisma.salesReturn.findMany({
      where: { storeId: store.id },
      include: {
        order: { select: { id: true, orderNumber: true } },
        customer: { select: { id: true, name: true, phone: true } },
        items: { orderBy: { id: 'asc' } },
      },
      orderBy: [{ createdAt: 'desc' }],
      take: 500,
    });
    const received = rows.filter((row) => row.status === 'RECEIVED');
    const requested = rows.filter((row) => row.status === 'REQUESTED');
    return {
      summary: {
        totalCount: rows.length,
        requestedCount: requested.length,
        receivedCount: received.length,
        rejectedCount: rows.filter((row) => row.status === 'REJECTED').length,
        returnedUsd: round6(received.reduce((sum, row) => sum + asNumber(row.amountUsdEquivalent), 0)),
        returnedSyp: round2(received.reduce((sum, row) => sum + asNumber(row.amountSypEquivalent), 0)),
      },
      items: rows.map((row) => this.serialize(row)),
    };
  }

  async eligibleOrders(user: AccessTokenPayload) {
    const store = await this.getStore(user);
    const rows = await this.prisma.order.findMany({
      where: { storeId: store.id, status: { in: ['SHIPPED', 'COMPLETED'] } },
      include: {
        customer: { select: { id: true, name: true, phone: true } },
        items: { orderBy: { id: 'asc' } },
        returns: {
          where: { status: { in: RESERVED_STATUSES as any } },
          include: { items: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 500,
    });
    const result = rows.map((order) => {
      const lines = order.items.map((item) => {
        const alreadyReserved = order.returns.reduce((sum, ret) => sum + ret.items
          .filter((line) => line.orderItemId === item.id)
          .reduce((lineSum, line) => lineSum + asNumber(line.quantity), 0), 0);
        const quantity = asNumber(item.quantity);
        return {
          orderItemId: item.id,
          productId: item.productId ?? '',
          productName: item.productName,
          barcode: item.barcode ?? '',
          quantity,
          reservedQuantity: round6(alreadyReserved),
          returnableQuantity: round6(Math.max(0, quantity - alreadyReserved)),
          unitPriceUsd: asNumber(item.unitPriceUsd),
          unitPriceSyp: asNumber(item.unitPriceSyp),
        };
      }).filter((line) => line.returnableQuantity > 0.000001);
      return {
        id: order.id,
        orderNumber: order.orderNumber,
        customerId: order.customerId ?? '',
        customerName: order.customerNameSnapshot ?? order.customer?.name ?? '',
        customerPhone: order.customerPhoneSnapshot ?? order.customer?.phone ?? '',
        status: order.status,
        createdAt: order.createdAt.toISOString(),
        exchangeRateSypPerUsd: asNumber(order.exchangeRateSypPerUsd),
        subtotalUsd: asNumber(order.subtotalUsd),
        discountUsd: asNumber(order.discountUsd),
        items: lines,
      };
    }).filter((order) => order.items.length > 0);
    return { items: result };
  }

  async create(user: AccessTokenPayload, dto: CreateSalesReturnDto) {
    const store = await this.getStore(user);
    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findFirst({
        where: { id: dto.orderId, storeId: store.id },
        include: {
          items: true,
          returns: {
            where: { status: { in: RESERVED_STATUSES as any } },
            include: { items: true },
          },
        },
      });
      if (!order) throw new NotFoundException('الطلب المحدد غير موجود في هذا المتجر.');
      if (!['SHIPPED', 'COMPLETED'].includes(order.status)) {
        throw new BadRequestException('يمكن إرجاع الطلب بعد شحنه أو إكماله فقط.');
      }
      if (dto.settlementType === 'CUSTOMER_CREDIT' && !order.customerId) {
        throw new BadRequestException('لا يمكن إضافة رصيد للعميل لأن الطلب غير مرتبط بعميل.');
      }
      if (!dto.items?.length) throw new BadRequestException('حدد صنفاً واحداً على الأقل لإرجاعه.');

      const seen = new Set<string>();
      const subtotalUsd = asNumber(order.subtotalUsd);
      const discountUsd = asNumber(order.discountUsd);
      const discountFactor = subtotalUsd > 0 ? Math.max(0, (subtotalUsd - discountUsd) / subtotalUsd) : 1;
      const rate = asNumber(order.exchangeRateSypPerUsd);
      if (!Number.isFinite(rate) || rate <= 0) throw new BadRequestException('سعر الصرف المحفوظ في الطلب غير صالح.');

      const lines: Array<Record<string, unknown>> = [];
      for (const requested of dto.items) {
        if (seen.has(requested.orderItemId)) throw new BadRequestException('لا تكرر الصنف نفسه في طلب المرتجع.');
        seen.add(requested.orderItemId);
        const item = order.items.find((candidate) => candidate.id === requested.orderItemId);
        if (!item) throw new BadRequestException('أحد الأصناف المحددة لا ينتمي إلى الطلب.');
        const quantity = Number(requested.quantity);
        if (!Number.isFinite(quantity) || quantity <= 0 || Math.abs(quantity * 1000 - Math.round(quantity * 1000)) > 0.000001) {
          throw new BadRequestException('كمية المرتجع يجب أن تكون أكبر من صفر وبحد أقصى 3 منازل عشرية.');
        }
        const reserved = order.returns.reduce((sum, ret) => sum + ret.items
          .filter((line) => line.orderItemId === item.id)
          .reduce((lineSum, line) => lineSum + asNumber(line.quantity), 0), 0);
        const available = asNumber(item.quantity) - reserved;
        if (quantity > available + 0.000001) {
          throw new BadRequestException(`الكمية المتاحة للإرجاع من ${item.productName} هي ${Math.max(0, available)} فقط.`);
        }
        if (item.productId) {
          const stockOut = await tx.inventoryMovement.findFirst({
            where: { storeId: store.id, productId: item.productId, referenceType: 'ORDER', referenceId: order.id, type: 'SALE_OUT' },
            select: { id: true },
          });
          if (!stockOut) throw new BadRequestException(`لا توجد حركة صرف مخزون مثبتة للصنف ${item.productName} في هذا الطلب.`);
        }
        const unitPriceUsd = asNumber(item.unitPriceUsd);
        const unitPriceSyp = asNumber(item.unitPriceSyp);
        const lineTotalUsd = round6(quantity * unitPriceUsd * discountFactor);
        const lineTotalSyp = round2(quantity * unitPriceSyp * discountFactor);
        lines.push({
          orderItemId: item.id,
          productId: item.productId,
          productName: item.productName,
          barcode: item.barcode,
          quantity,
          unitPriceUsd,
          unitPriceSyp,
          unitCostUsd: asNumber(item.unitCostUsd),
          lineTotalUsd,
          lineTotalSyp,
        });
      }

      const amountUsdEquivalent = round6(lines.reduce((sum, line) => sum + asNumber(line.lineTotalUsd), 0));
      const amountSypEquivalent = round2(lines.reduce((sum, line) => sum + asNumber(line.lineTotalSyp), 0));
      if (amountUsdEquivalent <= 0 || amountSypEquivalent <= 0) {
        throw new BadRequestException('قيمة المرتجع تساوي صفراً. تحقق من أسعار الأصناف والخصم.');
      }
      const currency = dto.currency;
      const amount = currency === 'USD' ? amountUsdEquivalent : amountSypEquivalent;
      const returnNumber = this.newReturnNumber();
      const row = await tx.salesReturn.create({
        data: {
          storeId: store.id,
          orderId: order.id,
          customerId: order.customerId,
          returnNumber,
          status: 'REQUESTED',
          settlementType: dto.settlementType as any,
          currency: currency as any,
          amount,
          exchangeRateSypPerUsd: rate,
          amountUsdEquivalent,
          amountSypEquivalent,
          reason: dto.reason?.trim() || null,
          notes: dto.notes?.trim() || null,
          items: { create: lines as any },
        },
        include: {
          order: { select: { id: true, orderNumber: true } },
          customer: { select: { id: true, name: true, phone: true } },
          items: { orderBy: { id: 'asc' } },
        },
      });
      return this.serialize(row);
    }, { isolationLevel: 'Serializable' });
  }

  async receive(user: AccessTokenPayload, id: string, dto: ReceiveSalesReturnDto) {
    const store = await this.getStore(user);
    return this.prisma.$transaction(async (tx) => {
      const row = await tx.salesReturn.findFirst({
        where: { id, storeId: store.id },
        include: {
          order: { include: { payments: true } },
          customer: { select: { id: true, name: true } },
          items: true,
        },
      });
      if (!row) throw new NotFoundException('سجل المرتجع غير موجود.');
      if (row.status === 'RECEIVED') return this.serialize(row);
      if (row.status !== 'REQUESTED') throw new BadRequestException('لا يمكن استلام مرتجع مرفوض.');

      const rate = asNumber(row.exchangeRateSypPerUsd);
      if (row.settlementType === 'CASH') {
        const paidUsd = row.order.payments.reduce(
          (sum, payment) => sum + asNumber(payment.amountUsdEquivalent),
          0,
        );
        const previousCashRefunds = await tx.salesReturn.aggregate({
          where: {
            storeId: store.id,
            orderId: row.orderId,
            status: 'RECEIVED',
            settlementType: 'CASH',
          },
          _sum: { amountUsdEquivalent: true },
        });
        const alreadyRefundedUsd = asNumber(previousCashRefunds._sum.amountUsdEquivalent);
        if (alreadyRefundedUsd + asNumber(row.amountUsdEquivalent) > paidUsd + 0.000001) {
          throw new BadRequestException(
            'لا يمكن رد مبلغ نقدي أكبر من إجمالي ما تم قبضه فعلياً على هذا الطلب. استخدم رصيداً دائناً للعميل عند الحاجة.',
          );
        }
      }
      for (const item of row.items) {
        if (!item.productId) continue;
        const changed = await tx.product.updateMany({
          where: { id: item.productId, storeId: store.id },
          data: { stockQuantity: { increment: item.quantity } },
        });
        if (changed.count !== 1) throw new NotFoundException(`الصنف ${item.productName} لم يعد موجوداً في المتجر؛ لم يتم اعتماد المرتجع.`);
        await tx.inventoryMovement.create({
          data: {
            storeId: store.id,
            productId: item.productId,
            type: 'CUSTOMER_RETURN_IN',
            quantity: item.quantity,
            unitCostUsd: item.unitCostUsd,
            unitCostSyp: round2(asNumber(item.unitCostUsd) * rate),
            referenceType: 'SALES_RETURN',
            referenceId: row.id,
            note: `استلام مرتجع ${row.returnNumber} للطلب ${row.order.orderNumber}`,
          },
        });
      }

      const receivedAt = dto.receivedAt ? this.parseDate(dto.receivedAt) : new Date();
      if (row.settlementType === 'CASH') {
        await tx.financeTransaction.create({
          data: {
            storeId: store.id,
            type: 'EXPENSE',
            currency: row.currency,
            amount: row.amount,
            exchangeRateSypPerUsd: row.exchangeRateSypPerUsd,
            amountUsdEquivalent: row.amountUsdEquivalent,
            amountSypEquivalent: row.amountSypEquivalent,
            category: 'مرتجعات المبيعات',
            description: `رد نقدي للعميل — مرتجع ${row.returnNumber}`,
            note: dto.note?.trim() || row.reason || null,
            referenceType: 'SALES_RETURN',
            referenceId: row.id,
            occurredAt: receivedAt,
          },
        });
      }

      await tx.salesReturn.update({
        where: { id: row.id },
        data: {
          status: 'RECEIVED',
          receivedAt,
          ...(dto.note?.trim() ? { notes: row.notes ? `${row.notes} | ${dto.note.trim()}` : dto.note.trim() } : {}),
        },
      });

      const receivedReturns = await tx.salesReturn.findMany({
        where: { storeId: store.id, orderId: row.orderId, status: 'RECEIVED' },
        select: { amountUsdEquivalent: true, settlementType: true },
      });
      const returnedUsd = receivedReturns.reduce((sum, ret) => sum + asNumber(ret.amountUsdEquivalent), 0);
      const cashRefundUsd = receivedReturns
        .filter((ret) => ret.settlementType === 'CASH')
        .reduce((sum, ret) => sum + asNumber(ret.amountUsdEquivalent), 0);
      const paymentTotalUsd = row.order.payments.reduce((sum, payment) => sum + asNumber(payment.amountUsdEquivalent), 0);
      const netTotalUsd = Math.max(0, asNumber(row.order.totalUsd) - returnedUsd);
      const netPaidUsd = Math.max(0, paymentTotalUsd - cashRefundUsd);
      const paymentStatus = netTotalUsd <= 0.000001
        ? 'PAID'
        : netPaidUsd <= 0.000001
          ? 'UNPAID'
          : netPaidUsd + 0.000001 >= netTotalUsd
            ? 'PAID'
            : 'PARTIALLY_PAID';
      await tx.order.update({ where: { id: row.orderId }, data: { paymentStatus: paymentStatus as any } });

      const updated = await tx.salesReturn.findFirst({
        where: { id: row.id, storeId: store.id },
        include: {
          order: { select: { id: true, orderNumber: true } },
          customer: { select: { id: true, name: true, phone: true } },
          items: { orderBy: { id: 'asc' } },
        },
      });
      if (!updated) throw new NotFoundException('تعذر إعادة تحميل سجل المرتجع بعد اعتماده.');
      return this.serialize(updated);
    }, { isolationLevel: 'Serializable' });
  }

  async reject(user: AccessTokenPayload, id: string, dto: RejectSalesReturnDto) {
    const store = await this.getStore(user);
    return this.prisma.$transaction(async (tx) => {
      const row = await tx.salesReturn.findFirst({
        where: { id, storeId: store.id },
        include: {
          order: { select: { id: true, orderNumber: true } },
          customer: { select: { id: true, name: true, phone: true } },
          items: { orderBy: { id: 'asc' } },
        },
      });
      if (!row) throw new NotFoundException('سجل المرتجع غير موجود.');
      if (row.status === 'REJECTED') return this.serialize(row);
      if (row.status !== 'REQUESTED') throw new BadRequestException('لا يمكن رفض مرتجع تم استلامه واعتماده.');
      const note = dto.reason?.trim();
      const updated = await tx.salesReturn.update({
        where: { id: row.id },
        data: {
          status: 'REJECTED',
          ...(note ? { notes: row.notes ? `${row.notes} | سبب الرفض: ${note}` : `سبب الرفض: ${note}` } : {}),
        },
        include: {
          order: { select: { id: true, orderNumber: true } },
          customer: { select: { id: true, name: true, phone: true } },
          items: { orderBy: { id: 'asc' } },
        },
      });
      return this.serialize(updated);
    }, { isolationLevel: 'Serializable' });
  }

  private async getStore(user: AccessTokenPayload) {
    const store = await this.prisma.store.findFirst({
      where: { id: user.storeId, organizationId: user.organizationId },
      select: { id: true },
    });
    if (!store) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');
    return store;
  }

  private parseDate(value: string): Date {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) throw new BadRequestException('تاريخ استلام المرتجع غير صالح.');
    return date;
  }

  private newReturnNumber() {
    const time = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).slice(2, 6).toUpperCase();
    return `RET-${time}-${random}`;
  }

  private serialize(row: any) {
    return {
      id: row.id,
      returnNumber: row.returnNumber,
      status: row.status,
      orderId: row.orderId,
      orderNumber: row.order?.orderNumber ?? '',
      customerId: row.customerId ?? '',
      customerName: row.customer?.name ?? '',
      customerPhone: row.customer?.phone ?? '',
      settlementType: row.settlementType,
      currency: row.currency,
      amount: asNumber(row.amount),
      amountUsdEquivalent: asNumber(row.amountUsdEquivalent),
      amountSypEquivalent: asNumber(row.amountSypEquivalent),
      exchangeRateSypPerUsd: asNumber(row.exchangeRateSypPerUsd),
      reason: row.reason ?? '',
      notes: row.notes ?? '',
      requestedAt: row.requestedAt.toISOString(),
      receivedAt: row.receivedAt?.toISOString() ?? null,
      createdAt: row.createdAt.toISOString(),
      items: (row.items ?? []).map((item: any) => ({
        id: item.id,
        orderItemId: item.orderItemId,
        productId: item.productId ?? '',
        productName: item.productName,
        barcode: item.barcode ?? '',
        quantity: asNumber(item.quantity),
        unitPriceUsd: asNumber(item.unitPriceUsd),
        unitPriceSyp: asNumber(item.unitPriceSyp),
        lineTotalUsd: asNumber(item.lineTotalUsd),
        lineTotalSyp: asNumber(item.lineTotalSyp),
      })),
    };
  }
}
