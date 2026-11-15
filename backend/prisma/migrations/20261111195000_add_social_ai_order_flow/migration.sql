-- Per-connected-account AI replies and per-conversation human handoff/draft state.
ALTER TABLE "ChannelConnection"
  ADD COLUMN "aiAutoReplyEnabled" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "Conversation"
  ADD COLUMN "aiPaused" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "aiOrderDraft" JSONB;

-- Social orders are idempotent by the inbound Meta message that confirmed them.
ALTER TABLE "Order"
  ADD COLUMN "sourceConversationId" UUID,
  ADD COLUMN "sourceConfirmationMessageId" TEXT;

CREATE UNIQUE INDEX "Order_sourceConfirmationMessageId_key"
  ON "Order"("sourceConfirmationMessageId");
CREATE INDEX "Order_sourceConversationId_createdAt_idx"
  ON "Order"("sourceConversationId", "createdAt");

ALTER TABLE "Order"
  ADD CONSTRAINT "Order_sourceConversationId_fkey"
  FOREIGN KEY ("sourceConversationId") REFERENCES "Conversation"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
