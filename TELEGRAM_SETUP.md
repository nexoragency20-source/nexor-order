NEXOR Orders - Telegram Backend Integration
=============================================

Files in this package:
- backend/src/conversations/conversations.service.ts
- backend/src/conversations/conversations.controller.ts
- backend/src/conversations/conversations.module.ts (unchanged; included for reference)

What this implements:
- Per-store Telegram bot connection using POST /api/v1/conversations/telegram/connect
- Bot token validation with Telegram getMe; webhook removal so long polling can be used
- Token encrypted before saving in ChannelConnection.accessTokenEncrypted
- Long polling resumes at backend startup and polls each active TELEGRAM connection
- Incoming private text/caption messages are stored in the existing conversation inbox
- Automated AI replies and staff replies are sent through Telegram sendMessage
- Telegram is not subject to Meta's 24-hour reply window
- Disconnect endpoint: DELETE /api/v1/conversations/telegram/:id
- Existing Instagram, Messenger, Website, order confirmation and per-store boundaries remain in place

Security/configuration:
- Never put a bot token in source code or commit it to Git.
- The service uses the existing META_TOKEN_ENCRYPTION_KEY first, preserving the key already used for Meta tokens.
- If META_TOKEN_ENCRYPTION_KEY is not configured, TOKEN_ENCRYPTION_KEY can be used instead; use 64 hexadecimal characters (32 bytes).
- Do not change the key after tokens have been encrypted. Generate a key locally with: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
- Do not send bot tokens or encryption keys in chat.

Connect API:
POST /api/v1/conversations/telegram/connect
Authorization: Bearer <your NEXOR access token>
Content-Type: application/json
Body: {"botToken":"<Telegram BotFather token>"}

The API returns the channel connection id. The connection is created with AI auto-reply enabled.
To disconnect:
DELETE /api/v1/conversations/telegram/<connection-id>
Authorization: Bearer <your NEXOR access token>

Operational notes:
- This first implementation accepts Telegram private chats only, and text/caption messages.
- The bot owner must open the bot and press Start/send a message before the bot can reply.
- One Telegram bot can be connected to only one NEXOR store because the schema has a unique (channel, externalAccountId) constraint.
- Long polling runs on the machine hosting the NestJS backend. Do not run duplicate backend instances polling the same bot simultaneously.
- The frontend does not yet include a dedicated Telegram token-entry screen; connect through an authenticated API client until the Flutter screen is added.
