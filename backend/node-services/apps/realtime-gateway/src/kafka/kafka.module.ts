import { Module } from '@nestjs/common';
import { KafkaConsumer } from './kafka.consumer';
import { GatewayModule } from '../gateway/gateway.module';

@Module({
  imports: [GatewayModule],
  providers: [KafkaConsumer],
  exports: [KafkaConsumer],
})
export class KafkaModule {}
