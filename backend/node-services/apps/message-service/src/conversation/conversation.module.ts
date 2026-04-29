import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Conversation } from '../entities/conversation.entity';
import { ConversationMember } from '../entities/conversation-member.entity';
import { ConversationDirectMap } from '../entities/conversation-direct-map.entity';
import { ConversationJoinRequest } from '../entities/conversation-join-request.entity';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { ConversationService } from './conversation.service';
import { ConversationController } from './conversation.controller';
import { KafkaProducerModule } from '../kafka/kafka-producer.module';
import { MessageModule } from '../message/message.module';
import { MembershipCacheService } from './membership-cache.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Conversation,
      ConversationMember,
      ConversationDirectMap,
      ConversationJoinRequest,
      ConversationInbox,
    ]),
    KafkaProducerModule,
    forwardRef(() => MessageModule),
  ],
  controllers: [ConversationController],
  providers: [ConversationService, MembershipCacheService],
  exports: [ConversationService, MembershipCacheService],
})
export class ConversationModule {}
