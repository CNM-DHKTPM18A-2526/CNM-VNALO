import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Message } from '../entities/message.entity';
import { MessageReaction } from '../entities/message-reaction.entity';
import { MessageReceipt } from '../entities/message-receipt.entity';
import { PinnedMessage } from '../entities/pinned-message.entity';
import { ConversationInbox } from '../entities/conversation-inbox.entity';
import { ConversationMember } from '../entities/conversation-member.entity';
import { MessageService } from './message.service';
import { MessageController } from './message.controller';
import { ConversationModule } from '../conversation/conversation.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Message,
      MessageReaction,
      MessageReceipt,
      PinnedMessage,
      ConversationInbox,
      ConversationMember,
    ]),
    forwardRef(() => ConversationModule),
  ],
  controllers: [MessageController],
  providers: [MessageService],
  exports: [MessageService],
})
export class MessageModule {}
