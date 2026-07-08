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

const MANAGER_ROLES = new Set(['owner', 'dm']);

export interface SessionSocketUser {
  userId: string;
  username: string;
}

export interface JoinSessionPayload {
  sessionId: string;
}

export interface SessionAck {
  ok: boolean;
  error?: string;
}

@WebSocketGateway({
  namespace: 'sessions',
  cors: { origin: '*' }
})
export class SessionsGateway {
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

  @SubscribeMessage('session:join')
  async handleJoinSession(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: JoinSessionPayload
  ): Promise<SessionAck> {
    const user = this.getSocketUser(client);
    if (!user) {
      return { ok: false, error: 'unauthorized' };
    }

    const sessionId = payload?.sessionId;
    if (!sessionId) {
      return { ok: false, error: 'missing_session_id' };
    }

    const session = await this.prismaService.session.findUnique({
      where: { id: sessionId },
      include: { campaign: { include: { members: true } } }
    });

    if (!session) {
      return { ok: false, error: 'session_not_found' };
    }

    const membership = session.campaign.members.find(
      (member: { userId: string; role: string }) =>
        member.userId === user.userId
    );

    if (!membership) {
      return { ok: false, error: 'not_member' };
    }

    await client.join(`session:${sessionId}`);
    if (
      MANAGER_ROLES.has(membership.role) ||
      session.campaign.ownerId === user.userId
    ) {
      await client.join(`session:${sessionId}:managers`);
    }

    return { ok: true };
  }

  @SubscribeMessage('session:leave')
  async handleLeaveSession(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: JoinSessionPayload
  ): Promise<SessionAck> {
    const sessionId = payload?.sessionId;
    if (!sessionId) {
      return { ok: false, error: 'missing_session_id' };
    }

    await client.leave(`session:${sessionId}`);
    await client.leave(`session:${sessionId}:managers`);
    return { ok: true };
  }

  broadcastToSession(
    sessionId: string,
    event: string,
    payload: unknown
  ): void {
    this.server.to(`session:${sessionId}`).emit(event, payload);
  }

  broadcastToSessionManagers(
    sessionId: string,
    event: string,
    payload: unknown
  ): void {
    this.server.to(`session:${sessionId}:managers`).emit(event, payload);
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

  private getSocketUser(client: Socket): SessionSocketUser | null {
    const user = (client.data ?? {}) as { user?: SessionSocketUser };
    return user.user ?? null;
  }
}
