import {
  ConflictException,
  ForbiddenException,
  Injectable
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { PasswordHashService } from './password-hash.service';
import type { RegisterInput, RegisterResult, RegisteredUser } from './auth.types';

@Injectable()
export class AuthService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly passwordHashService: PasswordHashService
  ) {}

  async register(input: RegisterInput): Promise<RegisterResult> {
    const settings = await this.prismaService.serverSetting.findFirst();
    if (settings?.registrationEnabled === false) {
      throw new ForbiddenException('Registration is disabled');
    }

    const existingByUsername = await this.prismaService.user.findFirst({
      where: { username: input.username }
    });
    if (existingByUsername) {
      throw new ConflictException('Username already exists');
    }

    const existingByEmail = await this.prismaService.user.findFirst({
      where: { email: input.email }
    });
    if (existingByEmail) {
      throw new ConflictException('Email already exists');
    }

    const passwordHash = await this.passwordHashService.hash(input.password);
    const userCount = await this.prismaService.user.count();
    const isFirstUser = userCount === 0;

    const createdUser = await this.prismaService.$transaction(
      async (tx) => {
        const user = await tx.user.create({
          data: {
            username: input.username,
            email: input.email,
            passwordHash
          }
        });

        if (isFirstUser) {
          await tx.serverAdmin.create({
            data: { userId: user.id, role: 'owner' }
          });
        }

        return user;
      }
    );

    return {
      user: toRegisteredUser(createdUser),
      isFirstUser
    };
  }
}

function toRegisteredUser(user: {
  id: string;
  username: string;
  email: string;
}): RegisteredUser {
  return {
    id: user.id,
    username: user.username,
    email: user.email
  };
}
