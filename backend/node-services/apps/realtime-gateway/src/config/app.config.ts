import { registerAs } from '@nestjs/config';

export const redisConfig = registerAs('redis', () => ({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379', 10),
  password: process.env.REDIS_PASSWORD || '',
}));

export const jwtConfig = registerAs('jwt', () => ({
  secret: process.env.JWT_SECRET || '',
  issuer: process.env.JWT_ISSUER || 'vnalo',
}));

export const rabbitConfig = registerAs('rabbit', () => ({
  url: process.env.RABBITMQ_URL || 'amqp://guest:guest@localhost:5672',
  broadcastQueue: 'realtime.broadcast',
  exchange: 'vnalo.realtime',
}));

export const kafkaConfig = registerAs('kafka', () => ({
  brokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
  clientId: process.env.KAFKA_CLIENT_ID || 'vnalo-realtime-gateway',
  realtimeTopic: process.env.KAFKA_REALTIME_TOPIC || 'vnalo.realtime.events',
}));
