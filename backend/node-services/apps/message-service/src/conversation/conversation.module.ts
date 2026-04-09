import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Conversation } from '../entities/conversation.entity';
import { ConversationMember } from '../entities/conversation-member.entity';
import { ConversationDirectMap } from '../entities/conversation-direct-map.entity';
import { ConversationJoinRequest } from '../entities/conversation-join-request.entity';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { ConversationService } from './conversation.service';
import { ConversationController } from './conversation.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Conversation,
      ConversationMember,
      ConversationDirectMap,
      ConversationJoinRequest,
      ConversationInbox,
    ]),
  ],
  controllers: [ConversationController],
  providers: [ConversationService],
  exports: [ConversationService],
})
export class ConversationModule {}
