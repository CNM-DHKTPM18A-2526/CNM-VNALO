import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { Conversation } from '../entities/conversation.entity';
import { ConversationMember } from '../entities/conversation-member.entity';
import { InboxService } from './inbox.service';
import { InboxController } from './inbox.controller';
import { GatewayModule } from '../gateway/gateway.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      ConversationInbox,
      Conversation,
      ConversationMember,
    ]),
    GatewayModule,
  ],
  controllers: [InboxController],
  providers: [InboxService],
  exports: [InboxService],
})
export class InboxModule {}
