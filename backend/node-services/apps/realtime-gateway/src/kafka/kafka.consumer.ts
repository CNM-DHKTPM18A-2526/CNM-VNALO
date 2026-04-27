import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Kafka, Consumer } from 'kafkajs';
import { RealtimeGateway } from '../gateway/realtime.gateway';

@Injectable()
export class KafkaConsumer implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(KafkaConsumer.name);
  private kafka: Kafka;
  private consumer: Consumer;
  private isConnected = false;

  constructor(
    private readonly configService: ConfigService,
    private readonly gateway: RealtimeGateway,
  ) {
    const brokers = this.configService.get<string[]>('kafka.brokers') ?? ['localhost:9092'];
    const clientId = this.configService.get<string>('kafka.clientId') ?? 'vnalo-realtime-gateway';

    this.kafka = new Kafka({
      clientId,
      brokers,
    });

    this.consumer = this.kafka.consumer({
      groupId: 'realtime-gateway-group',
    });
  }

  async onModuleInit() {
    await this.connect();
  }

  async onModuleDestroy() {
    await this.consumer.disconnect();
  }

  async connect() {
    try {
      await this.consumer.connect();
      this.isConnected = true;
      this.logger.log('Connected to Kafka');

      const topic = this.configService.get<string>('kafka.realtimeTopic') ?? 'vnalo.realtime.events';
      await this.consumer.subscribe({ topic, fromBeginning: false });

      await this.consumer.run({
        eachMessage: async ({ message }) => {
          if (!message.value) return;
          try {
            const event = JSON.parse(message.value.toString());
            this.handleEvent(event);
          } catch (err) {
            this.logger.error(`Error parsing Kafka message: ${err.message}`);
          }
        },
      });
    } catch (err) {
      this.logger.error(`Failed to connect to Kafka: ${err.message}`);
      // Reconnect logic could be added here if needed, 
      // but kafkajs has some built-in retry logic.
    }
  }

  private handleEvent(event: {
    type: string;
    userId: string;
    payload: any;
  }) {
    this.logger.debug(`Kafka event received: ${event.type} for user ${event.userId}`);
    if (event.userId) {
      this.gateway.emitToUser(event.userId, event.type, event.payload);
    }
  }
}
