import { UnauthorizedException } from '@nestjs/common';
import { SessionsGateway } from './sessions.gateway';

describe('SessionsGateway', () => {
  let gateway: SessionsGateway;
  let tokenService: { verifyAccessToken: jest.Mock };
  let prismaService: { session: { findUnique: jest.Mock } };
  let fakeServer: any;
  let fakeSocket: any;
  let toRoomEmit: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();

    tokenService = { verifyAccessToken: jest.fn() };
    prismaService = { session: { findUnique: jest.fn() } };

    toRoomEmit = jest.fn();
    fakeServer = {
      to: jest.fn(() => ({ emit: toRoomEmit })),
      emit: jest.fn(),
      socketsJoin: jest.fn(),
      socketsLeave: jest.fn(),
      on: jest.fn(),
      use: jest.fn(),
      close: jest.fn()
    };

    fakeSocket = {
      data: {} as any,
      handshake: { auth: {} as any, query: {} as any, headers: {} },
      join: jest.fn(),
      leave: jest.fn(),
      disconnect: jest.fn(),
      emit: jest.fn()
    };

    gateway = new SessionsGateway(
      prismaService as any,
      tokenService as any
    );
    (gateway as any).server = fakeServer;
  });

  describe('handleConnection', () => {
    it('stores user on socket when JWT in handshake.auth.token is valid', () => {
      tokenService.verifyAccessToken.mockReturnValue({
        userId: 'user-1',
        username: 'ranger'
      });
      fakeSocket.handshake.auth.token = 'valid-token';

      gateway.handleConnection(fakeSocket);

      expect(tokenService.verifyAccessToken).toHaveBeenCalledWith('valid-token');
      expect(fakeSocket.data.user).toEqual({
        userId: 'user-1',
        username: 'ranger'
      });
      expect(fakeSocket.disconnect).not.toHaveBeenCalled();
    });

    it('reads JWT from query.token when auth.token is absent', () => {
      tokenService.verifyAccessToken.mockReturnValue({
        userId: 'user-1',
        username: 'ranger'
      });
      fakeSocket.handshake.query.token = 'query-token';

      gateway.handleConnection(fakeSocket);

      expect(tokenService.verifyAccessToken).toHaveBeenCalledWith('query-token');
      expect(fakeSocket.data.user).toEqual({
        userId: 'user-1',
        username: 'ranger'
      });
    });

    it('prefers auth.token over query.token', () => {
      tokenService.verifyAccessToken.mockReturnValue({
        userId: 'user-1',
        username: 'ranger'
      });
      fakeSocket.handshake.auth.token = 'auth-token';
      fakeSocket.handshake.query.token = 'query-token';

      gateway.handleConnection(fakeSocket);

      expect(tokenService.verifyAccessToken).toHaveBeenCalledWith('auth-token');
    });

    it('disconnects the client when no token is provided', () => {
      gateway.handleConnection(fakeSocket);

      expect(tokenService.verifyAccessToken).not.toHaveBeenCalled();
      expect(fakeSocket.disconnect).toHaveBeenCalledWith(true);
      expect(fakeSocket.data.user).toBeUndefined();
    });

    it('disconnects the client when JWT verification throws', () => {
      tokenService.verifyAccessToken.mockImplementation(() => {
        throw new UnauthorizedException('Invalid access token');
      });
      fakeSocket.handshake.auth.token = 'bad-token';

      gateway.handleConnection(fakeSocket);

      expect(fakeSocket.disconnect).toHaveBeenCalledWith(true);
      expect(fakeSocket.data.user).toBeUndefined();
    });
  });

  describe('handleJoinSession', () => {
    it('adds socket to session room when user is a campaign member', async () => {
      fakeSocket.data.user = { userId: 'user-1', username: 'ranger' };
      prismaService.session.findUnique.mockResolvedValue({
        id: 's-1',
        campaign: {
          ownerId: 'user-2',
          members: [{ userId: 'user-1', role: 'player' }]
        }
      });

      const ack = await gateway.handleJoinSession(fakeSocket, {
        sessionId: 's-1'
      });

      expect(prismaService.session.findUnique).toHaveBeenCalledWith({
        where: { id: 's-1' },
        include: { campaign: { include: { members: true } } }
      });
      expect(fakeSocket.join).toHaveBeenCalledWith('session:s-1');
      expect(fakeSocket.join).not.toHaveBeenCalledWith('session:s-1:managers');
      expect(ack).toEqual({ ok: true });
    });

    it('also joins managers room when the user is the DM', async () => {
      fakeSocket.data.user = { userId: 'user-2', username: 'bard' };
      prismaService.session.findUnique.mockResolvedValue({
        id: 's-1',
        campaign: {
          ownerId: 'user-1',
          members: [{ userId: 'user-2', role: 'dm' }]
        }
      });

      const ack = await gateway.handleJoinSession(fakeSocket, {
        sessionId: 's-1'
      });

      expect(fakeSocket.join).toHaveBeenCalledWith('session:s-1');
      expect(fakeSocket.join).toHaveBeenCalledWith('session:s-1:managers');
      expect(ack).toEqual({ ok: true });
    });

    it('also joins managers room when the user is the campaign owner', async () => {
      fakeSocket.data.user = { userId: 'user-1', username: 'ranger' };
      prismaService.session.findUnique.mockResolvedValue({
        id: 's-1',
        campaign: {
          ownerId: 'user-1',
          members: [{ userId: 'user-1', role: 'owner' }]
        }
      });

      await gateway.handleJoinSession(fakeSocket, { sessionId: 's-1' });

      expect(fakeSocket.join).toHaveBeenCalledWith('session:s-1:managers');
    });

    it('rejects when the user is not a campaign member', async () => {
      fakeSocket.data.user = { userId: 'user-1', username: 'ranger' };
      prismaService.session.findUnique.mockResolvedValue({
        id: 's-1',
        campaign: { ownerId: 'user-2', members: [] }
      });

      const ack = await gateway.handleJoinSession(fakeSocket, {
        sessionId: 's-1'
      });

      expect(fakeSocket.join).not.toHaveBeenCalled();
      expect(ack).toEqual({ ok: false, error: 'not_member' });
    });

    it('rejects when the session does not exist', async () => {
      fakeSocket.data.user = { userId: 'user-1', username: 'ranger' };
      prismaService.session.findUnique.mockResolvedValue(null);

      const ack = await gateway.handleJoinSession(fakeSocket, {
        sessionId: 'nope'
      });

      expect(fakeSocket.join).not.toHaveBeenCalled();
      expect(ack).toEqual({ ok: false, error: 'session_not_found' });
    });

    it('rejects when the socket has no authenticated user', async () => {
      const ack = await gateway.handleJoinSession(fakeSocket, {
        sessionId: 's-1'
      });

      expect(prismaService.session.findUnique).not.toHaveBeenCalled();
      expect(fakeSocket.join).not.toHaveBeenCalled();
      expect(ack).toEqual({ ok: false, error: 'unauthorized' });
    });
  });

  describe('handleLeaveSession', () => {
    it('leaves both session and managers rooms', async () => {
      const ack = await gateway.handleLeaveSession(fakeSocket, {
        sessionId: 's-1'
      });

      expect(fakeSocket.leave).toHaveBeenCalledWith('session:s-1');
      expect(fakeSocket.leave).toHaveBeenCalledWith('session:s-1:managers');
      expect(ack).toEqual({ ok: true });
    });
  });

  describe('broadcastToSession', () => {
    it('emits the event to the session room', () => {
      gateway.broadcastToSession('s-1', 'message:new', { id: 'm-1' });

      expect(fakeServer.to).toHaveBeenCalledWith('session:s-1');
      expect(toRoomEmit).toHaveBeenCalledWith('message:new', { id: 'm-1' });
    });
  });

  describe('broadcastToSessionManagers', () => {
    it('emits the event to the managers room only', () => {
      gateway.broadcastToSessionManagers('s-1', 'roll:secret', { id: 'r-1' });

      expect(fakeServer.to).toHaveBeenCalledWith('session:s-1:managers');
      expect(toRoomEmit).toHaveBeenCalledWith('roll:secret', { id: 'r-1' });
    });
  });
});
