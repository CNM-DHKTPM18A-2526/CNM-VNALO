import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { databaseConfig, redisConfig, jwtConfig } from './config/app.config';
import { AuthModule } from './auth/auth.module';
import { ConversationModule } from './conversation/conversation.module';
import { MessageModule } from './message/message.module';
import { InboxModule } from './inbox/inbox.module';
import { GatewayModule } from './gateway/gateway.module';
import { HealthController } from './health.controller';

@Module({
  imports: [
    // Load .env
    ConfigModule.forRoot({
      isGlobal: true,
      load: [databaseConfig, redisConfig, jwtConfig],
      envFilePath: ['.env'],
    }),

    // PostgreSQL via TypeORM
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get('database.host'),
        port: config.get('database.port'),
        username: config.get('database.user'),
        password: config.get('database.password'),
        database: config.get('database.database'),
        autoLoadEntities: true,
        synchronize: config.get('NODE_ENV') === 'development', // Auto-sync in dev only
        schema: 'public',
        logging: config.get('NODE_ENV') === 'development' ? ['error'] : false,
      }),
    }),

    // JWT (shared secret with core-service)
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get('jwt.secret'),
        verifyOptions: {
          issuer: config.get('jwt.issuer'),
        },
      }),
    }),

    // Feature modules
    AuthModule,
    ConversationModule,
    MessageModule,
    InboxModule,
    GatewayModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
