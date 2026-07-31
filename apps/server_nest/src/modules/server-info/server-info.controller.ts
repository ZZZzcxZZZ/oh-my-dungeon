import { Controller, Get } from '@nestjs/common';
import { ServerInfoService } from './server-info.service';
import type { ServerMetadata } from './server-metadata.type';

@Controller('.well-known/dnd-tool-server')
export class ServerInfoController {
  constructor(private readonly serverInfoService: ServerInfoService) {}

  @Get()
  getMetadata(): Promise<ServerMetadata> {
    return this.serverInfoService.getMetadata();
  }
}
