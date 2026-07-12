import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../../prisma/prisma.service';
import { TokenService } from '../auth/token.service';

export interface CampaignSocketUser {
  userId: string;
  username: string;
}

export interface JoinCampaignPayload {
  campaignId: string;
}

export interface CampaignAck {
  ok: boolean;
  error?: string;
}

@WebSocketGateway({
  namespace: 'campaigns',
  cors: { origin: '*' }
})
export class CampaignsGateway {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly prismaService: PrismaService,
    private readonly tokenService: TokenService
  ) {}

  handleConnection(client: Socket): void {
    const token = this.extractToken(client);
    if (!token) {
      client.disconnect(true);
      return;
    }

    try {
      const payload = this.tokenService.verifyAccessToken(token);
      (client.data as Record<string, unknown>).user = {
        userId: payload.userId,
        username: payload.username
      };
    } catch {
      client.disconnect(true);
    }
  }

  @SubscribeMessage('campaign:join')
  async handleJoinCampaign(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: JoinCampaignPayload
  ): Promise<CampaignAck> {
    const user = this.getSocketUser(client);
    if (!user) {
      return { ok: false, error: 'unauthorized' };
    }

    const campaignId = payload?.campaignId;
    if (!campaignId) {
      return { ok: false, error: 'missing_campaign_id' };
    }

    const campaign = await this.prismaService.campaign.findUnique({
      where: { id: campaignId },
      include: { members: true }
    });

    if (!campaign) {
      return { ok: false, error: 'campaign_not_found' };
    }

    const isMember = campaign.members.some(
      (member: { userId: string }) => member.userId === user.userId
    );
    if (!isMember) {
      return { ok: false, error: 'not_member' };
    }

    await client.join(`campaign:${campaignId}`);
    return { ok: true };
  }

  @SubscribeMessage('campaign:leave')
  async handleLeaveCampaign(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: JoinCampaignPayload
  ): Promise<CampaignAck> {
    const campaignId = payload?.campaignId;
    if (!campaignId) {
      return { ok: false, error: 'missing_campaign_id' };
    }

    await client.leave(`campaign:${campaignId}`);
    return { ok: true };
  }

  broadcastToCampaign(
    campaignId: string,
    event: string,
    payload: unknown
  ): void {
    this.server.to(`campaign:${campaignId}`).emit(event, payload);
  }

  private extractToken(client: Socket): string | null {
    const auth = (client.handshake.auth ?? {}) as { token?: unknown };
    if (typeof auth.token === 'string' && auth.token.length > 0) {
      return auth.token;
    }
    const query = (client.handshake.query ?? {}) as { token?: unknown };
    if (typeof query.token === 'string' && query.token.length > 0) {
      return query.token;
    }
    return null;
  }

  private getSocketUser(client: Socket): CampaignSocketUser | null {
    const user = (client.data ?? {}) as { user?: CampaignSocketUser };
    return user.user ?? null;
  }
}
