ALTER TABLE "Customer"
ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX "Customer_storeId_isActive_idx"
ON "Customer"("storeId", "isActive");
