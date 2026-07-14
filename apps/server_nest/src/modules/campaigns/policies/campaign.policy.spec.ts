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

  describe('canViewActor', () => {
    const actorCtx = {
      campaignId: 'c-1',
      ownerId: 'user-1',
      members: [
        { userId: 'user-1', role: 'owner' },
        { userId: 'user-2', role: 'player' }
      ],
      actorId: 'actor-1',
      actorOwnerUserId: 'user-2',
      actorSourceCharacterId: 'char-1',
      actorRevision: 1
    };

    it('allows a campaign member to view the actor', () => {
      expect(() =>
        policy.canViewActor(
          { userId: 'user-2', username: 'bard' },
          actorCtx
        )
      ).not.toThrow();
    });

    it('rejects a non-member', () => {
      expect(() =>
        policy.canViewActor(
          { userId: 'user-3', username: 'stranger' },
          actorCtx
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canManageActor', () => {
    const actorCtx = {
      campaignId: 'c-1',
      ownerId: 'user-1',
      members: [
        { userId: 'user-1', role: 'owner' },
        { userId: 'user-2', role: 'dm' },
        { userId: 'user-3', role: 'player' }
      ],
      actorId: 'actor-1',
      actorOwnerUserId: 'user-3',
      actorSourceCharacterId: null,
      actorRevision: 1
    };

    it('allows the owner', () => {
      expect(() =>
        policy.canManageActor(
          { userId: 'user-1', username: 'ranger' },
          actorCtx
        )
      ).not.toThrow();
    });

    it('allows a DM', () => {
      expect(() =>
        policy.canManageActor(
          { userId: 'user-2', username: 'bard' },
          actorCtx
        )
      ).not.toThrow();
    });

    it('rejects a player even if they own the actor', () => {
      expect(() =>
        policy.canManageActor(
          { userId: 'user-3', username: 'player' },
          actorCtx
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canEditOwnedActor', () => {
    const baseCtx = {
      campaignId: 'c-1',
      ownerId: 'user-1',
      members: [
        { userId: 'user-1', role: 'owner' },
        { userId: 'user-2', role: 'dm' },
        { userId: 'user-3', role: 'player' }
      ],
      actorId: 'actor-1',
      actorSourceCharacterId: null,
      actorRevision: 1
    };

    it('allows the owner of the campaign (DM path)', () => {
      expect(() =>
        policy.canEditOwnedActor(
          { userId: 'user-1', username: 'ranger' },
          { ...baseCtx, actorOwnerUserId: 'user-3' }
        )
      ).not.toThrow();
    });

    it('allows a DM (manager path)', () => {
      expect(() =>
        policy.canEditOwnedActor(
          { userId: 'user-2', username: 'bard' },
          { ...baseCtx, actorOwnerUserId: 'user-3' }
        )
      ).not.toThrow();
    });

    it('allows the player who owns the actor', () => {
      expect(() =>
        policy.canEditOwnedActor(
          { userId: 'user-3', username: 'player' },
          { ...baseCtx, actorOwnerUserId: 'user-3' }
        )
      ).not.toThrow();
    });

    it('rejects a different player', () => {
      expect(() =>
        policy.canEditOwnedActor(
          { userId: 'user-4', username: 'other' },
          { ...baseCtx, actorOwnerUserId: 'user-3' }
        )
      ).toThrow(ForbiddenException);
    });

    it('rejects a player when the actor has no owner', () => {
      expect(() =>
        policy.canEditOwnedActor(
          { userId: 'user-3', username: 'player' },
          { ...baseCtx, actorOwnerUserId: null }
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canPublishActor', () => {
    const campaignCtx = {
      campaignId: 'c-1',
      ownerId: 'user-1',
      members: [
        { userId: 'user-1', role: 'owner' },
        { userId: 'user-2', role: 'player' }
      ]
    };

    it('allows a campaign member to publish', () => {
      expect(() =>
        policy.canPublishActor(
          { userId: 'user-2', username: 'bard' },
          campaignCtx
        )
      ).not.toThrow();
    });

    it('rejects a non-member', () => {
      expect(() =>
        policy.canPublishActor(
          { userId: 'user-3', username: 'stranger' },
          campaignCtx
        )
      ).toThrow(ForbiddenException);
    });
  });
});
