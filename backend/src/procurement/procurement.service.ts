import {
  ConflictException,
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AccessTokenPayload } from '../auth/interfaces/access-token-payload.interface.js';
import type {
  CreatePurchaseDto,
  SupplierDto,
  SupplierPaymentDto,
} from './dto/procurement.dto.js';

const asNumber = (value: unknown): number => {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && 'toString' in value) {
    return Number((value as { toString(): string }).toString());
  }
  return Number(value ?? 0);
};

@Injectable()
export class ProcurementService {
  constructor(private readonly prisma: PrismaService) {}

  async listSuppliers(user: AccessTokenPayload) {
    const store = await this.getStore(user);
    const rows = await this.prisma.supplier.findMany({
      where: { storeId: store.id },
      include: {
        purchaseInvoices: {
          where: { status: 'RECEIVED' },
          select: { totalUsd: true },
        },
        payments: { select: { amountUsdEquivalent: true } },
      },
      orderBy: [{ isActive: 'desc' }, { createdAt: 'desc' }],
    });

    const rate = asNumber(store.exchangeRateSypPerUsd);
    return {
      exchangeRateSypPerUsd: rate,
      items: rows.map((row) => {
        const purchasesUsd = row.purchaseInvoices.reduce(
          (sum, item) => sum + asNumber(item.totalUsd),
          0,
        );
        const paidUsd = row.payments.reduce(
          (sum, item) => sum + asNumber(item.amountUsdEquivalent),
          0,
        );
        const balanceUsd = purchasesUsd - paidUsd;
        return {
          id: row.id,
          name: row.name,
          phone: row.phone ?? '',
          email: row.email ?? '',
          address: row.address ?? '',
          note: row.notes ?? '',
          isActive: row.isActive,
          createdAt: row.createdAt.toISOString(),
          totalPurchasesUsd: purchasesUsd,
          totalPaidUsd: paidUsd,
          balanceUsd,
          balanceSyp: balanceUsd * rate,
        };
      }),
    };
  }

  async createSupplier(user: AccessTokenPayload, dto: SupplierDto) {
    const store = await this.getStore(user);
    const row = await this.prisma.supplier.create({
      data: {
        storeId: store.id,
        name: dto.name.trim(),
        phone: dto.phone?.trim() || null,
        email: dto.email?.trim() || null,
        address: dto.address?.trim() || null,
        notes: dto.notes?.trim() || null,
      },
    });
    return this.serializeSupplier(row);
  }

