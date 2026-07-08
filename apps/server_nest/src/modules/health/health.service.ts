import { Injectable } from '@nestjs/common';

@Injectable()
export class HealthService {
  getHealth(): { status: string; service: string; timestamp: string } {
    return {
      status: 'ok',
      service: 'dnd-table-server',
      timestamp: new Date().toISOString()
    };
  }
}
