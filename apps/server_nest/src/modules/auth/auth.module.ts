import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { PasswordHashService } from './password-hash.service';
import { TokenService } from './token.service';

@Module({
  imports: [PrismaModule],
  controllers: [AuthController],
  providers: [AuthService, PasswordHashService, TokenService, JwtAuthGuard],
  exports: [AuthService, PasswordHashService, TokenService, JwtAuthGuard]
})
export class AuthModule {}
