import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/user.decorator';
import { MessageService } from './message.service';
import { SendMessageDto } from '../dto/send-message.dto';
import { EditMessageDto } from '../dto/edit-message.dto';
import { MessageReactionDto } from '../dto/message-reaction.dto';
import { MarkReadDto } from '../dto/mark-read.dto';
import { PaginationDto } from '../dto/pagination.dto';
import { SearchMessagesDto } from '../dto/search-messages.dto';

@Controller()
@UseGuards(JwtAuthGuard)
export class MessageController {
  constructor(private readonly messageService: MessageService) {}

  private buildAccessContext(user: AuthUser) {
    return {
      clientPlatform: user.clientPlatform ?? 'WEB',
      restrictedWebMode: Boolean(user.restrictedWebMode),
      loginAtEpochSec: user.loginAtEpochSec,
    };
  }

  /** Send a message via REST (alternative to WebSocket). */
  @Post('messages')
  sendMessage(@CurrentUser() user: AuthUser, @Body() dto: SendMessageDto) {
    return this.messageService.sendMessage(
      user.userId,
      dto,
      this.buildAccessContext(user),
    );
  }

  /** Get paginated message history for a conversation. */
  @Get('conversations/:id/messages')
  getMessages(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query() pagination: PaginationDto,
  ) {
    return this.messageService.getMessages(
      id,
      user.userId,
      pagination.before,
      pagination.limit,
      this.buildAccessContext(user),
      pagination.forceSync,
    );
  }

  /** Search messages in a conversation by keyword and/or media type. */
  @Get('conversations/:id/messages/search')
  searchMessages(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query() search: SearchMessagesDto,
  ) {
    return this.messageService.searchMessages(
      id,
      user.userId,
      search.keyword,
      search.messageType,
      search.limit,
      search.offset,
      this.buildAccessContext(user),
    );
  }

  @Patch('messages/:id')
  editMessage(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: EditMessageDto,
  ) {
    return this.messageService.editMessage(user.userId, id, dto.content);
  }

  @Delete('messages/:id')
  recallMessage(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messageService.recallMessage(user.userId, id);
  }

  @Delete('messages/:id/for-me')
  deleteForMe(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messageService.deleteForMe(user.userId, id);
  }

  // ─── Reactions ──────────────────────────────────
  @Post('messages/:id/reactions')
  addReaction(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: MessageReactionDto,
  ) {
    return this.messageService.addReaction(user.userId, id, dto.emoji);
  }

  @Delete('messages/:id/reactions')
  removeReaction(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messageService.removeReaction(user.userId, id);
  }

  @Get('messages/:id/reactions')
  getReactions(@Param('id') id: string) {
    return this.messageService.getReactions(id);
  }

  // ─── Pins ───────────────────────────────────────
  @Post('conversations/:id/pin/:messageId')
  pinMessage(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('messageId') messageId: string,
  ) {
    return this.messageService.pinMessage(user.userId, id, messageId);
  }

  @Delete('conversations/:id/pin/:messageId')
  unpinMessage(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('messageId') messageId: string,
  ) {
    return this.messageService.unpinMessage(user.userId, id, messageId);
  }

  @Get('conversations/:id/pins')
  getPinnedMessages(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.messageService.getPinnedMessages(id, user.userId);
  }

  // ─── Read Receipts ──────────────────────────────
  @Post('conversations/:id/read')
  markAsRead(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: MarkReadDto,
  ) {
    return this.messageService.markAsRead(user.userId, id, dto.lastReadSeq);
  }
}
