import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/user.decorator';
import { InboxService } from './inbox.service';

@Controller('inbox')
@UseGuards(JwtAuthGuard)
export class InboxController {
  constructor(private readonly inboxService: InboxService) {}

  /** Get user's conversation list sorted by pinned + latest message. */
  @Get()
  getInbox(
    @CurrentUser() user: AuthUser,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.inboxService.getInbox(user.userId, limit, offset);
  }

  /** Get total unread count badge number. */
  @Get('unread-count')
  getUnreadCount(@CurrentUser() user: AuthUser) {
    return this.inboxService.getTotalUnreadCount(user.userId);
  }
}
