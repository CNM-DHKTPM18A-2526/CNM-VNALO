import { Module } from '@nestjs/common';
import { ChatGateway } from './chat.gateway';
import { MessageModule } from '../message/message.module';

@Module({
  imports: [MessageModule],
  providers: [ChatGateway],
  exports: [ChatGateway],
})
export class GatewayModule {}
