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
    const redisOptions: RedisOptions = { host: redisHost, port: redisPort };
    if (redisPassword) {
      redisOptions.password = redisPassword;
    }
    const pubClient = new Redis(redisOptions);
    const subClient = pubClient.duplicate();

    const timeout = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('Redis connection timeout (10s)')), 10000),
    );

    try {
      await Promise.race([
        Promise.all([
          new Promise<void>((resolve, reject) => {
            pubClient.once('ready', resolve);
            pubClient.once('error', reject);
          }),
          new Promise<void>((resolve, reject) => {
            subClient.once('ready', resolve);
            subClient.once('error', reject);
          }),
        ]),
        timeout,
      ]);
    } catch (err) {
      pubClient.disconnect();
      subClient.disconnect();
      throw err;
    }

    this.adapterConstructor = createAdapter(pubClient, subClient);
    this.logger.log(`Redis adapter connected to ${redisHost}:${redisPort}`);
  }

  createIOServer(port: number, options?: ServerOptions): unknown {
    const server = super.createIOServer(port, options) as {
      adapter: (adapter: unknown) => void;
      _nsps: Map<string, unknown>;
    };
    server.adapter(this.adapterConstructor);
    server._nsps.forEach((nsp: unknown) => {
      (nsp as { adapter: unknown }).adapter = this.adapterConstructor;
    });
    return server;
  }
}
