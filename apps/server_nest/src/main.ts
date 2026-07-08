import { NestFactory } from '@nestjs/core';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api', {
    exclude: ['health', '.well-known/dnd-tool-server']
  });
  app.enableCors();
  app.useWebSocketAdapter(new IoAdapter(app));

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
}

void bootstrap();
