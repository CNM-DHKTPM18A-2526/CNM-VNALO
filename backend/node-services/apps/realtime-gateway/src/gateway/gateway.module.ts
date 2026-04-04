import { Module } from '@nestjs/common';
import { RealtimeGateway } from './realtime.gateway';
import { PresenceModule } from '../presence/presence.module';

@Module({
  imports: [PresenceModule],
  providers: [RealtimeGateway],
  exports: [RealtimeGateway],
})
export class GatewayModule {}
