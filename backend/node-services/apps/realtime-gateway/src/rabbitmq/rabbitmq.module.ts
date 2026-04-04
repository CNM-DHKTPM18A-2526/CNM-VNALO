import { Module, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { RabbitMQConsumer } from './rabbitmq.consumer';
import { GatewayModule } from '../gateway/gateway.module';

@Module({
  imports: [GatewayModule],
  providers: [RabbitMQConsumer],
  exports: [RabbitMQConsumer],
})
export class RabbitMQModule implements OnModuleInit, OnModuleDestroy {
  constructor(private readonly consumer: RabbitMQConsumer) {}

  async onModuleInit() {
    await this.consumer.connect();
  }

  async onModuleDestroy() {
    await this.consumer.disconnect();
  }
}
