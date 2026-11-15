-- NEXOR unified inbox: per-store Meta assets, conversations, messages and one-time OAuth state.
CREATE TYPE "ConversationChannel" AS ENUM ('INSTAGRAM', 'MESSENGER');
CREATE TYPE "ConversationStatus" AS ENUM ('OPEN', 'CLOSED');
CREATE TYPE "MessageDirection" AS ENUM ('INBOUND', 'OUTBOUND');
CREATE TYPE "MessageDeliveryStatus" AS ENUM ('RECEIVED', 'SENT', 'FAILED');

CREATE TABLE "ChannelConnection" (
    "id" UUID NOT NULL,
    "storeId" UUID NOT NULL,
    "channel" "ConversationChannel" NOT NULL,
    "externalAccountId" TEXT NOT NULL,
    "pageId" TEXT,
    "accountName" TEXT NOT NULL,
    "accessTokenEncrypted" TEXT NOT NULL,
    "tokenExpiresAt" TIMESTAMP(3),
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "connectedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ChannelConnection_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Conversation" (
    "id" UUID NOT NULL,
    "storeId" UUID NOT NULL,
    "channelConnectionId" UUID NOT NULL,
    "externalConversationId" TEXT NOT NULL,
    "externalCustomerId" TEXT NOT NULL,
    "customerName" TEXT,
    "customerUsername" TEXT,
    "customerProfileImage" TEXT,
    "lastMessageText" TEXT,
    "lastMessageAt" TIMESTAMP(3),
    "lastInboundAt" TIMESTAMP(3),
    "unreadCount" INTEGER NOT NULL DEFAULT 0,
    "status" "ConversationStatus" NOT NULL DEFAULT 'OPEN',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "Conversation_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ConversationMessage" (
    "id" UUID NOT NULL,
    "conversationId" UUID NOT NULL,
    "externalMessageId" TEXT,
    "direction" "MessageDirection" NOT NULL,
    "body" TEXT,
    "attachmentUrl" TEXT,
    "attachmentType" TEXT,
    "status" "MessageDeliveryStatus" NOT NULL DEFAULT 'RECEIVED',
    "rawPayload" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ConversationMessage_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "MetaOAuthState" (
    "id" UUID NOT NULL,
    "storeId" UUID NOT NULL,
    "state" TEXT NOT NULL,
    "channel" "ConversationChannel" NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "MetaOAuthState_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ChannelConnection_channel_externalAccountId_key" ON "ChannelConnection"("channel", "externalAccountId");
CREATE INDEX "ChannelConnection_storeId_channel_isActive_idx" ON "ChannelConnection"("storeId", "channel", "isActive");
CREATE INDEX "ChannelConnection_pageId_idx" ON "ChannelConnection"("pageId");
CREATE UNIQUE INDEX "Conversation_channelConnectionId_externalConversationId_key" ON "Conversation"("channelConnectionId", "externalConversationId");
CREATE INDEX "Conversation_storeId_status_lastMessageAt_idx" ON "Conversation"("storeId", "status", "lastMessageAt");
CREATE INDEX "Conversation_channelConnectionId_lastMessageAt_idx" ON "Conversation"("channelConnectionId", "lastMessageAt");
CREATE UNIQUE INDEX "ConversationMessage_conversationId_externalMessageId_key" ON "ConversationMessage"("conversationId", "externalMessageId");
CREATE INDEX "ConversationMessage_conversationId_createdAt_idx" ON "ConversationMessage"("conversationId", "createdAt");
CREATE UNIQUE INDEX "MetaOAuthState_state_key" ON "MetaOAuthState"("state");
CREATE INDEX "MetaOAuthState_storeId_expiresAt_idx" ON "MetaOAuthState"("storeId", "expiresAt");
CREATE INDEX "MetaOAuthState_expiresAt_idx" ON "MetaOAuthState"("expiresAt");

ALTER TABLE "ChannelConnection" ADD CONSTRAINT "ChannelConnection_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Conversation" ADD CONSTRAINT "Conversation_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Conversation" ADD CONSTRAINT "Conversation_channelConnectionId_fkey"
  FOREIGN KEY ("channelConnectionId") REFERENCES "ChannelConnection"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ConversationMessage" ADD CONSTRAINT "ConversationMessage_conversationId_fkey"
  FOREIGN KEY ("conversationId") REFERENCES "Conversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "MetaOAuthState" ADD CONSTRAINT "MetaOAuthState_storeId_fkey"
  FOREIGN KEY ("storeId") REFERENCES "Store"("id") ON DELETE CASCADE ON UPDATE CASCADE;
