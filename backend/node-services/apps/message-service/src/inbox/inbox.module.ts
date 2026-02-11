import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { Conversation } from '../entities/conversation.entity';
import { InboxService } from './inbox.service';
import { InboxController } from './inbox.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ConversationInbox, Conversation])],
  controllers: [InboxController],
  providers: [InboxService],
  exports: [InboxService],
})
export class InboxModule {}
