import { randomUUID } from 'node:crypto';
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import { FinanceTransactionDto, FinanceTransferDto } from './dto/finance.dto.js';

const CASH_METHODS = ['CASH', 'CASH_ON_DELIVERY'];
const INCOMING_TYPES = ['INCOME', 'DEPOSIT', 'OPENING_BALANCE', 'TRANSFER_IN'];
const OUTGOING_TYPES = ['EXPENSE', 'WITHDRAWAL', 'TRANSFER_OUT'];

function asNumber(value: unknown): number {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && 'toString' in value) {
    return Number(value.toString());
  }
  return Number(value ?? 0);
}

function roundUsd(value: number): number {
  return Math.round((value + Number.EPSILON) * 1_000_000) / 1_000_000;
}

function roundSyp(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

@Injectable()
export class FinanceService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(user: AccessTokenPayload, date?: string) {
    const store = await this.getStore(user);
    const selectedDate = date ?? this.todayLocalString();
    const { start, end } = this.dayBounds(selectedDate);

    const [manualToday, customerPaymentsToday, supplierPaymentsToday,
      manualAll, customerPaymentsAll, supplierPaymentsAll] = await Promise.all([
      this.prisma.financeTransaction.findMany({
        where: { storeId: store.id, occurredAt: { gte: start, lt: end } },
        orderBy: [{ occurredAt: 'desc' }, { createdAt: 'desc' }],
      }),
      this.prisma.customerPayment.findMany({
        where: {
          storeId: store.id,
          method: { in: CASH_METHODS as any },
          paidAt: { gte: start, lt: end },
        },
        include: {
          customer: { select: { name: true } },
          order: { select: { orderNumber: true } },
        },
        orderBy: { paidAt: 'desc' },
      }),
      this.prisma.supplierPayment.findMany({
        where: {
          storeId: store.id,
          method: 'CASH',
          paidAt: { gte: start, lt: end },
        },
        include: {
          supplier: { select: { name: true } },
          purchaseInvoice: { select: { invoiceNumber: true } },
        },
        orderBy: { paidAt: 'desc' },
      }),
      this.prisma.financeTransaction.findMany({
        where: { storeId: store.id },
        select: { type: true, currency: true, amount: true },
      }),
      this.prisma.customerPayment.findMany({
        where: { storeId: store.id, method: { in: CASH_METHODS as any } },
        select: { amount: true, currency: true },
      }),
      this.prisma.supplierPayment.findMany({
        where: { storeId: store.id, method: 'CASH' },
        select: { amount: true, currency: true },
      }),
    ]);

    const items = [
      ...manualToday.map((row) => this.serializeManual(row)),
      ...customerPaymentsToday.map((row) => this.serializeCustomerPayment(row)),
      ...supplierPaymentsToday.map((row) => this.serializeSupplierPayment(row)),
    ].sort((a, b) => b.occurredAt.localeCompare(a.occurredAt));

    let cashBalanceUsd = 0;
    let cashBalanceSyp = 0;
    for (const row of manualAll) {
      const signed = this.signedAmount(row.type, asNumber(row.amount));
      if (row.currency === 'USD') cashBalanceUsd += signed;
      else cashBalanceSyp += signed;
    }
    for (const row of customerPaymentsAll) {
      const amount = asNumber(row.amount);
      if (row.currency === 'USD') cashBalanceUsd += amount;
      else cashBalanceSyp += amount;
    }
    for (const row of supplierPaymentsAll) {
      const amount = asNumber(row.amount);
      if (row.currency === 'USD') cashBalanceUsd -= amount;
      else cashBalanceSyp -= amount;
    }

    const today = {
      receiptsUsdEquivalent: 0,
      paymentsUsdEquivalent: 0,
      receiptsSypEquivalent: 0,
      paymentsSypEquivalent: 0,
      transfersUsdEquivalent: 0,
    };
    for (const item of items) {
      if (['INCOME', 'DEPOSIT'].includes(item.type)) {
        today.receiptsUsdEquivalent += item.amountUsdEquivalent;
        today.receiptsSypEquivalent += item.amountSypEquivalent;
      } else if (['EXPENSE', 'WITHDRAWAL'].includes(item.type)) {
        today.paymentsUsdEquivalent += item.amountUsdEquivalent;
        today.paymentsSypEquivalent += item.amountSypEquivalent;
      } else if (item.type === 'TRANSFER_OUT') {
        today.transfersUsdEquivalent += item.amountUsdEquivalent;
      }
    }

    const rate = asNumber(store.exchangeRateSypPerUsd);
    return {
      date: selectedDate,
      exchangeRateSypPerUsd: rate,
      summary: {
        cashBalanceUsd: roundUsd(cashBalanceUsd),
        cashBalanceSyp: roundSyp(cashBalanceSyp),
        cashBalanceUsdEquivalent: roundUsd(cashBalanceUsd + cashBalanceSyp / rate),
        cashBalanceSypEquivalent: roundSyp(cashBalanceSyp + cashBalanceUsd * rate),
        todayReceiptsUsdEquivalent: roundUsd(today.receiptsUsdEquivalent),
        todayPaymentsUsdEquivalent: roundUsd(today.paymentsUsdEquivalent),
        todayReceiptsSypEquivalent: roundSyp(today.receiptsSypEquivalent),
        todayPaymentsSypEquivalent: roundSyp(today.paymentsSypEquivalent),
        todayTransfersUsdEquivalent: roundUsd(today.transfersUsdEquivalent),
        todayNetUsdEquivalent: roundUsd(
          today.receiptsUsdEquivalent - today.paymentsUsdEquivalent,
        ),
        todayTransactionCount: items.length,
      },
      items,
    };
  }

  async createTransaction(user: AccessTokenPayload, dto: FinanceTransactionDto) {
    const store = await this.getStore(user);
    const occurredAt = this.parseDate(dto.occurredAt);
    const rate = asNumber(store.exchangeRateSypPerUsd);
    const amountUsd = dto.currency === 'USD' ? dto.amount : roundUsd(dto.amount / rate);
    const amountSyp = dto.currency === 'SYP' ? roundSyp(dto.amount) : roundSyp(dto.amount * rate);

    const row = await this.prisma.financeTransaction.create({
      data: {
        storeId: store.id,
        type: dto.type as any,
        currency: dto.currency as any,
        amount: dto.amount,
        exchangeRateSypPerUsd: rate,
        amountUsdEquivalent: amountUsd,
        amountSypEquivalent: amountSyp,
        category: dto.category.trim(),
        description: dto.description.trim(),
        note: dto.note?.trim() || null,
        occurredAt,
      },
    });
    return this.serializeManual(row);
  }

  async createTransfer(user: AccessTokenPayload, dto: FinanceTransferDto) {
    if (dto.fromCurrency === dto.toCurrency) {
      throw new BadRequestException('اختر عملتين مختلفتين للتحويل.');
    }
    if (!Number.isFinite(dto.fromAmount) || !Number.isFinite(dto.toAmount) ||
        dto.fromAmount <= 0 || dto.toAmount <= 0) {
      throw new BadRequestException('أدخل مبالغ تحويل صحيحة وأكبر من صفر.');
    }

    const store = await this.getStore(user);
    const occurredAt = this.parseDate(dto.occurredAt);
    const transferRate = dto.fromCurrency === 'USD'
      ? dto.toAmount / dto.fromAmount
      : dto.fromAmount / dto.toAmount;
    if (!Number.isFinite(transferRate) || transferRate <= 0) {
      throw new BadRequestException('سعر التحويل الناتج غير صحيح.');
    }

    const groupId = randomUUID();
    const fromEquivalent = this.equivalents(dto.fromAmount, dto.fromCurrency, transferRate);
    const toEquivalent = this.equivalents(dto.toAmount, dto.toCurrency, transferRate);
    const description = dto.description.trim();

    const created = await this.prisma.$transaction(async (tx) => {
      const outgoing = await tx.financeTransaction.create({
        data: {
          storeId: store.id,
          type: 'TRANSFER_OUT',
          currency: dto.fromCurrency as any,
          amount: dto.fromAmount,
          exchangeRateSypPerUsd: transferRate,
          amountUsdEquivalent: fromEquivalent.usd,
          amountSypEquivalent: fromEquivalent.syp,
          category: 'تحويل بين العملات',
          description: `${description} — صادر`,
          note: dto.note?.trim() || null,
          transferGroupId: groupId,
          occurredAt,
        },
      });
      const incoming = await tx.financeTransaction.create({
        data: {
          storeId: store.id,
          type: 'TRANSFER_IN',
          currency: dto.toCurrency as any,
          amount: dto.toAmount,
          exchangeRateSypPerUsd: transferRate,
          amountUsdEquivalent: toEquivalent.usd,
          amountSypEquivalent: toEquivalent.syp,
          category: 'تحويل بين العملات',
          description: `${description} — وارد`,
          note: dto.note?.trim() || null,
          transferGroupId: groupId,
          occurredAt,
        },
      });
      return [outgoing, incoming];
    }, { isolationLevel: 'Serializable' });

    return { transferGroupId: groupId, items: created.map((row) => this.serializeManual(row)) };
  }

  private async getStore(user: AccessTokenPayload) {
    const store = await this.prisma.store.findFirst({
      where: { id: user.storeId, organizationId: user.organizationId },
      select: { id: true, exchangeRateSypPerUsd: true },
    });
    if (!store) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');
    const rate = asNumber(store.exchangeRateSypPerUsd);
    if (!Number.isFinite(rate) || rate <= 0) {
      throw new BadRequestException('سعر صرف المتجر غير صالح.');
    }
    return store;
  }

  private serializeManual(row: any) {
    return {
      id: row.id,
      type: row.type,
      currency: row.currency,
      amount: asNumber(row.amount),
      amountUsdEquivalent: asNumber(row.amountUsdEquivalent),
      amountSypEquivalent: asNumber(row.amountSypEquivalent),
      exchangeRateSypPerUsd: asNumber(row.exchangeRateSypPerUsd),
      category: row.category,
      description: row.description,
      note: row.note ?? '',
      referenceType: row.referenceType ?? '',
      referenceId: row.referenceId ?? '',
      transferGroupId: row.transferGroupId ?? '',
      occurredAt: row.occurredAt.toISOString(),
      isAutomatic: row.referenceType === 'SALES_RETURN',
      canEdit: false,
    };
  }

  private serializeCustomerPayment(row: any) {
    const orderSuffix = row.order?.orderNumber ? ` — طلب ${row.order.orderNumber}` : '';
    return {
      id: `CUSTOMER-${row.id}`,
      type: 'INCOME',
      currency: row.currency,
      amount: asNumber(row.amount),
      amountUsdEquivalent: asNumber(row.amountUsdEquivalent),
      amountSypEquivalent: asNumber(row.amountSypEquivalent),
      exchangeRateSypPerUsd: asNumber(row.exchangeRateSypPerUsd),
      category: 'دفعات العملاء',
      description: `قبض من العميل — ${row.customer?.name ?? 'عميل'}${orderSuffix}`,
      note: row.note ?? '',
      referenceType: 'CUSTOMER_PAYMENT',
      referenceId: row.id,
      transferGroupId: '',
      occurredAt: row.paidAt.toISOString(),
      method: row.method,
      isAutomatic: true,
      canEdit: false,
    };
  }

  private serializeSupplierPayment(row: any) {
    const invoiceSuffix = row.purchaseInvoice?.invoiceNumber
      ? ` — فاتورة ${row.purchaseInvoice.invoiceNumber}`
      : '';
    return {
      id: `SUPPLIER-${row.id}`,
      type: 'EXPENSE',
      currency: row.currency,
      amount: asNumber(row.amount),
      amountUsdEquivalent: asNumber(row.amountUsdEquivalent),
      amountSypEquivalent: asNumber(row.amountSypEquivalent),
      exchangeRateSypPerUsd: asNumber(row.exchangeRateSypPerUsd),
      category: 'دفعات الموردين',
      description: `دفع إلى المورد — ${row.supplier?.name ?? 'مورد'}${invoiceSuffix}`,
      note: row.note ?? '',
      referenceType: 'SUPPLIER_PAYMENT',
      referenceId: row.id,
      transferGroupId: '',
      occurredAt: row.paidAt.toISOString(),
      method: row.method,
      isAutomatic: true,
      canEdit: false,
    };
  }

  private signedAmount(type: string, amount: number): number {
    if (INCOMING_TYPES.includes(type)) return amount;
    if (OUTGOING_TYPES.includes(type)) return -amount;
    return 0;
  }

  private equivalents(amount: number, currency: string, rate: number) {
    if (currency === 'USD') {
      return { usd: roundUsd(amount), syp: roundSyp(amount * rate) };
    }
    return { usd: roundUsd(amount / rate), syp: roundSyp(amount) };
  }

  private parseDate(value?: string): Date {
    if (!value) return new Date();
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException('تاريخ الحركة غير صالح.');
    }
    return date;
  }

  private todayLocalString(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = `${now.getMonth() + 1}`.padStart(2, '0');
    const day = `${now.getDate()}`.padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private dayBounds(value: string) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw new BadRequestException('صيغة التاريخ يجب أن تكون YYYY-MM-DD.');
    }
    const [year, month, day] = value.split('-').map(Number);
    const start = new Date(year, month - 1, day, 0, 0, 0, 0);
    if (start.getFullYear() !== year || start.getMonth() !== month - 1 || start.getDate() !== day) {
      throw new BadRequestException('التاريخ المحدد غير صالح.');
    }
    const end = new Date(year, month - 1, day + 1, 0, 0, 0, 0);
    return { start, end };
  }
}
