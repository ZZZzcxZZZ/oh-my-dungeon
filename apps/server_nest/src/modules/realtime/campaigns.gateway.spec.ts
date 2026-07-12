import { UnauthorizedException } from '@nestjs/common';
import { CampaignsGateway } from './campaigns.gateway';

describe('CampaignsGateway', () => {
  let gateway: CampaignsGateway;
  let tokenService: { verifyAccessToken: jest.Mock };
  let prismaService: { campaign: { findUnique: jest.Mock } };
  let fakeServer: any;
  let fakeSocket: any;
  let toRoomEmit: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();

    tokenService = { verifyAccessToken: jest.fn() };
    prismaService = { campaign: { findUnique: jest.fn() } };

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

    gateway = new CampaignsGateway(
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

  describe('handleJoinCampaign', () => {
    it('adds socket to campaign room when user is a campaign member', async () => {
      fakeSocket.data.user = { userId: 'user-1', username: 'ranger' };
      prismaService.campaign.findUnique.mockResolvedValue({
        id: 'camp-1',
        ownerId: 'user-2',
        members: [{ userId: 'user-1', role: 'player' }]
      });

      const ack = await gateway.handleJoinCampaign(fakeSocket, {
        campaignId: 'camp-1'
      });

      expect(prismaService.campaign.findUnique).toHaveBeenCalledWith({
        where: { id: 'camp-1' },
        include: { members: true }
      });
      expect(fakeSocket.join).toHaveBeenCalledWith('campaign:camp-1');
      expect(ack).toEqual({ ok: true });
    });

    it('rejects when the user is not a campaign member', async () => {
      fakeSocket.data.user = { userId: 'user-1', username: 'ranger' };
      prismaService.campaign.findUnique.mockResolvedValue({
        id: 'camp-1',
        ownerId: 'user-2',
        members: [{ userId: 'user-2', role: 'owner' }]
      });

      const ack = await gateway.handleJoinCampaign(fakeSocket, {
        campaignId: 'camp-1'
      });

      expect(fakeSocket.join).not.toHaveBeenCalled();
      expect(ack).toEqual({ ok: false, error: 'not_member' });
    });

    it('rejects when the campaign does not exist', async () => {
      fakeSocket.data.user = { userId: 'user-1', username: 'ranger' };
      prismaService.campaign.findUnique.mockResolvedValue(null);

      const ack = await gateway.handleJoinCampaign(fakeSocket, {
        campaignId: 'missing'
      });

      expect(fakeSocket.join).not.toHaveBeenCalled();
      expect(ack).toEqual({ ok: false, error: 'campaign_not_found' });
    });

    it('rejects when the socket has no authenticated user', async () => {
      const ack = await gateway.handleJoinCampaign(fakeSocket, {
        campaignId: 'camp-1'
      });

      expect(prismaService.campaign.findUnique).not.toHaveBeenCalled();
      expect(fakeSocket.join).not.toHaveBeenCalled();
      expect(ack).toEqual({ ok: false, error: 'unauthorized' });
    });
  });

  describe('handleLeaveCampaign', () => {
    it('leaves the campaign room', async () => {
      const ack = await gateway.handleLeaveCampaign(fakeSocket, {
        campaignId: 'camp-1'
      });

      expect(fakeSocket.leave).toHaveBeenCalledWith('campaign:camp-1');
      expect(ack).toEqual({ ok: true });
    });
  });

  describe('broadcastToCampaign', () => {
    it('emits the event to the campaign room', () => {
      gateway.broadcastToCampaign('camp-1', 'campaign:message:new', {
        id: 'msg-1'
      });

      expect(fakeServer.to).toHaveBeenCalledWith('campaign:camp-1');
      expect(toRoomEmit).toHaveBeenCalledWith('campaign:message:new', {
        id: 'msg-1'
      });
    });
  });
});
