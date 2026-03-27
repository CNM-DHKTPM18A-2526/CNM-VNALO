import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as amqplib from 'amqplib';
import { RealtimeGateway } from '../gateway/realtime.gateway';

/**
 * RabbmitMQ Consumer cho realtime-gateway.
 *
 * Nhận message từ queue `realtime.broadcast` và broadcast qua WebSocket.
 *
 * Message format:
 * {
 *   type: 'message.new' | 'message.recalled' | 'message.reaction' | 'notification',
 *   room?: string,        // 'conversation:{id}' — broadcast tới room
 *   userId?: string,      // broadcast tới 1 user cụ thể
 *   payload: any
 * }
 */
@Injectable()
export class RabbitMQConsumer {
  private readonly logger = new Logger(RabbitMQConsumer.name);
  private connection: any;
  private channel: any;
  private isConnected = false;

  private readonly queue = 'realtime.broadcast';
  private readonly exchange = 'vnalo.realtime';

  constructor(
    private readonly configService: ConfigService,
    private readonly gateway: RealtimeGateway,
  ) { }

  async connect(): Promise<void> {
    const url = (this.configService.get<string>('rabbit.url') ?? 'amqp://guest:guest@localhost:5672');
    try {
      this.connection = await amqplib.connect(url);
      this.channel = await this.connection.createChannel();

      // Khai báo exchange + queue
      await this.channel.assertExchange(this.exchange, 'direct', { durable: true });
      await this.channel.assertQueue(this.queue, { durable: true });
      await this.channel.bindQueue(this.queue, this.exchange, 'broadcast');

      this.channel.prefetch(10);
      this.isConnected = true;
      this.logger.log(`Connected to RabbitMQ — consuming queue: ${this.queue}`);

      await this.startConsuming();

      // Reconnect on close
      this.connection.on('close', async () => {
        this.isConnected = false;
        this.logger.warn('RabbitMQ connection closed. Reconnecting in 5s...');
        // Đóng channel cũ trước khi reconnect để tránh duplicate consumer
        try { await this.channel?.close(); } catch { /* ignore */ }
        this.channel = null;
        setTimeout(() => this.connect(), 5000);
      });

      this.connection.on('error', (err) => {
        this.logger.error(`RabbitMQ error: ${err.message}`);
      });
    } catch (err) {
      this.logger.error(`Failed to connect to RabbitMQ: ${err.message}. Retry in 10s...`);
      setTimeout(() => this.connect(), 10000);
    }
  }

  private async startConsuming(): Promise<void> {
    this.channel.consume(this.queue, (msg) => {
      if (!msg) return;
      try {
        const event = JSON.parse(msg.content.toString());
        this.handleEvent(event);
        this.channel.ack(msg);
      } catch (err) {
        this.logger.error(`Error processing message: ${err.message}`);
        this.channel.nack(msg, false, false); // discard bad message
      }
    });
  }

  private handleEvent(event: { type: string; room?: string; userId?: string; payload: any }): void {
    this.logger.debug(`Event received: ${event.type}`);

    if (event.room) {
      // Broadcast tới cả room
      this.gateway.broadcastToRoom(event.room, event.type, event.payload);
    } else if (event.userId) {
      // Emit tới user cụ thể
      this.gateway.emitToUser(event.userId, event.type, event.payload);
    } else {
      this.logger.warn(`Event has no room or userId: ${JSON.stringify(event)}`);
    }
  }

  async disconnect(): Promise<void> {
    try {
      await this.channel?.close();
      await this.connection?.close();
    } catch (err) {
      this.logger.error(`Error disconnecting RabbitMQ: ${err.message}`);
    }
  }
}
