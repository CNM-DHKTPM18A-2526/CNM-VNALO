import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';

/**
 * Standardized Error Envelope to match Java Core Service:
 * {
 *   "success": false,
 *   "code": "ERR_CODE",
 *   "message": "Human readable message",
 *   "data": { optional details }
 * }
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const exceptionResponse =
      exception instanceof HttpException
        ? exception.getResponse()
        : { message: (exception as any)?.message || 'Internal server error' };

    let code = 'INTERNAL_ERROR';
    let message = 'An unexpected error occurred';
    let data = null;

    if (typeof exceptionResponse === 'string') {
      message = exceptionResponse;
    } else if (typeof exceptionResponse === 'object' && exceptionResponse !== null) {
      message = (exceptionResponse as any).message || message;
      code = (exceptionResponse as any).error || this.mapStatusToCode(status);
      data = (exceptionResponse as any).details || null;
      
      // If NestJS ValidationPipe error
      if (Array.isArray((exceptionResponse as any).message)) {
          message = 'Validation failed';
          data = (exceptionResponse as any).message;
          code = 'VALIDATION_ERROR';
      }
    }

    response.status(status).json({
      success: false,
      code,
      message,
      data,
    });
  }

  private mapStatusToCode(status: number): string {
    switch (status) {
      case 400: return 'BAD_REQUEST';
      case 401: return 'UNAUTHORIZED';
      case 403: return 'ACCESS_DENIED';
      case 404: return 'RESOURCE_NOT_FOUND';
      case 405: return 'METHOD_NOT_ALLOWED';
      case 429: return 'TOO_MANY_REQUESTS';
      default: return 'INTERNAL_ERROR';
    }
  }
}
