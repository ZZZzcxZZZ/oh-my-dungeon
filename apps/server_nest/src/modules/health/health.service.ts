import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface HealthReport {
  status: 'ok' | 'degraded';
  service: string;
  timestamp: string;
  database: {
    status: 'ok' | 'down';
  };
}

@Injectable()
export class HealthService {
  constructor(private readonly prismaService: PrismaService) {}

  async getHealth(): Promise<HealthReport> {
    const database = await this.checkDatabase();

    return {
      status: database.status === 'ok' ? 'ok' : 'degraded',
      service: 'dnd-table-server',
      timestamp: new Date().toISOString(),
      database
    };
  }

  private async checkDatabase(): Promise<HealthReport['database']> {
    try {
      await this.prismaService.$queryRaw`SELECT 1 AS health_check`;
      return { status: 'ok' };
    } catch {
      return { status: 'down' };
    }
  }
}
