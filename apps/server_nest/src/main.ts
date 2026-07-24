import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger
} from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { INestApplication } from '@nestjs/core';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { Prisma } from '@prisma/client';
import type { Request, Response } from 'express';
import { AppModule } from './app.module';

/**
 * 全局异常过滤器: 把 Prisma 已知错误映射为 4xx, 避免暴露内部错误结构.
 *
 * - P2002 唯一约束冲突 → 409 Conflict
 * - P2025 记录未找到 → 404 Not Found
 * - 其他 PrismaClientKnownRequestError → 400 Bad Request
 * - 未识别异常 → 500 (只暴露通用消息, 不泄露 stack/token)
 */
@Catch()
class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const resp = exception.getResponse();
      const message =
        typeof resp === 'string'
          ? resp
          : (resp as { message?: unknown }).message ?? exception.message;
      response.status(status).json({
        statusCode: status,
        message,
        timestamp: new Date().toISOString(),
        path: request.url
      });
      return;
    }

    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      const mapped = this.mapPrismaError(exception);
      response.status(mapped.status).json({
        statusCode: mapped.status,
        message: mapped.message,
        code: exception.code,
        timestamp: new Date().toISOString(),
        path: request.url
      });
      return;
    }

    this.logger.error(
      `Unhandled exception: ${exception instanceof Error ? exception.message : String(exception)}`,
      exception instanceof Error ? exception.stack : undefined
    );
    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      message: 'Internal server error',
      timestamp: new Date().toISOString(),
      path: request.url
    });
  }

  private mapPrismaError(
    error: Prisma.PrismaClientKnownRequestError
  ): { status: number; message: string } {
    switch (error.code) {
      case 'P2002':
        return { status: HttpStatus.CONFLICT, message: 'Resource already exists' };
      case 'P2025':
        return { status: HttpStatus.NOT_FOUND, message: 'Resource not found' };
      default:
        return { status: HttpStatus.BAD_REQUEST, message: 'Invalid request' };
    }
  }
}

/**
 * 安全响应头中间件 (helmet 替代, 不引入额外 npm 依赖).
 * 覆盖 OWASP 推荐的基础响应头: nosniff, frame-deny, XSS protection 等.
 */
function registerSecurityHeaders(app: INestApplication): void {
  app.use((req: Request, res: Response, next: () => void) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('Permissions-Policy', 'geolocation=(), microphone=(), camera=()');
    // HSTS 只在 https 下生效, 但提前设置无害.
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
    next();
  });
}

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api', {
    exclude: ['health', '.well-known/dnd-tool-server']
  });

  // CORS: 默认关闭, 通过 CORS_ORIGIN 环境变量显式开启 (逗号分隔白名单).
  // 例: CORS_ORIGIN=https://app.example.com,https://staging.example.com
  const corsOrigin = process.env.CORS_ORIGIN;
  app.enableCors({
    origin: corsOrigin ? corsOrigin.split(',').map((s) => s.trim()) : false,
    credentials: Boolean(corsOrigin)
  });

  registerSecurityHeaders(app);

  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useWebSocketAdapter(new IoAdapter(app));

  // 优雅关闭: SIGTERM 时先断开连接再退出, 让 PrismaService.onModuleDestroy 执行.
  app.enableShutdownHooks();

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  Logger.log(`Server listening on :${port}`, 'Bootstrap');
}

void bootstrap();
