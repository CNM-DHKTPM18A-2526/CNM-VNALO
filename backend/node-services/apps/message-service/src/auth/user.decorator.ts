import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/** Extracts current user from HTTP request (set by JwtStrategy.validate). */
export const CurrentUser = createParamDecorator(
  (data: string | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user;
    return data ? user?.[data] : user;
  },
);

export interface AuthUser {
  userId: string;
  phone: string;
  loginAtEpochSec?: number;
  clientPlatform?: string;
  trustLevel?: string;
  sessionType?: string;
  restrictedWebMode?: boolean;
  deviceId?: string | null;
}
