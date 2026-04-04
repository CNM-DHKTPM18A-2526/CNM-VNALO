import { Module } from '@nestjs/common';
import { ChatGateway } from './chat.gateway';
import { MessageModule } from '../message/message.module';
import { AuthModule } from '../auth/auth.module';
import { ConversationModule } from '../conversation/conversation.module';

@Module({
  imports: [MessageModule, AuthModule, ConversationModule],
  providers: [ChatGateway],
  exports: [ChatGateway],
})
export class GatewayModule {}
