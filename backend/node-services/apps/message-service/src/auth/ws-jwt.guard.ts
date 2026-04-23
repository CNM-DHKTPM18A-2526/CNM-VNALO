import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
} from '@nestjs/common';
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
        client.handshake?.auth?.token || client.handshake?.query?.token;

      if (!token) {
        this.logger.warn(
          `[WsJwtGuard] Connection rejected: no token found in auth or query`,
        );
        client.disconnect();
        return false;
      }

      this.logger.debug(
        `[WsJwtGuard] Token received, length: ${(token as string).length}`,
      );
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
      this.logger.log(
        `[WsJwtGuard] Auth success, user: ${payload.sub}, restrictedWebMode: ${payload.restrictedWebMode}`,
      );
      return true;
    } catch (err) {
      this.logger.warn(`[WsJwtGuard] Auth failed: ${err.message}`);
      client.disconnect();
      return false;
    }
  }
}
