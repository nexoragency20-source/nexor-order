-- NEXOR platform administration, store activation codes, and subscriptions.
CREATE TYPE "SubscriptionPlan" AS ENUM ('MONTHLY', 'THREE_MONTHS', 'SIX_MONTHS', 'YEARLY', 'CUSTOM');
CREATE TYPE "SubscriptionStatus" AS ENUM ('PENDING', 'ACTIVE', 'EXPIRED', 'SUSPENDED', 'CANCELLED');
CREATE TYPE "ActivationCodeStatus" AS ENUM ('AVAILABLE', 'USED', 'REVOKED', 'EXPIRED');

ALTER TABLE "Store"
  ADD COLUMN "contactName" TEXT,
  ADD COLUMN "contactPhone" TEXT,
  ADD COLUMN "subscriptionRequired" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "isSuspended" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "ownerActivatedAt" TIMESTAMP(3);

CREATE TABLE "PlatformAdmin" (
  "id" UUID NOT NULL,
  "email" TEXT NOT NULL,
  "fullName" TEXT NOT NULL,
  "passwordHash" TEXT NOT NULL,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "PlatformAdmin_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "PlatformAdmin_email_key" ON "PlatformAdmin"("email");
CREATE INDEX "PlatformAdmin_isActive_idx" ON "PlatformAdmin"("isActive");

CREATE TABLE "StoreSubscription" (
  "id" UUID NOT NULL,
  "storeId" UUID NOT NULL,
  "plan" "SubscriptionPlan" NOT NULL,
  "planName" TEXT NOT NULL,
  "durationMonths" INTEGER NOT NULL DEFAULT 0,
  "durationDays" INTEGER NOT NULL DEFAULT 0,
  "status" "SubscriptionStatus" NOT NULL DEFAULT 'PENDING',
  "startsAt" TIMESTAMP(3),
  "endsAt" TIMESTAMP(3),
  "amount" DECIMAL(20,2) NOT NULL DEFAULT 0,
  "paidAmount" DECIMAL(20,2) NOT NULL DEFAULT 0,
  "currency" "CurrencyCode" NOT NULL DEFAULT 'SYP',
  "notes" TEXT,
  "activatedAt" TIMESTAMP(3),
  "createdByAdminId" UUID,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "StoreSubscription_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "StoreSubscription_storeId_status_startsAt_endsAt_idx"
  ON "StoreSubscription"("storeId", "status", "startsAt", "endsAt");
CREATE INDEX "StoreSubscription_createdAt_idx" ON "StoreSubscription"("createdAt");
ALTER TABLE "StoreSubscription"
  ADD CONSTRAINT "StoreSubscription_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "StoreSubscription_createdByAdminId_fkey"
  FOREIGN KEY ("createdByAdminId") REFERENCES "PlatformAdmin"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "ActivationCode" (
  "id" UUID NOT NULL,
  "storeId" UUID NOT NULL,
  "subscriptionId" UUID NOT NULL,
  "codeHash" TEXT NOT NULL,
  "codeHint" TEXT NOT NULL,
  "status" "ActivationCodeStatus" NOT NULL DEFAULT 'AVAILABLE',
  "expiresAt" TIMESTAMP(3),
  "usedAt" TIMESTAMP(3),
  "usedByUserId" UUID,
  "createdByAdminId" UUID NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ActivationCode_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "ActivationCode_codeHash_key" ON "ActivationCode"("codeHash");
CREATE INDEX "ActivationCode_storeId_status_idx" ON "ActivationCode"("storeId", "status");
CREATE INDEX "ActivationCode_subscriptionId_idx" ON "ActivationCode"("subscriptionId");
ALTER TABLE "ActivationCode"
  ADD CONSTRAINT "ActivationCode_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "ActivationCode_subscriptionId_fkey"
  FOREIGN KEY ("subscriptionId") REFERENCES "StoreSubscription"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "ActivationCode_createdByAdminId_fkey"
  FOREIGN KEY ("createdByAdminId") REFERENCES "PlatformAdmin"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT "ActivationCode_usedByUserId_fkey"
  FOREIGN KEY ("usedByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "PlatformAuditLog" (
  "id" UUID NOT NULL,
  "adminId" UUID,
  "storeId" UUID,
  "actorType" TEXT NOT NULL,
  "actorId" TEXT,
  "action" TEXT NOT NULL,
  "details" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "PlatformAuditLog_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "PlatformAuditLog_adminId_createdAt_idx" ON "PlatformAuditLog"("adminId", "createdAt");
CREATE INDEX "PlatformAuditLog_storeId_createdAt_idx" ON "PlatformAuditLog"("storeId", "createdAt");
ALTER TABLE "PlatformAuditLog"
  ADD CONSTRAINT "PlatformAuditLog_adminId_fkey"
  FOREIGN KEY ("adminId") REFERENCES "PlatformAdmin"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "PlatformAuditLog_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE SET NULL ON UPDATE CASCADE;
