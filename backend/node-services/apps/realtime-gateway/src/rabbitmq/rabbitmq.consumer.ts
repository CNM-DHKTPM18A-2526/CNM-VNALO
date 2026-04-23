import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as amqplib from 'amqplib';
import { RealtimeGateway } from '../gateway/realtime.gateway';

/**
 * RabbitMQ Consumer cho realtime-gateway.
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
  private connection: Awaited<ReturnType<typeof amqplib.connect>> | null = null;
  private channel: amqplib.Channel | null = null;
  private isConnected = false;
  private isConnecting = false;
  private reconnectTimer: NodeJS.Timeout | null = null;

  private readonly queue = 'realtime.broadcast';
  private readonly exchange = 'vnalo.realtime';

  constructor(
    private readonly configService: ConfigService,
    private readonly gateway: RealtimeGateway,
  ) {}

  async connect(): Promise<void> {
    if (this.isConnected || this.isConnecting) {
      return;
    }
    this.isConnecting = true;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    const url =
      this.configService.get<string>('rabbit.url') ??
      'amqp://guest:guest@localhost:5672';
    try {
      const connection = await amqplib.connect(url);
      const channel = await connection.createChannel();
      this.connection = connection;
      this.channel = channel;

      // Khai báo exchange + queue
      await channel.assertExchange(this.exchange, 'direct', { durable: true });
      await channel.assertQueue(this.queue, { durable: true });
      await channel.bindQueue(this.queue, this.exchange, 'broadcast');

      channel.prefetch(10);
      this.isConnected = true;
      this.isConnecting = false;
      this.logger.log(`Connected to RabbitMQ — consuming queue: ${this.queue}`);

      await this.startConsuming();

      // Reconnect on close
      connection.on('close', async () => {
        this.isConnected = false;
        this.isConnecting = false;
        this.logger.warn('RabbitMQ connection closed. Reconnecting in 5s...');
        // Đóng channel cũ trước khi reconnect để tránh duplicate consumer
        try {
          await this.channel?.close();
        } catch {
          /* ignore */
        }
        this.channel = null;
        this.connection = null;
        this.reconnectTimer = setTimeout(() => this.connect(), 5000);
      });

      connection.on('error', (err) => {
        this.logger.error(`RabbitMQ error: ${err.message}`);
      });
    } catch (err) {
      this.isConnecting = false;
      this.logger.error(
        `Failed to connect to RabbitMQ: ${err.message}. Retry in 10s...`,
      );
      this.reconnectTimer = setTimeout(() => this.connect(), 10000);
    }
  }

  private async startConsuming(): Promise<void> {
    if (!this.channel) {
      return;
    }
    this.channel.consume(this.queue, (msg) => {
      if (!msg) return;
      try {
        const event = JSON.parse(msg.content.toString());
        this.handleEvent(event);
        this.channel?.ack(msg);
      } catch (err) {
        this.logger.error(`Error processing message: ${err.message}`);
        this.channel?.nack(msg, false, false); // discard bad message
      }
    });
  }

  private handleEvent(event: {
    type: string;
    room?: string;
    userId?: string;
    payload: any;
  }): void {
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
      if (this.reconnectTimer) {
        clearTimeout(this.reconnectTimer);
        this.reconnectTimer = null;
      }
      await this.channel?.close();
      await this.connection?.close();
      this.channel = null;
      this.connection = null;
      this.isConnected = false;
      this.isConnecting = false;
    } catch (err) {
      this.logger.error(`Error disconnecting RabbitMQ: ${err.message}`);
    }
  }
}
