import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { CharactersController } from './characters.controller';
import { CharactersService } from './characters.service';
import { CharacterStateStore } from './character-state.store';
import { GameEventsModule } from '../game-events/game-events.module';
import { CharacterOperationsService } from './character-operations.service';

@Module({
  imports: [PrismaModule, AuthModule, GameEventsModule],
  controllers: [CharactersController],
  providers: [CharactersService, CharacterStateStore, CharacterOperationsService]
})
export class CharactersModule {}
