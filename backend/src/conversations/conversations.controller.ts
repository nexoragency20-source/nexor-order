import {
  Body,
  Headers,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from "@nestjs/common";
import { CurrentUser } from "../auth/decorators/current-user.decorator.js";
import { JwtAuthGuard } from "../auth/guards/jwt-auth.guard.js";
import type { AccessTokenPayload } from "../auth/interfaces/access-token-payload.interface.js";
import {
  SendConversationMessageDto,
  ToggleChannelAutomationDto,
  ToggleConversationAutomationDto,
  UpdateConversationStatusDto,
} from "./dto/conversations.dto.js";
import { ConversationsService } from "./conversations.service.js";
import { SetupWebsiteChatDto, WebsiteChatMessageDto } from "./dto/website-chat.dto.js";

@Controller("conversations")
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Post("website/setup")
  @UseGuards(JwtAuthGuard)
  setupWebsiteChat(
    @CurrentUser() user: AccessTokenPayload,
    @Body() dto: SetupWebsiteChatDto,
  ) {
    return this.conversationsService.setupWebsiteChat(user, dto.allowedOrigins);
  }

  @Post("website/demo/setup")
  @UseGuards(JwtAuthGuard)
  setupWebsiteDemo(@CurrentUser() user: AccessTokenPayload) {
    return this.conversationsService.setupWebsiteDemo(user);
  }

  @Get("website/demo/:publicKey")
  async websiteDemo(@Param("publicKey") publicKey: string, @Res() response: any) {
    const html = await this.conversationsService.websiteDemoPage(publicKey);
    response
      .status(200)
      .type("html")
      .header("Cache-Control", "no-store")
      .header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'")
      .send(html);
  }

  @Get("website/widget.js")
  websiteWidget(@Res() response: any) {
    response
      .status(200)
      .type("application/javascript; charset=utf-8")
      .header("Cache-Control", "public, max-age=300")
      .send(this.conversationsService.websiteWidgetScript());
  }

  @Post("website/:publicKey/messages")
  @HttpCode(200)
  receiveWebsiteMessage(
    @Param("publicKey") publicKey: string,
    @Body() dto: WebsiteChatMessageDto,
    @Req() request: any,
  ) {
    return this.conversationsService.receiveWebsiteMessage(
      publicKey,
      dto,
      String(request.headers?.origin ?? request.headers?.referer ?? ""),
      String(request.ip ?? "unknown"),
    );
  }

  @Get("website/:publicKey/messages/:conversationId")
  websiteMessages(
    @Param("publicKey") publicKey: string,
    @Param("conversationId") conversationId: string,
    @Headers("x-nexor-session") sessionToken: string,
    @Req() request: any,
  ) {
    return this.conversationsService.getWebsiteMessages(
      publicKey,
      conversationId,
      String(sessionToken ?? ""),
      String(request.headers?.origin ?? request.headers?.referer ?? ""),
    );
  }

  @Get("connect-url")
  @UseGuards(JwtAuthGuard)
  connectUrl(
    @CurrentUser() user: AccessTokenPayload,
    @Query("channel") channel: string,
  ) {
    return this.conversationsService.createConnectUrl(user, channel);
  }

  @Post("telegram/connect")
  @UseGuards(JwtAuthGuard)
  connectTelegram(
    @CurrentUser() user: AccessTokenPayload,
    @Body("botToken") botToken: string,
  ) {
    return this.conversationsService.connectTelegram(user, botToken);
  }

  @Delete("telegram/:id")
  @UseGuards(JwtAuthGuard)
  disconnectTelegram(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
  ) {
    return this.conversationsService.disconnectTelegram(user, id);
  }

  @Get("channels")
  @UseGuards(JwtAuthGuard)
  channels(@CurrentUser() user: AccessTokenPayload) {
    return this.conversationsService.listChannels(user);
  }

  @Patch("channels/:id/automation")
  @UseGuards(JwtAuthGuard)
  toggleChannelAutomation(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
    @Body() dto: ToggleChannelAutomationDto,
  ) {
    return this.conversationsService.toggleChannelAutomation(
      user,
      id,
      dto.enabled,
    );
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  list(
    @CurrentUser() user: AccessTokenPayload,
    @Query("status") status?: string,
    @Query("channel") channel?: string,
  ) {
    return this.conversationsService.listConversations(user, status, channel);
  }

  @Get(":id/messages")
  @UseGuards(JwtAuthGuard)
  messages(@CurrentUser() user: AccessTokenPayload, @Param("id") id: string) {
    return this.conversationsService.getMessages(user, id);
  }

  @Post(":id/messages")
  @UseGuards(JwtAuthGuard)
  sendMessage(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
    @Body() dto: SendConversationMessageDto,
  ) {
    return this.conversationsService.sendMessage(user, id, dto.text);
  }

  @Patch(":id/automation")
  @UseGuards(JwtAuthGuard)
  toggleConversationAutomation(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
    @Body() dto: ToggleConversationAutomationDto,
  ) {
    return this.conversationsService.toggleConversationAutomation(
      user,
      id,
      dto.paused,
    );
  }

  @Patch(":id/status")
  @UseGuards(JwtAuthGuard)
  updateStatus(
    @CurrentUser() user: AccessTokenPayload,
    @Param("id") id: string,
    @Body() dto: UpdateConversationStatusDto,
  ) {
    return this.conversationsService.updateStatus(user, id, dto.status);
  }

  // Meta OAuth callback. Keep this endpoint public; the one-time state is checked server-side.
  @Get("oauth/callback")
  async oauthCallback(@Req() request: any, @Res() response: any) {
    try {
      const result = await this.conversationsService.handleOAuthCallback(
        request.query ?? {},
      );
      response
        .status(200)
        .type("html")
        .send(this.resultHtml(true, result.message));
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "تعذر إكمال الربط مع Meta.";
      response.status(200).type("html").send(this.resultHtml(false, message));
    }
  }

  @Get("webhook")
  verifyWebhook(@Req() request: any, @Res() response: any) {
    const query = request.query ?? {};
    const result = this.conversationsService.verifyWebhook(
      String(query["hub.mode"] ?? ""),
      String(query["hub.verify_token"] ?? ""),
      String(query["hub.challenge"] ?? ""),
    );
    if (result === null) {
      response.status(403).send("Forbidden");
      return;
    }
    response.status(200).type("text/plain").send(result);
  }

  @Post("webhook")
  @HttpCode(200)
  async receiveWebhook(@Req() request: any) {
    const rawBody: Buffer | undefined = request.rawBody;
    this.conversationsService.assertWebhookSignature(
      rawBody,
      request.headers?.["x-hub-signature-256"],
    );
    await this.conversationsService.receiveWebhook(request.body ?? {});
    return { received: true };
  }

  private resultHtml(success: boolean, message: string): string {
    const safe = message
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
    const color = success ? "#20b98f" : "#e36e77";
    return `<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>NEXOR Meta Connect</title><body style="margin:0;background:#11131b;color:#f7f7fb;font-family:Arial,sans-serif;display:grid;min-height:100vh;place-items:center"><main style="width:min(520px,calc(100% - 36px));padding:32px;border:1px solid #343347;border-radius:22px;background:#1b1d29;box-sizing:border-box;text-align:center"><div style="font-size:13px;letter-spacing:4px;color:#a59cff;font-weight:900">NEXOR</div><div style="font-size:24px;font-weight:900;margin:18px 0;color:${color}">${success ? "تم ربط القناة" : "تعذر إكمال الربط"}</div><p style="line-height:1.9;color:#c8c7d4">${safe}</p><p style="font-size:12px;color:#88879a">ارجع إلى تبويب NEXOR واضغط «تحديث الاتصالات».</p></main></body></html>`;
  }
}
