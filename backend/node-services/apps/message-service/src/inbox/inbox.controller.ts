import { Controller, Get, Query, Patch, Delete, Param, Body, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/user.decorator';
import { InboxService } from './inbox.service';
import { UpdateInboxSettingsDto } from '../dto/update-inbox-settings.dto';

@Controller('inbox')
@UseGuards(JwtAuthGuard)
export class InboxController {
  constructor(private readonly inboxService: InboxService) {}

  private buildAccessContext(user: AuthUser) {
    return {
      clientPlatform: user.clientPlatform ?? 'WEB',
      restrictedWebMode: Boolean(user.restrictedWebMode),
      loginAtEpochSec: user.loginAtEpochSec,
    };
  }

  /** Get user's conversation list sorted by pinned + latest message. */
  @Get()
  getInbox(
    @CurrentUser() user: AuthUser,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.inboxService.getInbox(user.userId, limit, offset, this.buildAccessContext(user));
  }

  /** Get total unread count badge number. */
  @Get('unread-count')
  getUnreadCount(@CurrentUser() user: AuthUser) {
    return this.inboxService.getTotalUnreadCount(user.userId, this.buildAccessContext(user));
  }

  /** Update personal settings for a conversation (Pin/Mute/Hide). */
  @Patch(':conversationId')
  updateSettings(
    @CurrentUser() user: AuthUser,
    @Param('conversationId') conversationId: string,
    @Body() dto: UpdateInboxSettingsDto,
  ) {
    return this.inboxService.updateSettings(user.userId, conversationId, dto);
  }

  /** Hide history (clear chat) for the user. */
  @Delete(':conversationId/history')
  clearHistory(
    @CurrentUser() user: AuthUser,
    @Param('conversationId') conversationId: string,
  ) {
    return this.inboxService.clearHistory(user.userId, conversationId);
  }
}
