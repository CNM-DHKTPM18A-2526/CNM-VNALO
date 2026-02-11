import {
  Controller, Get, Post, Patch, Delete, Param, Body, Query, UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/user.decorator';
import { MessageService } from './message.service';
import { SendMessageDto } from '../dto/send-message.dto';
import { EditMessageDto } from '../dto/edit-message.dto';
import { MessageReactionDto } from '../dto/message-reaction.dto';
import { MarkReadDto } from '../dto/mark-read.dto';
import { PaginationDto } from '../dto/pagination.dto';

@Controller()
@UseGuards(JwtAuthGuard)
export class MessageController {
  constructor(private readonly messageService: MessageService) {}

  /** Send a message via REST (alternative to WebSocket). */
  @Post('messages')
  sendMessage(@CurrentUser() user: AuthUser, @Body() dto: SendMessageDto) {
    return this.messageService.sendMessage(user.userId, dto);
  }

  /** Get paginated message history for a conversation. */
  @Get('conversations/:id/messages')
  getMessages(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Query() pagination: PaginationDto,
  ) {
    return this.messageService.getMessages(id, user.userId, pagination.before, pagination.limit);
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
