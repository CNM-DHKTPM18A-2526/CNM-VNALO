import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { RedisModule } from '@nestjs-modules/ioredis';
import { HealthController } from './health.controller';
import { GatewayModule } from './gateway/gateway.module';
import { PresenceModule } from './presence/presence.module';
import { RabbitMQModule } from './rabbitmq/rabbitmq.module';
import { KafkaModule } from './kafka/kafka.module';
import { redisConfig, jwtConfig, rabbitConfig, kafkaConfig } from './config/app.config';

@Module({
  imports: [
    // Load env vars
    ConfigModule.forRoot({
      isGlobal: true,
      load: [redisConfig, jwtConfig, rabbitConfig, kafkaConfig],
      envFilePath: ['.env'],
    }),

    // Redis — cho PresenceService
    RedisModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const host = config.get('redis.host');
        const port = config.get('redis.port');
        const password = config.get<string>('redis.password');
        const url = password
          ? `redis://:${password}@${host}:${port}`
          : `redis://${host}:${port}`;
        return { type: 'single', url };
      },
    }),

    // JWT — dùng để verify token client kết nối WS
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: Buffer.from(config.get<string>('jwt.secret') ?? '', 'base64'),
        verifyOptions: {
          issuer: config.get<string>('jwt.issuer'),
          algorithms: ['HS512'] as const,
        },
      }),
    }),

    // Feature modules
    PresenceModule,
    GatewayModule,
    RabbitMQModule,
    KafkaModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