  async updateSupplier(user: AccessTokenPayload, id: string, dto: SupplierDto) {
    const store = await this.getStore(user);
    const existing = await this.prisma.supplier.findFirst({
      where: { id, storeId: store.id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('المورد غير موجود في هذا المتجر.');

    const row = await this.prisma.supplier.update({
      where: { id },
      data: {
        name: dto.name.trim(),
        phone: dto.phone?.trim() || null,
        email: dto.email?.trim() || null,
        address: dto.address?.trim() || null,
        notes: dto.notes?.trim() || null,
      },
    });
    return this.serializeSupplier(row);
  }

  async archiveSupplier(user: AccessTokenPayload, id: string) {
    const store = await this.getStore(user);
    const existing = await this.prisma.supplier.findFirst({
      where: { id, storeId: store.id },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('المورد غير موجود في هذا المتجر.');
    const row = await this.prisma.supplier.update({
      where: { id },
      data: { isActive: false },
    });
    return this.serializeSupplier(row);
  }

  async listSupplierPayments(user: AccessTokenPayload) {
    const store = await this.getStore(user);
    const rows = await this.prisma.supplierPayment.findMany({
      where: { storeId: store.id },
      include: {
        supplier: { select: { name: true } },
        purchaseInvoice: { select: { invoiceNumber: true } },
      },
      orderBy: { paidAt: 'desc' },
    });
    return {
      items: rows.map((row) => this.serializePayment(row)),
    };
  }

  async recordSupplierPayment(
    user: AccessTokenPayload,
    supplierId: string,
    dto: SupplierPaymentDto,
  ) {
    const store = await this.getStore(user);
    return this.prisma.$transaction(
      async (tx) => {
        const transactionStore = await tx.store.findFirst({
          where: { id: store.id, organizationId: user.organizationId },
          select: { id: true, exchangeRateSypPerUsd: true },
        });
        if (!transactionStore) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');
        const supplier = await tx.supplier.findFirst({
          where: { id: supplierId, storeId: store.id, isActive: true },
          select: { id: true, name: true },
        });
        if (!supplier) throw new NotFoundException('المورد غير موجود أو مؤرشف.');

        const rate = asNumber(transactionStore.exchangeRateSypPerUsd);
        const amountUsd = dto.currency === 'USD' ? dto.amount : dto.amount / rate;
        const amountSyp = dto.currency === 'SYP' ? dto.amount : dto.amount * rate;

        if (dto.purchaseInvoiceId) {
          const invoice = await tx.purchaseInvoice.findFirst({
            where: {
              id: dto.purchaseInvoiceId,
              storeId: store.id,
              supplierId,
              status: 'RECEIVED',
            },
            include: { payments: { select: { amountUsdEquivalent: true } } },
          });
          if (!invoice) {
            throw new NotFoundException('فاتورة الشراء غير موجودة لهذا المورد.');
          }
          const paidUsd = invoice.payments.reduce(
            (sum, payment) => sum + asNumber(payment.amountUsdEquivalent),
            0,
          );
          const outstandingUsd = asNumber(invoice.totalUsd) - paidUsd;
          if (amountUsd > outstandingUsd + 0.000001) {
            throw new BadRequestException('قيمة الدفعة أكبر من المبلغ المتبقي على الفاتورة.');
          }
        }

        const row = await tx.supplierPayment.create({
          data: {
            storeId: store.id,
            supplierId,
            purchaseInvoiceId: dto.purchaseInvoiceId || null,
            amount: dto.amount,
            currency: dto.currency,
            exchangeRateSypPerUsd: rate,
            amountUsdEquivalent: amountUsd,
            amountSypEquivalent: amountSyp,
            method: 'CASH',
            note: dto.note?.trim() || null,
          },
          include: {
            supplier: { select: { name: true } },
            purchaseInvoice: { select: { invoiceNumber: true } },
          },
        });
        return this.serializePayment(row);
      },
      { isolationLevel: 'Serializable' },
    );
  }

  async listPurchases(user: AccessTokenPayload) {
    const store = await this.getStore(user);
    const rows = await this.prisma.purchaseInvoice.findMany({
      where: { storeId: store.id },
      include: {
        supplier: { select: { id: true, name: true } },
        items: { orderBy: { id: 'asc' } },
        payments: { select: { amountUsdEquivalent: true } },
      },
      orderBy: { purchasedAt: 'desc' },
    });
    return { items: rows.map((row) => this.serializePurchase(row)) };
  }

  async createPurchase(user: AccessTokenPayload, dto: CreatePurchaseDto) {
    const store = await this.getStore(user);

    try {
      const created = await this.prisma.$transaction(
        async (tx) => {
          const transactionStore = await tx.store.findFirst({
            where: { id: store.id, organizationId: user.organizationId },
            select: { id: true, exchangeRateSypPerUsd: true },
          });
          if (!transactionStore) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');
          const rate = asNumber(transactionStore.exchangeRateSypPerUsd);
          const supplier = await tx.supplier.findFirst({
            where: { id: dto.supplierId, storeId: store.id, isActive: true },
            select: { id: true, name: true },
          });
          if (!supplier) throw new NotFoundException('اختر مورداً فعالاً من هذا المتجر.');

          const products = new Map<string, any>();
          for (const line of dto.items) {
            if (!products.has(line.productId)) {
              const product = await tx.product.findFirst({
                where: { id: line.productId, storeId: store.id, isActive: true },
                select: {
                  id: true,
                  name: true,
                  barcode: true,
                  stockQuantity: true,
                  purchasePriceUsd: true,
                },
              });
              if (!product) {
                throw new NotFoundException('أحد المنتجات غير موجود أو غير فعال في هذا المتجر.');
              }
              products.set(line.productId, product);
            }
          }

          const invoiceLines = dto.items.map((line) => {
            const product = products.get(line.productId);
            const lineTotalUsd = line.quantity * line.unitCostUsd;
            const lineTotalSyp = line.quantity * line.unitCostSyp;
            return {
              productId: product.id,
              productName: product.name,
              barcode: product.barcode ?? null,
              quantity: line.quantity,
              unitCostUsd: line.unitCostUsd,
              unitCostSyp: line.unitCostSyp,
              lineTotalUsd,
              lineTotalSyp,
            };
          });

          const totalUsd = invoiceLines.reduce((sum, line) => sum + line.lineTotalUsd, 0);
          const totalSyp = invoiceLines.reduce((sum, line) => sum + line.lineTotalSyp, 0);
          const initialAmount = dto.initialPaymentAmount ?? 0;
          const initialCurrency = dto.initialPaymentCurrency ?? 'USD';
          if (!Number.isFinite(initialAmount) || initialAmount < 0) {
            throw new BadRequestException('قيمة الدفعة الأولى غير صحيحة.');
          }
          const initialUsd = initialCurrency === 'USD' ? initialAmount : initialAmount / rate;
          const initialSyp = initialCurrency === 'SYP' ? initialAmount : initialAmount * rate;
          if (initialUsd > totalUsd + 0.000001) {
            throw new BadRequestException('الدفعة الأولى أكبر من إجمالي الفاتورة.');
          }

          const invoice = await tx.purchaseInvoice.create({
            data: {
              storeId: store.id,
              supplierId: supplier.id,
              invoiceNumber: dto.invoiceNumber.trim(),
              status: 'RECEIVED',
              exchangeRateSypPerUsd: rate,
              subtotalUsd: totalUsd,
              totalUsd,
              totalSyp,
              notes: dto.note?.trim() || null,
              purchasedAt: new Date(),
              receivedAt: new Date(),
              items: { create: invoiceLines },
            },
          });

          // Apply stock once per product, with a weighted average USD purchase cost.
          const grouped = new Map<string, { quantity: number; totalCostUsd: number; totalCostSyp: number }>();
          for (const line of invoiceLines) {
            const current = grouped.get(line.productId) ?? {
              quantity: 0,
              totalCostUsd: 0,
              totalCostSyp: 0,
            };
            current.quantity += line.quantity;
            current.totalCostUsd += line.lineTotalUsd;
            current.totalCostSyp += line.lineTotalSyp;
            grouped.set(line.productId, current);
          }

          for (const [productId, received] of grouped.entries()) {
            const product = products.get(productId);
            const oldQuantity = asNumber(product.stockQuantity);
            const newQuantity = oldQuantity + received.quantity;
            const oldCostUsd = asNumber(product.purchasePriceUsd);
            const weightedCostUsd = newQuantity > 0
              ? ((oldQuantity * oldCostUsd) + received.totalCostUsd) / newQuantity
              : 0;
            const averageIncomingUsd = received.quantity > 0
              ? received.totalCostUsd / received.quantity
              : 0;
            const averageIncomingSyp = received.quantity > 0
              ? received.totalCostSyp / received.quantity
              : 0;

            await tx.product.update({
              where: { id: productId },
              data: {
                stockQuantity: newQuantity,
                purchasePriceUsd: weightedCostUsd,
              },
            });
            await tx.inventoryMovement.create({
              data: {
                storeId: store.id,
                productId,
                type: 'PURCHASE_IN',
                quantity: received.quantity,
                unitCostUsd: averageIncomingUsd,
                unitCostSyp: averageIncomingSyp,
                referenceType: 'PURCHASE_INVOICE',
                referenceId: invoice.id,
                note: `استلام فاتورة شراء ${dto.invoiceNumber.trim()}`,
              },
            });
          }

          if (initialAmount > 0) {
            await tx.supplierPayment.create({
              data: {
                storeId: store.id,
                supplierId: supplier.id,
                purchaseInvoiceId: invoice.id,
                amount: initialAmount,
                currency: initialCurrency,
                exchangeRateSypPerUsd: rate,
                amountUsdEquivalent: initialUsd,
                amountSypEquivalent: initialSyp,
                method: 'CASH',
                note: 'دفعة عند تسجيل فاتورة الشراء',
              },
            });
          }

          return tx.purchaseInvoice.findUniqueOrThrow({
            where: { id: invoice.id },
            include: {
              supplier: { select: { id: true, name: true } },
              items: { orderBy: { id: 'asc' } },
              payments: { select: { amountUsdEquivalent: true } },
            },
          });
        },
        { isolationLevel: 'Serializable' },
      );
      return this.serializePurchase(created);
    } catch (error) {
      if (this.isUniqueConflict(error)) {
        throw new ConflictException('رقم فاتورة المورد مسجل مسبقاً في هذا المتجر.');
      }
      throw error;
    }
  }

  private async getStore(user: AccessTokenPayload) {
    const store = await this.prisma.store.findFirst({
      where: { id: user.storeId, organizationId: user.organizationId },
      select: { id: true, exchangeRateSypPerUsd: true },
    });
    if (!store) throw new NotFoundException('المتجر المرتبط بالجلسة غير موجود.');
    return store;
  }

  private serializeSupplier(row: any) {
    return {
      id: row.id,
      name: row.name,
      phone: row.phone ?? '',
      email: row.email ?? '',
      address: row.address ?? '',
      note: row.notes ?? '',
      isActive: row.isActive,
      createdAt: row.createdAt.toISOString(),
    };
  }

  private serializePayment(row: any) {
    return {
      id: row.id,
      supplierId: row.supplierId,
      supplierNameSnapshot: row.supplier?.name ?? '',
      purchaseId: row.purchaseInvoiceId ?? null,
      purchaseInvoiceNumber: row.purchaseInvoice?.invoiceNumber ?? null,
      amount: asNumber(row.amount),
      currencyCode: row.currency,
      exchangeRateSypPerUsd: asNumber(row.exchangeRateSypPerUsd),
      amountUsdEquivalent: asNumber(row.amountUsdEquivalent),
      amountSypEquivalent: asNumber(row.amountSypEquivalent),
      createdAt: row.paidAt.toISOString(),
      note: row.note ?? '',
    };
  }

  private serializePurchase(row: any) {
    const totalUsd = asNumber(row.totalUsd);
    const totalSyp = asNumber(row.totalSyp);
    const paidUsd = (row.payments ?? []).reduce(
      (sum: number, payment: any) => sum + asNumber(payment.amountUsdEquivalent),
      0,
    );
    return {
      id: row.id,
      invoiceNumber: row.invoiceNumber ?? '',
      supplierId: row.supplierId,
      supplierNameSnapshot: row.supplier?.name ?? '',
      items: (row.items ?? []).map((item: any) => ({
        productId: item.productId ?? '',
        productName: item.productName,
        barcode: item.barcode ?? '',
        quantity: asNumber(item.quantity),
        unitPriceUsd: asNumber(item.unitCostUsd),
        unitPriceSyp: asNumber(item.unitCostSyp),
        totalUsd: asNumber(item.lineTotalUsd),
        totalSyp: asNumber(item.lineTotalSyp),
      })),
      exchangeRateSypPerUsd: asNumber(row.exchangeRateSypPerUsd),
      createdAt: row.purchasedAt.toISOString(),
      note: row.notes ?? '',
      totalUsd,
      totalSyp,
      paidUsd,
      outstandingUsd: Math.max(0, totalUsd - paidUsd),
      status: row.status,
    };
  }

  private isUniqueConflict(error: unknown): boolean {
    return typeof error === 'object' && error !== null && 'code' in error &&
      (error as { code?: string }).code === 'P2002';
  }
}
