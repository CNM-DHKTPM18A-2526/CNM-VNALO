import { IoAdapter } from '@nestjs/platform-socket.io';
import { ServerOptions } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { Redis, RedisOptions } from 'ioredis';
import { Logger } from '@nestjs/common';

export class RedisIoAdapter extends IoAdapter {
  private adapterConstructor: ReturnType<typeof createAdapter>;
  private readonly logger = new Logger(RedisIoAdapter.name);

  async connectToRedis(
    redisHost: string,
    redisPort: number,
    redisPassword?: string,
  ): Promise<void> {
    const redisOptions: RedisOptions = {
      host: redisHost,
      port: redisPort,
    };
    if (redisPassword) {
      redisOptions.password = redisPassword;
    }
    const pubClient = new Redis(redisOptions);
    const subClient = pubClient.duplicate();

    await Promise.all([
      new Promise<void>((resolve, reject) => {
        pubClient.once('ready', resolve);
        pubClient.once('error', reject);
      }),
      new Promise<void>((resolve, reject) => {
        subClient.once('ready', resolve);
        subClient.once('error', reject);
      }),
    ]);

    this.adapterConstructor = createAdapter(pubClient, subClient);
    this.logger.log(`Redis adapter connected to ${redisHost}:${redisPort}`);
  }

  createIOServer(port: number, options?: ServerOptions): unknown {
    const server = super.createIOServer(port, options);
    (server as unknown as { adapter: typeof this.adapterConstructor }).adapter =
      this.adapterConstructor;
    return server;
  }
}
