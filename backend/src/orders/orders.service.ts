import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service.js";
import type { AccessTokenPayload } from "../auth/interfaces/access-token-payload.interface.js";
import type { CustomerPaymentDto, OrderDto } from "./dto/orders.dto.js";

const asNumber = (value: unknown): number => {
  if (typeof value === "number") return value;
  if (value && typeof value === "object" && "toString" in value) {
    return Number((value as { toString(): string }).toString());
  }
  return Number(value ?? 0);
};

const roundMoney = (value: number): number =>
  Math.round((value + Number.EPSILON) * 100) / 100;
const HOLDING_STATUSES = new Set([
  "CONFIRMED",
  "PROCESSING",
  "SHIPPED",
  "COMPLETED",
]);

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  async listCustomers(user: AccessTokenPayload) {
    const store = await this.getStore(user);
    const rows = await this.prisma.customer.findMany({
      where: { storeId: store.id, isActive: true },
      orderBy: [{ name: "asc" }, { createdAt: "desc" }],
      take: 500,
    });
    return {
      items: rows.map((row) => ({
        id: row.id,
        name: row.name,
        phone: row.phone ?? "",
        address: row.address ?? "",
      })),
    };
  }

  async list(user: AccessTokenPayload) {
    const store = await this.getStore(user);
    const rows = await this.prisma.order.findMany({
      where: { storeId: store.id },
      include: {
        customer: {
          select: { id: true, name: true, phone: true, address: true },
        },
        items: { orderBy: { id: "asc" } },
        payments: { orderBy: { paidAt: "asc" } },
        returns: {
          where: { status: "RECEIVED" },
          select: {
            amountUsdEquivalent: true,
            amountSypEquivalent: true,
            settlementType: true,
          },
        },
      },
      orderBy: { createdAt: "desc" },
    });
    return {
      exchangeRateSypPerUsd: asNumber(store.exchangeRateSypPerUsd),
      items: rows.map((row) => this.serializeOrder(row)),
    };
  }

  async create(user: AccessTokenPayload, dto: OrderDto) {
    const store = await this.getStore(user);
    return this.createForStore(store, user.organizationId, dto);
  }

  /**
   * Creates a normal pending order from a confirmed Meta conversation.
   * Product identity and prices are reloaded from this store inside the same
   * transaction as the order creation. The Meta confirmation message is the
   * idempotency key, so webhook retries cannot create duplicate orders.
   */
  async createFromSocialConversation(input: {
    storeId: string;
    organizationId: string;
    conversationId: string;
    confirmationMessageId: string;
    dto: OrderDto;
  }) {
    const store = await this.prisma.store.findFirst({
      where: { id: input.storeId, organizationId: input.organizationId },
      select: { id: true, exchangeRateSypPerUsd: true },
    });
    if (!store)
      throw new NotFoundException("المتجر المرتبط بالمحادثة غير موجود.");

    const existing = await (this.prisma as any).order.findFirst({
      where: {
        storeId: store.id,
        sourceConfirmationMessageId: input.confirmationMessageId,
      },
      select: { id: true },
    });
    if (existing)
      return this.findSerialized(this.prisma, store.id, existing.id);

    try {
      return await this.createForStore(store, input.organizationId, input.dto, {
        conversationId: input.conversationId,
        confirmationMessageId: input.confirmationMessageId,
      });
    } catch (error) {
      // A concurrent webhook retry may have committed the same confirmation.
      const duplicate = await (this.prisma as any).order.findFirst({
        where: {
          storeId: store.id,
          sourceConfirmationMessageId: input.confirmationMessageId,
        },
        select: { id: true },
      });
      if (duplicate)
        return this.findSerialized(this.prisma, store.id, duplicate.id);
      throw error;
    }
  }

  private async createForStore(
    store: { id: string; exchangeRateSypPerUsd: unknown },
    organizationId: string,
    dto: OrderDto,
    source?: { conversationId: string; confirmationMessageId: string },
  ) {
    try {
      return await this.prisma.$transaction(
        async (tx) => {
          const transactionalStore = await tx.store.findFirst({
            where: { id: store.id, organizationId },
            select: { id: true, exchangeRateSypPerUsd: true },
          });
          if (!transactionalStore)
            throw new NotFoundException("المتجر المرتبط بالجلسة غير موجود.");
          if (source) {
            const conversation = await tx.conversation.findFirst({
              where: { id: source.conversationId, storeId: store.id },
              select: { id: true },
            });
            if (!conversation)
              throw new NotFoundException(
                "محادثة الطلب غير موجودة في هذا المتجر.",
              );
          }
          const rate = asNumber(transactionalStore.exchangeRateSypPerUsd);
          const customer = await this.resolveCustomer(tx, store.id, dto);
          const lines = await this.buildLines(
            tx,
            store.id,
            dto.items,
            rate,
            Boolean(source),
          );
          const totals = this.calculateTotals(lines, dto, rate);
          const status = dto.status ?? "PENDING";
          const orderNumber = this.newOrderNumber();

          const order = await (tx as any).order.create({
            data: {
              storeId: store.id,
              customerId: customer.id,
              customerNameSnapshot: dto.customerName.trim(),
              customerPhoneSnapshot: dto.phone?.trim() || null,
              shippingAddressSnapshot: dto.address?.trim() || null,
              orderNumber,
              status: status as any,
              paymentMethod: (dto.paymentMethod ?? null) as any,
              exchangeRateSypPerUsd: rate,
              subtotalUsd: totals.subtotalUsd,
              discountUsd: totals.discountUsd,
              shippingUsd: totals.shippingUsd,
              totalUsd: totals.totalUsd,
              totalSyp: totals.totalSyp,
              notes: dto.notes?.trim() || null,
              ...(source
                ? {
                    sourceConversationId: source.conversationId,
                    sourceConfirmationMessageId: source.confirmationMessageId,
                  }
                : {}),
              items: { create: lines },
            },
            include: {
              customer: {
                select: { id: true, name: true, phone: true, address: true },
              },
              items: true,
              payments: true,
            },
          });

          if (HOLDING_STATUSES.has(status)) {
            await this.deductStock(
              tx,
              store.id,
              order.id,
              lines,
              order.orderNumber,
              rate,
            );
          }

          const initialAmount = dto.initialPaymentAmount ?? 0;
          if (initialAmount > 0) {
            await this.createPayment(tx, {
              storeId: store.id,
              customerId: customer.id,
              orderId: order.id,
              amount: initialAmount,
              currency: dto.initialPaymentCurrency ?? "SYP",
              method: dto.initialPaymentMethod ?? dto.paymentMethod ?? "CASH",
              note: "دفعة عند إنشاء الطلب",
              rate,
              totalUsd: totals.totalUsd,
            });
          }

          return this.findSerialized(tx, store.id, order.id);
        },
        { isolationLevel: "Serializable" },
      );
    } catch (error) {
      this.handleUniqueConflict(error);
      throw error;
    }
  }

  async update(user: AccessTokenPayload, id: string, dto: OrderDto) {
    const store = await this.getStore(user);
    return this.prisma.$transaction(
      async (tx) => {
        const existing = await tx.order.findFirst({
          where: { id, storeId: store.id },
          include: { items: true, payments: true },
        });
        if (!existing)
          throw new NotFoundException("الطلب غير موجود في هذا المتجر.");
        if (existing.status !== "PENDING") {
          throw new BadRequestException(
            "يمكن تعديل تفاصيل الطلب قبل اعتماده فقط. غيّر الحالة أو ألغِ الطلب بدلاً من تعديل طلب معتمد.",
          );
        }

        const customer = await this.resolveCustomer(tx, store.id, dto);
        const rate = asNumber(existing.exchangeRateSypPerUsd);
        const lines = await this.buildLines(tx, store.id, dto.items, rate);
        const totals = this.calculateTotals(lines, dto, rate);
        const alreadyPaidUsd = existing.payments.reduce(
          (sum, payment) => sum + asNumber(payment.amountUsdEquivalent),
          0,
        );
        if (alreadyPaidUsd > totals.totalUsd + 0.000001) {
          throw new BadRequestException(
            "إجمالي الطلب الجديد أقل من المبلغ المدفوع مسبقاً.",
          );
        }

        await tx.orderItem.deleteMany({ where: { orderId: id } });
        await tx.order.update({
          where: { id },
          data: {
            customerId: customer.id,
            customerNameSnapshot: dto.customerName.trim(),
            customerPhoneSnapshot: dto.phone?.trim() || null,
            shippingAddressSnapshot: dto.address?.trim() || null,
            paymentMethod: (dto.paymentMethod ?? null) as any,
            subtotalUsd: totals.subtotalUsd,
            discountUsd: totals.discountUsd,
            shippingUsd: totals.shippingUsd,
            totalUsd: totals.totalUsd,
            totalSyp: totals.totalSyp,
            notes: dto.notes?.trim() || null,
            items: { create: lines },
          },
        });
        // Keep historical payments attached to the currently selected customer.
        await tx.customerPayment.updateMany({
          where: { orderId: id, storeId: store.id },
          data: { customerId: customer.id },
        });
        await this.refreshPaymentStatus(tx, id, totals.totalUsd);
        return this.findSerialized(tx, store.id, id);
      },
      { isolationLevel: "Serializable" },
    );
  }

  async updateStatus(user: AccessTokenPayload, id: string, nextStatus: string) {
    const store = await this.getStore(user);
    return this.prisma.$transaction(
      async (tx) => {
        const order = await tx.order.findFirst({
          where: { id, storeId: store.id },
          include: { items: true },
        });
        if (!order)
          throw new NotFoundException("الطلب غير موجود في هذا المتجر.");
        if (order.status === nextStatus)
          return this.findSerialized(tx, store.id, id);
        const allowedTransitions: Record<string, string[]> = {
          PENDING: ["CONFIRMED", "PROCESSING", "CANCELLED"],
          CONFIRMED: ["PROCESSING", "SHIPPED", "CANCELLED"],
          PROCESSING: ["SHIPPED", "CANCELLED"],
          SHIPPED: ["COMPLETED"],
          COMPLETED: [],
          CANCELLED: [],
        };
        if (!(allowedTransitions[order.status] ?? []).includes(nextStatus)) {
          if (order.status === "SHIPPED" && nextStatus === "CANCELLED") {
            throw new BadRequestException(
              "لا يمكن إلغاء طلب تم شحنه. استخدم إجراء مرتجع عند توفره.",
            );
          }
          throw new BadRequestException(
            "انتقال حالة الطلب غير مسموح. تحقق من الحالة الحالية والحالة الجديدة.",
          );
        }

        if (
          HOLDING_STATUSES.has(nextStatus) &&
          !HOLDING_STATUSES.has(order.status)
        ) {
          await this.deductStock(
            tx,
            store.id,
            id,
            order.items,
            order.orderNumber,
            asNumber(order.exchangeRateSypPerUsd),
          );
        }
        if (nextStatus === "CANCELLED" && HOLDING_STATUSES.has(order.status)) {
          await this.restoreStock(
            tx,
            store.id,
            id,
            order.items,
            order.orderNumber,
          );
        }

        await tx.order.update({
          where: { id },
          data: { status: nextStatus as any },
        });
        return this.findSerialized(tx, store.id, id);
      },
      { isolationLevel: "Serializable" },
    );
  }

  async recordPayment(
    user: AccessTokenPayload,
    id: string,
    dto: CustomerPaymentDto,
  ) {
    const store = await this.getStore(user);
    return this.prisma.$transaction(
      async (tx) => {
        const transactionalStore = await tx.store.findFirst({
          where: { id: store.id, organizationId: user.organizationId },
          select: { id: true, exchangeRateSypPerUsd: true },
        });
        if (!transactionalStore)
          throw new NotFoundException("المتجر المرتبط بالجلسة غير موجود.");
        const order = await tx.order.findFirst({
          where: { id, storeId: store.id },
          include: {
            payments: true,
            returns: {
              where: { status: "RECEIVED" },
              select: { amountUsdEquivalent: true, settlementType: true },
            },
          },
        });
        if (!order)
          throw new NotFoundException("الطلب غير موجود في هذا المتجر.");
        if (order.status === "CANCELLED")
          throw new BadRequestException("لا يمكن تسجيل دفعة لطلب ملغي.");
        const rate = asNumber(transactionalStore.exchangeRateSypPerUsd);
        const paidUsd = order.payments.reduce(
          (sum, payment) => sum + asNumber(payment.amountUsdEquivalent),
          0,
        );
        const amountUsd =
          dto.currency === "USD" ? dto.amount : dto.amount / rate;
        const returnedUsd = order.returns.reduce(
          (sum, item) => sum + asNumber(item.amountUsdEquivalent),
          0,
        );
        const cashRefundUsd = order.returns
          .filter((item) => item.settlementType === "CASH")
          .reduce((sum, item) => sum + asNumber(item.amountUsdEquivalent), 0);
        const allowedPaymentUsd = Math.max(
          0,
          asNumber(order.totalUsd) - returnedUsd + cashRefundUsd,
        );
        if (paidUsd + amountUsd > allowedPaymentUsd + 0.000001) {
          throw new BadRequestException(
            "قيمة الدفعة أكبر من المبلغ المتبقي على الطلب.",
          );
        }
        if (!order.customerId)
          throw new BadRequestException("الطلب غير مرتبط بعميل.");

        await tx.customerPayment.create({
          data: {
            storeId: store.id,
            customerId: order.customerId,
            orderId: order.id,
            amount: dto.amount,
            currency: dto.currency as any,
            exchangeRateSypPerUsd: rate,
            amountUsdEquivalent: amountUsd,
            amountSypEquivalent:
              dto.currency === "SYP"
                ? dto.amount
                : roundMoney(dto.amount * rate),
            method: (dto.method ?? "CASH") as any,
            note: dto.note?.trim() || null,
          },
        });
        await this.refreshPaymentStatus(tx, id, asNumber(order.totalUsd));
        return this.findSerialized(tx, store.id, id);
      },
      { isolationLevel: "Serializable" },
    );
  }

  private async getStore(user: AccessTokenPayload) {
    const store = await this.prisma.store.findFirst({
      where: { id: user.storeId, organizationId: user.organizationId },
      select: { id: true, exchangeRateSypPerUsd: true },
    });
    if (!store)
      throw new NotFoundException("المتجر المرتبط بالجلسة غير موجود.");
    return store;
  }

  private async resolveCustomer(tx: any, storeId: string, dto: OrderDto) {
    if (dto.customerId) {
      const byId = await tx.customer.findFirst({
        where: { id: dto.customerId, storeId, isActive: true },
      });
      if (!byId)
        throw new NotFoundException("العميل المحدد غير موجود في هذا المتجر.");
      return byId;
    }

    const phone = dto.phone?.trim();
    if (phone) {
      const existing = await tx.customer.findFirst({
        where: { storeId, phone, isActive: true },
        orderBy: { createdAt: "desc" },
      });
      if (existing) return existing;
    }
    return tx.customer.create({
      data: {
        storeId,
        name: dto.customerName.trim(),
        phone: phone || null,
        address: dto.address?.trim() || null,
      },
    });
  }

  private async buildLines(
    tx: any,
    storeId: string,
    rawLines: OrderDto["items"],
    rate: number,
    validateSocialSnapshot = false,
  ) {
    const lines: any[] = [];
    for (const line of rawLines) {
      if (!Number.isFinite(line.quantity) || line.quantity <= 0) {
        throw new BadRequestException("كمية أحد الأصناف غير صحيحة.");
      }
      let product: any = null;
      if (line.productId) {
        product = await tx.product.findFirst({
          where: { id: line.productId, storeId, isActive: true },
          select: {
            id: true,
            name: true,
            barcode: true,
            purchasePriceUsd: true,
            sellingPriceUsd: true,
            stockQuantity: true,
          },
        });
        if (!product)
          throw new NotFoundException(
            "أحد المنتجات غير موجود أو غير فعال في هذا المتجر.",
          );
      }
      const productName = product?.name ?? line.productName?.trim();
      if (!productName) throw new BadRequestException("اسم الصنف مطلوب.");
      if (validateSocialSnapshot && !product) {
        throw new ConflictException(
          "تعذر التحقق من أحد منتجات الطلب. أعد مراجعة المنتجات قبل التأكيد.",
        );
      }
      const currentCatalogPrice = product
        ? asNumber(product.sellingPriceUsd)
        : undefined;
      const unitPriceUsd = line.unitPriceUsd ?? currentCatalogPrice;
      if (
        unitPriceUsd === undefined ||
        !Number.isFinite(unitPriceUsd) ||
        unitPriceUsd < 0
      ) {
        throw new BadRequestException("سعر أحد الأصناف غير صحيح.");
      }
      if (
        validateSocialSnapshot &&
        currentCatalogPrice !== undefined &&
        Math.abs(unitPriceUsd - currentCatalogPrice) > 0.000001
      ) {
        throw new ConflictException(
          "تغير سعر أحد المنتجات بعد إرسال ملخص الطلب. يجب عرض السعر الجديد قبل التسجيل.",
        );
      }
      const quantity = line.quantity;
      if (
        validateSocialSnapshot &&
        product &&
        quantity > asNumber(product.stockQuantity)
      ) {
        throw new ConflictException(
          `الكمية المتاحة من ${product.name} تغيرت بعد إرسال ملخص الطلب. يجب مراجعة الكمية قبل التسجيل.`,
        );
      }
      const unitPriceSyp = roundMoney(unitPriceUsd * rate);
      const lineTotalUsd = quantity * unitPriceUsd;
      const lineTotalSyp = roundMoney(quantity * unitPriceSyp);
      lines.push({
        productId: product?.id ?? null,
        productName,
        barcode: product?.barcode ?? line.barcode?.trim() ?? null,
        quantity,
        unitPriceUsd,
        unitPriceSyp,
        unitCostUsd: product ? asNumber(product.purchasePriceUsd) : 0,
        lineTotalUsd,
        lineTotalSyp,
      });
    }
    return lines;
  }

  private calculateTotals(lines: any[], dto: OrderDto, rate: number) {
    const subtotalUsd = lines.reduce((sum, line) => sum + line.lineTotalUsd, 0);
    const discountUsd = dto.discountUsd ?? 0;
    const shippingUsd = dto.shippingUsd ?? 0;
    if (discountUsd > subtotalUsd + 0.000001) {
      throw new BadRequestException("الخصم لا يمكن أن يتجاوز مجموع الأصناف.");
    }
    const totalUsd = Math.max(0, subtotalUsd - discountUsd + shippingUsd);
    return {
      subtotalUsd,
      discountUsd,
      shippingUsd,
      totalUsd,
      totalSyp: roundMoney(totalUsd * rate),
    };
  }

  private async deductStock(
    tx: any,
    storeId: string,
    orderId: string,
    lines: any[],
    orderNumber: string,
    rate: number,
  ) {
    const alreadyDeducted = await tx.inventoryMovement.findFirst({
      where: {
        storeId,
        referenceType: "ORDER",
        referenceId: orderId,
        type: "SALE_OUT",
      },
      select: { id: true },
    });
    if (alreadyDeducted) return;

    const grouped = this.groupStockLines(lines, rate);
    for (const [productId, group] of grouped.entries()) {
      const changed = await tx.product.updateMany({
        where: {
          id: productId,
          storeId,
          isActive: true,
          stockQuantity: { gte: group.quantity },
        },
        data: { stockQuantity: { decrement: group.quantity } },
      });
      if (changed.count !== 1) {
        const product = await tx.product.findFirst({
          where: { id: productId, storeId },
          select: { name: true, stockQuantity: true },
        });
        if (!product)
          throw new NotFoundException("أحد أصناف الطلب لم يعد موجوداً.");
        throw new BadRequestException(
          `المخزون غير كافٍ للصنف ${product.name}. المتوفر حالياً ${asNumber(product.stockQuantity)}.`,
        );
      }
      const averageCostUsd =
        group.quantity > 0 ? group.costUsd / group.quantity : 0;
      await tx.inventoryMovement.create({
        data: {
          storeId,
          productId,
          type: "SALE_OUT",
          quantity: group.quantity,
          unitCostUsd: averageCostUsd,
          unitCostSyp: roundMoney(averageCostUsd * group.rate),
          referenceType: "ORDER",
          referenceId: orderId,
          note: `صرف بضاعة للطلب ${orderNumber}`,
        },
      });
    }
  }

  private async restoreStock(
    tx: any,
    storeId: string,
    orderId: string,
    lines: any[],
    orderNumber: string,
  ) {
    const saleMovements = await tx.inventoryMovement.findMany({
      where: {
        storeId,
        referenceType: "ORDER",
        referenceId: orderId,
        type: "SALE_OUT",
      },
    });
    if (saleMovements.length === 0) return;
    const grouped = this.groupStockLines(lines);
    for (const [productId, group] of grouped.entries()) {
      await tx.product.updateMany({
        where: { id: productId, storeId },
        data: { stockQuantity: { increment: group.quantity } },
      });
      await tx.inventoryMovement.create({
        data: {
          storeId,
          productId,
          type: "CUSTOMER_RETURN_IN",
          quantity: group.quantity,
          referenceType: "ORDER_CANCELLATION",
          referenceId: orderId,
          note: `إرجاع مخزون بسبب إلغاء الطلب ${orderNumber}`,
        },
      });
    }
  }

  private groupStockLines(lines: any[], rate = 1) {
    const grouped = new Map<
      string,
      { quantity: number; costUsd: number; rate: number }
    >();
    for (const line of lines) {
      if (!line.productId) continue;
      const current = grouped.get(line.productId) ?? {
        quantity: 0,
        costUsd: 0,
        rate,
      };
      current.quantity += asNumber(line.quantity);
      current.costUsd += asNumber(line.quantity) * asNumber(line.unitCostUsd);
      current.rate = rate;
      grouped.set(line.productId, current);
    }
    return grouped;
  }

  private async createPayment(
    tx: any,
    input: {
      storeId: string;
      customerId: string;
      orderId: string;
      amount: number;
      currency: string;
      method: string;
      note: string;
      rate: number;
      totalUsd: number;
    },
  ) {
    if (!Number.isFinite(input.amount) || input.amount <= 0) {
      throw new BadRequestException("قيمة الدفعة يجب أن تكون أكبر من صفر.");
    }
    const amountUsd =
      input.currency === "USD" ? input.amount : input.amount / input.rate;
    const amountSyp =
      input.currency === "SYP"
        ? input.amount
        : roundMoney(input.amount * input.rate);
    const previous = await tx.customerPayment.aggregate({
      where: { orderId: input.orderId },
      _sum: { amountUsdEquivalent: true },
    });
    const paidUsd = asNumber(previous._sum.amountUsdEquivalent);
    if (paidUsd + amountUsd > input.totalUsd + 0.000001) {
      throw new BadRequestException("قيمة الدفعة أكبر من إجمالي الطلب.");
    }
    await tx.customerPayment.create({
      data: {
        storeId: input.storeId,
        customerId: input.customerId,
        orderId: input.orderId,
        amount: input.amount,
        currency: input.currency as any,
        exchangeRateSypPerUsd: input.rate,
        amountUsdEquivalent: amountUsd,
        amountSypEquivalent: amountSyp,
        method: input.method as any,
        note: input.note,
      },
    });
    await this.refreshPaymentStatus(tx, input.orderId, input.totalUsd);
  }

  private async refreshPaymentStatus(
    tx: any,
    orderId: string,
    totalUsd: number,
  ) {
    const [payments, returns] = await Promise.all([
      tx.customerPayment.findMany({
        where: { orderId },
        select: { amountUsdEquivalent: true },
      }),
      tx.salesReturn.findMany({
        where: { orderId, status: "RECEIVED" },
        select: { amountUsdEquivalent: true, settlementType: true },
      }),
    ]);
    const returnedUsd = returns.reduce(
      (sum: number, item: any) => sum + asNumber(item.amountUsdEquivalent),
      0,
    );
    const cashRefundUsd = returns
      .filter((item: any) => item.settlementType === "CASH")
      .reduce(
        (sum: number, item: any) => sum + asNumber(item.amountUsdEquivalent),
        0,
      );
    const netTotalUsd = Math.max(0, totalUsd - returnedUsd);
    const netPaidUsd = Math.max(
      0,
      payments.reduce(
        (sum: number, payment: any) =>
          sum + asNumber(payment.amountUsdEquivalent),
        0,
      ) - cashRefundUsd,
    );
    const paymentStatus =
      netTotalUsd <= 0.000001
        ? "PAID"
        : netPaidUsd <= 0.000001
          ? "UNPAID"
          : netPaidUsd + 0.000001 >= netTotalUsd
            ? "PAID"
            : "PARTIALLY_PAID";
    await tx.order.update({
      where: { id: orderId },
      data: { paymentStatus: paymentStatus as any },
    });
  }

  private async findSerialized(tx: any, storeId: string, id: string) {
    const row = await tx.order.findFirst({
      where: { id, storeId },
      include: {
        customer: {
          select: { id: true, name: true, phone: true, address: true },
        },
        items: { orderBy: { id: "asc" } },
        payments: { orderBy: { paidAt: "asc" } },
        returns: {
          where: { status: "RECEIVED" },
          select: {
            amountUsdEquivalent: true,
            amountSypEquivalent: true,
            settlementType: true,
          },
        },
      },
    });
    if (!row) throw new NotFoundException("الطلب غير موجود في هذا المتجر.");
    return this.serializeOrder(row);
  }

  private serializeOrder(row: any) {
    const totalUsd = asNumber(row.totalUsd);
    const totalSyp = asNumber(row.totalSyp);
    const rate = asNumber(row.exchangeRateSypPerUsd);
    const grossPaidUsd = (row.payments ?? []).reduce(
      (sum: number, payment: any) =>
        sum + asNumber(payment.amountUsdEquivalent),
      0,
    );
    const grossPaidSyp = (row.payments ?? []).reduce(
      (sum: number, payment: any) =>
        sum + asNumber(payment.amountSypEquivalent),
      0,
    );
    const receivedReturns = row.returns ?? [];
    const returnedUsd = receivedReturns.reduce(
      (sum: number, item: any) => sum + asNumber(item.amountUsdEquivalent),
      0,
    );
    const returnedSyp = receivedReturns.reduce(
      (sum: number, item: any) => sum + asNumber(item.amountSypEquivalent),
      0,
    );
    const cashRefundUsd = receivedReturns
      .filter((item: any) => item.settlementType === "CASH")
      .reduce(
        (sum: number, item: any) => sum + asNumber(item.amountUsdEquivalent),
        0,
      );
    const cashRefundSyp = receivedReturns
      .filter((item: any) => item.settlementType === "CASH")
      .reduce(
        (sum: number, item: any) => sum + asNumber(item.amountSypEquivalent),
        0,
      );
    const netTotalUsd = Math.max(0, totalUsd - returnedUsd);
    const netTotalSyp = Math.max(0, totalSyp - returnedSyp);
    const paidUsd = Math.min(
      netTotalUsd,
      Math.max(0, grossPaidUsd - cashRefundUsd),
    );
    const paidSyp = Math.min(
      netTotalSyp,
      Math.max(0, grossPaidSyp - cashRefundSyp),
    );
    return {
      recordId: row.id,
      id: row.orderNumber,
      orderNumber: row.orderNumber,
      customerId: row.customerId ?? "",
      customerName: row.customerNameSnapshot ?? row.customer?.name ?? "",
      phone: row.customerPhoneSnapshot ?? row.customer?.phone ?? "",
      address: row.shippingAddressSnapshot ?? row.customer?.address ?? "",
      items: (row.items ?? []).map((item: any) => ({
        productId: item.productId ?? "",
        productName: item.productName,
        barcode: item.barcode ?? "",
        quantity: asNumber(item.quantity),
        unitPriceUsd: asNumber(item.unitPriceUsd),
        unitPrice: asNumber(item.unitPriceSyp),
        unitCostUsd: asNumber(item.unitCostUsd),
        totalUsd: asNumber(item.lineTotalUsd),
        totalSyp: asNumber(item.lineTotalSyp),
      })),
      status: row.status,
      paymentStatus: row.paymentStatus,
      paymentMethod: row.paymentMethod,
      exchangeRateSypPerUsd: rate,
      subtotalUsd: asNumber(row.subtotalUsd),
      discountUsd: asNumber(row.discountUsd),
      shippingUsd: asNumber(row.shippingUsd),
      totalUsd,
      totalAmount: netTotalSyp,
      totalSyp,
      netTotalUsd,
      netTotalSyp,
      returnedUsd: roundMoney(returnedUsd),
      returnedSyp: roundMoney(returnedSyp),
      paidUsd: roundMoney(paidUsd),
      paidAmountSyp: roundMoney(paidSyp),
      remainingUsd: Math.max(0, netTotalUsd - paidUsd),
      remainingSyp: roundMoney(Math.max(0, netTotalSyp - paidSyp)),
      payments: (row.payments ?? []).map((payment: any) => ({
        id: payment.id,
        amount: asNumber(payment.amount),
        currency: payment.currency,
        amountUsdEquivalent: asNumber(payment.amountUsdEquivalent),
        amountSypEquivalent: asNumber(payment.amountSypEquivalent),
        method: payment.method,
        note: payment.note ?? "",
        paidAt: payment.paidAt.toISOString(),
      })),
      createdAt: row.createdAt.toISOString(),
      note: row.notes ?? "",
    };
  }

  private newOrderNumber() {
    const time = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).slice(2, 6).toUpperCase();
    return `NX-${time}-${random}`;
  }

  private handleUniqueConflict(error: unknown): void {
    if (
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      (error as { code?: string }).code === "P2002"
    ) {
      throw new ConflictException("تعذر إنشاء رقم طلب فريد. أعد المحاولة.");
    }
  }
}
