-- Website Chat uses the existing unified inbox and AI order workflow.
ALTER TYPE "ConversationChannel" ADD VALUE IF NOT EXISTS 'WEBSITE';

ALTER TABLE "ChannelConnection"
  ALTER COLUMN "accessTokenEncrypted" DROP NOT NULL;

ALTER TABLE "ChannelConnection"
  ADD COLUMN "allowedOrigins" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

ALTER TABLE "Conversation"
  ADD COLUMN "publicSessionTokenHash" TEXT;

CREATE UNIQUE INDEX "Conversation_publicSessionTokenHash_key"
  ON "Conversation"("publicSessionTokenHash");
