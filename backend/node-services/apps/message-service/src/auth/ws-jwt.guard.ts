import { CanActivate, ExecutionContext, Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Socket } from 'socket.io';

/** Extracts and verifies JWT from WebSocket handshake (auth.token or query.token). */
@Injectable()
export class WsJwtGuard implements CanActivate {
  private readonly logger = new Logger(WsJwtGuard.name);

  constructor(private readonly jwtService: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const client: Socket = context.switchToWs().getClient();

    try {
      const token =
        client.handshake?.auth?.token ||
        client.handshake?.query?.token;

      if (!token) {
        this.logger.warn(`WebSocket connection rejected: no token`);
        client.disconnect();
        return false;
      }

      const payload = this.jwtService.verify(token as string);
      // Attach user info to socket data for downstream access
      client.data.user = {
        userId: payload.sub,
        phone: payload.phone,
        loginAtEpochSec: payload.iat,
        clientPlatform: payload.clientPlatform ?? 'WEB',
        trustLevel: payload.trustLevel ?? 'UNKNOWN',
        sessionType: payload.sessionType ?? 'PASSWORD',
        restrictedWebMode: Boolean(payload.restrictedWebMode),
        deviceId: payload.deviceId ?? null,
      };
      return true;
    } catch (err) {
      this.logger.warn(`WebSocket auth failed: ${err.message}`);
      client.disconnect();
      return false;
    }
  }
}
