import {
  Controller,
  Post,
  Get,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../auth/user.decorator';
import { ConversationService } from './conversation.service';
import { CreateDirectConversationDto } from '../dto/create-direct-conversation.dto';
import { CreateGroupConversationDto } from '../dto/create-group-conversation.dto';
import { UpdateConversationDto } from '../dto/update-conversation.dto';
import { AddMembersDto } from '../dto/add-members.dto';

@Controller('conversations')
@UseGuards(JwtAuthGuard)
export class ConversationController {
  constructor(private readonly conversationService: ConversationService) {}

  @Post('direct')
  createDirect(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateDirectConversationDto,
  ) {
    return this.conversationService.createDirect(user.userId, dto.targetUserId);
  }

  @Post('group')
  createGroup(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateGroupConversationDto,
  ) {
    return this.conversationService.createGroup(user.userId, dto);
  }

  @Get(':id')
  getConversation(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.conversationService.getConversation(id, user.userId);
  }

  @Patch(':id')
  updateGroup(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateConversationDto,
  ) {
    return this.conversationService.updateGroup(id, user.userId, dto);
  }

  @Post(':id/members')
  addMembers(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AddMembersDto,
  ) {
    return this.conversationService.addMembers(id, user.userId, dto.memberIds);
  }

  @Delete(':id/members/:userId')
  removeMember(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('userId') targetUserId: string,
  ) {
    return this.conversationService.removeMember(id, user.userId, targetUserId);
  }

  @Get(':id/members')
  getMembers(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.conversationService.getMembers(id, user.userId);
  }

  @Post(':id/join')
  requestJoin(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.conversationService.requestJoin(id, user.userId);
  }

  @Get(':id/join-requests')
  getJoinRequests(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.conversationService.getJoinRequests(id, user.userId);
  }

  @Post(':id/join-requests/:userId/approve')
  approveJoinRequest(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('userId') targetUserId: string,
  ) {
    return this.conversationService.approveJoinRequest(
      id,
      user.userId,
      targetUserId,
    );
  }

  @Delete(':id/join-requests/:userId')
  rejectJoinRequest(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('userId') targetUserId: string,
  ) {
    return this.conversationService.rejectJoinRequest(
      id,
      user.userId,
      targetUserId,
    );
  }

  @Patch(':id/member/:targetUserId')
  updateMember(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('targetUserId') targetUserId: string,
    @Body() dto: { nickname?: string; role?: string },
  ) {
    return this.conversationService.updateMember(
      id,
      user.userId,
      targetUserId,
      dto,
    );
  }

  @Patch(':id/wallpaper')
  updateWallpaper(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: { wallpaperUrl: string; isGlobal?: boolean },
  ) {
    return this.conversationService.updateWallpaper(
      id,
      user.userId,
      dto.wallpaperUrl,
      dto.isGlobal ?? true,
    );
  }

  /** Disband (permanently delete) a group. Only group ADMIN. D-012. */
  @Delete(':id')
  disbandGroup(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.conversationService.disbandGroup(id, user.userId);
  }
}
