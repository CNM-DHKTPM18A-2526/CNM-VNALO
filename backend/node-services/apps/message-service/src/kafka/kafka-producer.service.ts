import { Injectable, Logger, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Kafka, Producer, CompressionTypes, logLevel } from 'kafkajs';

@Injectable()
export class KafkaProducerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(KafkaProducerService.name);
  private kafka: Kafka;
  private producer: Producer;
  private isConnected = false;
  private readonly brokers: string[];
  private readonly clientId: string;
  private readonly notificationsTopic: string;

  constructor(private readonly configService: ConfigService) {
    this.brokers = this.configService.get('kafka.brokers') ?? ['localhost:9092'];
    this.clientId = this.configService.get('kafka.clientId') ?? 'vnalo-message-service';
    this.notificationsTopic = this.configService.get('kafka.notificationsTopic') ?? 'vnalo.notifications';

    this.kafka = new Kafka({
      clientId: this.clientId,
      brokers: this.brokers,
      logLevel: logLevel.WARN,
      retry: {
        initialRetryTime: 100,
        retries: 3,
      },
    });

    this.producer = this.kafka.producer({
      allowAutoTopicCreation: false,
      transactionTimeout: 30000,
    });
  }

  async onModuleInit() {
    try {
      await this.producer.connect();
      this.isConnected = true;
      this.logger.log(
        `Kafka producer connected to brokers: ${this.brokers.join(', ')}`,
      );
    } catch (error) {
      this.logger.warn(
        `Failed to connect to Kafka: ${error.message}. Notifications will not be sent.`,
      );
      this.isConnected = false;
    }
  }

  async onModuleDestroy() {
    if (this.isConnected) {
      await this.producer.disconnect();
      this.logger.log('Kafka producer disconnected');
    }
  }

  /**
   * Publish a notification event to Kafka.
   * This is sent asynchronously - failures are logged but don't block the caller.
   *
   * @param event - The notification event payload
   */
  async publishNotification(event: NotificationEventPayload): Promise<void> {
    if (!this.isConnected) {
      this.logger.warn(
        'Kafka producer not connected. Skipping notification publish.',
      );
      return;
    }

    try {
      await this.producer.send({
        topic: this.notificationsTopic,
        compression: CompressionTypes.GZIP,
        messages: [
          {
            key: event.userId,
            value: JSON.stringify(event),
            headers: {
              'event-type': event.eventType,
              'content-type': 'application/json',
            },
          },
        ],
      });

      this.logger.log(
        `Notification published: eventId=${event.eventId} userId=${event.userId} type=${event.eventType}`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to publish notification: ${error.message}`,
        error.stack,
      );
    }
  }
}

/**
 * Notification event payload structure.
 * Must match the NotificationEvent record in notification-service.
 */
export interface NotificationEventPayload {
  eventId: string;
  eventType: string;
  userId: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  createdAt: string;
}
