-- NEXOR Sales Returns: tracked requests and receipt processing.
CREATE TYPE "SalesReturnStatus" AS ENUM ('REQUESTED', 'RECEIVED', 'REJECTED');
CREATE TYPE "SalesReturnSettlementType" AS ENUM ('CASH', 'CUSTOMER_CREDIT');

CREATE TABLE "SalesReturn" (
    "id" UUID NOT NULL,
    "storeId" UUID NOT NULL,
    "orderId" UUID NOT NULL,
    "customerId" UUID,
    "returnNumber" TEXT NOT NULL,
    "status" "SalesReturnStatus" NOT NULL DEFAULT 'REQUESTED',
    "settlementType" "SalesReturnSettlementType" NOT NULL,
    "currency" "CurrencyCode" NOT NULL,
    "amount" DECIMAL(20,6) NOT NULL,
    "exchangeRateSypPerUsd" DECIMAL(20,6) NOT NULL,
    "amountUsdEquivalent" DECIMAL(20,6) NOT NULL,
    "amountSypEquivalent" DECIMAL(20,2) NOT NULL,
    "reason" TEXT,
    "notes" TEXT,
    "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "receivedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "SalesReturn_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "SalesReturnItem" (
    "id" UUID NOT NULL,
    "salesReturnId" UUID NOT NULL,
    "orderItemId" UUID NOT NULL,
    "productId" UUID,
    "productName" TEXT NOT NULL,
    "barcode" TEXT,
    "quantity" DECIMAL(20,3) NOT NULL,
    "unitPriceUsd" DECIMAL(20,6) NOT NULL,
    "unitPriceSyp" DECIMAL(20,2) NOT NULL,
    "unitCostUsd" DECIMAL(20,6) NOT NULL DEFAULT 0,
    "lineTotalUsd" DECIMAL(20,6) NOT NULL,
    "lineTotalSyp" DECIMAL(20,2) NOT NULL,
    CONSTRAINT "SalesReturnItem_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "SalesReturn_storeId_returnNumber_key" ON "SalesReturn"("storeId", "returnNumber");
CREATE INDEX "SalesReturn_storeId_createdAt_idx" ON "SalesReturn"("storeId", "createdAt");
CREATE INDEX "SalesReturn_storeId_status_idx" ON "SalesReturn"("storeId", "status");
CREATE INDEX "SalesReturn_orderId_status_idx" ON "SalesReturn"("orderId", "status");
CREATE INDEX "SalesReturn_customerId_createdAt_idx" ON "SalesReturn"("customerId", "createdAt");
CREATE UNIQUE INDEX "SalesReturnItem_salesReturnId_orderItemId_key" ON "SalesReturnItem"("salesReturnId", "orderItemId");
CREATE INDEX "SalesReturnItem_orderItemId_idx" ON "SalesReturnItem"("orderItemId");
CREATE INDEX "SalesReturnItem_productId_idx" ON "SalesReturnItem"("productId");

ALTER TABLE "SalesReturn" ADD CONSTRAINT "SalesReturn_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SalesReturn" ADD CONSTRAINT "SalesReturn_orderId_fkey"
  FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "SalesReturn" ADD CONSTRAINT "SalesReturn_customerId_fkey"
  FOREIGN KEY ("customerId") REFERENCES "Customer"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "SalesReturnItem" ADD CONSTRAINT "SalesReturnItem_salesReturnId_fkey"
  FOREIGN KEY ("salesReturnId") REFERENCES "SalesReturn"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SalesReturnItem" ADD CONSTRAINT "SalesReturnItem_orderItemId_fkey"
  FOREIGN KEY ("orderItemId") REFERENCES "OrderItem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "SalesReturnItem" ADD CONSTRAINT "SalesReturnItem_productId_fkey"
  FOREIGN KEY ("productId") REFERENCES "Product"("id") ON DELETE SET NULL ON UPDATE CASCADE;
