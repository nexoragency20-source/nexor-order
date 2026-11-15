import 'dotenv/config';
import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module.js';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { rawBody: true });

  app.setGlobalPrefix('api/v1');

  // A single "*" must be passed to the CORS middleware as a string.
  // Splitting it into ["*"] makes it a literal allowed origin and browsers
  // receive no Access-Control-Allow-Origin header for localhost origins.
  const configuredCorsOrigins = (process.env.CORS_ORIGIN ?? '*')
    .split(',')
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  const corsOrigin = configuredCorsOrigins.includes('*')
    ? '*'
    : configuredCorsOrigins;

  app.enableCors({
    origin: corsOrigin,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'x-nexor-session'],
  });

  app.use(helmet());
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port, '0.0.0.0');
console.log(`NEXOR Orders API is running on http://localhost:${port}/api/v1`);
}

void bootstrap();
