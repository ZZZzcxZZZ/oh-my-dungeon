import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { CampaignPolicy } from './campaign.policy';

describe('CampaignPolicy', () => {
  let policy: CampaignPolicy;

  beforeEach(() => {
    policy = new CampaignPolicy();
  });

  describe('canCreateCampaign', () => {
    it('allows any authenticated user to create a campaign', () => {
      expect(() =>
        policy.canCreateCampaign({ userId: 'user-1', username: 'ranger' })
      ).not.toThrow();
    });

    it('rejects when userId is missing', () => {
      expect(() =>
        policy.canCreateCampaign({ userId: '', username: 'ranger' })
      ).toThrow(ForbiddenException);
    });
  });

  describe('canViewCampaign', () => {
    it('allows owner to view', () => {
      expect(() =>
        policy.canViewCampaign(
          { userId: 'user-1', username: 'ranger' },
          {
            campaignId: 'c-1',
            ownerId: 'user-1',
            members: [
              { userId: 'user-1', role: 'owner' }
            ]
          }
        )
      ).not.toThrow();
    });

    it('allows member to view', () => {
      expect(() =>
        policy.canViewCampaign(
          { userId: 'user-2', username: 'bard' },
          {
            campaignId: 'c-1',
            ownerId: 'user-1',
            members: [
              { userId: 'user-1', role: 'owner' },
              { userId: 'user-2', role: 'player' }
            ]
          }
        )
      ).not.toThrow();
    });

    it('rejects non-member', () => {
      expect(() =>
        policy.canViewCampaign(
          { userId: 'user-3', username: 'stranger' },
          {
            campaignId: 'c-1',
            ownerId: 'user-1',
            members: [
              { userId: 'user-1', role: 'owner' }
            ]
          }
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canManageCampaign', () => {
    it('allows owner to manage', () => {
      expect(() =>
        policy.canManageCampaign(
          { userId: 'user-1', username: 'ranger' },
          {
            campaignId: 'c-1',
            ownerId: 'user-1',
            members: [
              { userId: 'user-1', role: 'owner' }
            ]
          }
        )
      ).not.toThrow();
    });

    it('allows dm to manage', () => {
      expect(() =>
        policy.canManageCampaign(
          { userId: 'user-2', username: 'bard' },
          {
            campaignId: 'c-1',
            ownerId: 'user-1',
            members: [
              { userId: 'user-1', role: 'owner' },
              { userId: 'user-2', role: 'dm' }
            ]
          }
        )
      ).not.toThrow();
    });

    it('rejects player', () => {
      expect(() =>
        policy.canManageCampaign(
          { userId: 'user-2', username: 'bard' },
          {
            campaignId: 'c-1',
            ownerId: 'user-1',
            members: [
              { userId: 'user-1', role: 'owner' },
              { userId: 'user-2', role: 'player' }
            ]
          }
        )
      ).toThrow(ForbiddenException);
    });

    it('rejects spectator', () => {
      expect(() =>
        policy.canManageCampaign(
          { userId: 'user-2', username: 'bard' },
          {
            campaignId: 'c-1',
            ownerId: 'user-1',
            members: [
              { userId: 'user-1', role: 'owner' },
              { userId: 'user-2', role: 'spectator' }
            ]
          }
        )
      ).toThrow(ForbiddenException);
    });

    it('rejects non-member', () => {
      expect(() =>
        policy.canManageCampaign(
          { userId: 'user-3', username: 'stranger' },
          {
            campaignId: 'c-1',
            ownerId: 'user-1',
            members: [
              { userId: 'user-1', role: 'owner' }
            ]
          }
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canJoinCampaign', () => {
    it('allows a valid, non-expired invite with remaining uses', () => {
      expect(() =>
        policy.canJoinCampaign({
          invite: {
            id: 'inv-1',
            campaignId: 'c-1',
            code: 'ABC123',
            roleOnJoin: 'player',
            expiresAt: null,
            maxUses: 5,
            usedCount: 2,
            requireApproval: false
          },
          existingMembership: null
        })
      ).not.toThrow();
    });

    it('throws NotFound when invite is null', () => {
      expect(() =>
        policy.canJoinCampaign({
          invite: null,
          existingMembership: null
        })
      ).toThrow(NotFoundException);
    });

    it('throws Forbidden when invite is expired', () => {
      expect(() =>
        policy.canJoinCampaign({
          invite: {
            id: 'inv-1',
            campaignId: 'c-1',
            code: 'ABC123',
            roleOnJoin: 'player',
            expiresAt: new Date('2020-01-01T00:00:00Z'),
            maxUses: 5,
            usedCount: 0,
            requireApproval: false
          },
          existingMembership: null
        })
      ).toThrow(ForbiddenException);
    });

    it('throws Forbidden when invite maxUses is exhausted', () => {
      expect(() =>
        policy.canJoinCampaign({
          invite: {
            id: 'inv-1',
            campaignId: 'c-1',
            code: 'ABC123',
            roleOnJoin: 'player',
            expiresAt: null,
            maxUses: 1,
            usedCount: 1,
            requireApproval: false
          },
          existingMembership: null
        })
      ).toThrow(ForbiddenException);
    });
  });
});
