import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, ExtractJwt } from 'passport-jwt';

/** JWT payload structure matching core-service token format */
export interface JwtPayload {
  sub: string;      // account UUID
  phone: string;
  iat: number;
  exp: number;
  iss: string;
}

/**
 * Validates JWT tokens issued by core-service.
 * Uses the same secret so no inter-service call is needed.
 */
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    const secret = config.get<string>('jwt.secret')!;
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: Buffer.from(secret, 'base64'),
      issuer: config.get<string>('jwt.issuer'),
      algorithms: ['HS512'],
    });
  }

  /** Return value is injected as request.user */
  validate(payload: JwtPayload) {
    return {
      userId: payload.sub,
      phone: payload.phone,
    };
  }
}
