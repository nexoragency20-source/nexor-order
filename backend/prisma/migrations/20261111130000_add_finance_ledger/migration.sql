CREATE TYPE "FinanceTransactionType" AS ENUM (
  'INCOME',
  'EXPENSE',
  'DEPOSIT',
  'WITHDRAWAL',
  'OPENING_BALANCE',
  'TRANSFER_IN',
  'TRANSFER_OUT'
);

CREATE TABLE "FinanceTransaction" (
  "id" UUID NOT NULL,
  "storeId" UUID NOT NULL,
  "type" "FinanceTransactionType" NOT NULL,
  "currency" "CurrencyCode" NOT NULL,
  "amount" DECIMAL(20,6) NOT NULL,
  "exchangeRateSypPerUsd" DECIMAL(20,6) NOT NULL,
  "amountUsdEquivalent" DECIMAL(20,6) NOT NULL,
  "amountSypEquivalent" DECIMAL(20,2) NOT NULL,
  "category" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "note" TEXT,
  "referenceType" TEXT,
  "referenceId" UUID,
  "transferGroupId" UUID,
  "occurredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "FinanceTransaction_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "FinanceTransaction_storeId_fkey"
    FOREIGN KEY ("storeId") REFERENCES "Store"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "FinanceTransaction_storeId_referenceType_referenceId_key"
  ON "FinanceTransaction"("storeId", "referenceType", "referenceId");
CREATE INDEX "FinanceTransaction_storeId_occurredAt_idx"
  ON "FinanceTransaction"("storeId", "occurredAt");
CREATE INDEX "FinanceTransaction_storeId_currency_occurredAt_idx"
  ON "FinanceTransaction"("storeId", "currency", "occurredAt");
CREATE INDEX "FinanceTransaction_transferGroupId_idx"
  ON "FinanceTransaction"("transferGroupId");
