import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface Response<T> {
  data: T;
}

@Injectable()
export class TransformInterceptor<T>
  implements NestInterceptor<T, Response<T>>
{
  intercept(
    context: ExecutionContext,
    next: CallHandler,
  ): Observable<Response<T>> {
    return next.handle().pipe(
      map((data) => {
        // If data already has a 'data' property, or it's a health check/special case, return as is
        // But for consistency, we wrap everything.
        if (data && typeof data === 'object' && 'data' in data && Object.keys(data).length === 1) {
            return data;
        }
        return { data };
      }),
    );
  }
}
