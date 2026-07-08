import { Controller, Get } from '@nestjs/common';
import { HealthReport, HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  getHealth(): Promise<HealthReport> {
    return this.healthService.getHealth();
  }
}
