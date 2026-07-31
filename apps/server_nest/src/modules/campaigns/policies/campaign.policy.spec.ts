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

  describe('capabilitiesFor', () => {
    const campaign = {
      campaignId: 'c-1',
      ownerId: 'user-1',
      members: [
        { userId: 'user-1', role: 'owner' },
        { userId: 'user-2', role: 'player' }
      ]
    };

    it('grants every campaign management capability to the owner', () => {
      expect(
        policy.capabilitiesFor(
          { userId: 'user-1', username: 'ranger' },
          campaign
        )
      ).toEqual({
        canManageCampaign: true,
        canManageMembers: true,
        canInviteMembers: true,
        canCreateCharacters: true,
        canManageCharacters: true,
        canEditAnyCharacter: true,
        canSpeakAsNarrator: true,
        canCreateArchive: true,
        canManageArchive: true
      });
    });

    it('denies campaign management capabilities to a player', () => {
      expect(
        policy.capabilitiesFor(
          { userId: 'user-2', username: 'bard' },
          campaign
        )
      ).toEqual({
        canManageCampaign: false,
        canManageMembers: false,
        canInviteMembers: false,
        canCreateCharacters: false,
        canManageCharacters: false,
        canEditAnyCharacter: false,
        canSpeakAsNarrator: false,
        canCreateArchive: false,
        canManageArchive: false
      });
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

  describe('canViewCharacter', () => {
    const characterCtx = {
      campaignId: 'c-1',
      ownerId: 'user-1',
      members: [
        { userId: 'user-1', role: 'owner' },
        { userId: 'user-2', role: 'player' }
      ],
      characterId: 'character-1',
      characterOwnerUserId: 'user-2',
      characterSourceCharacterId: 'char-1',
      characterRevision: 1
    };

    it('allows a campaign member to view the character', () => {
      expect(() =>
        policy.canViewCharacter(
          { userId: 'user-2', username: 'bard' },
          characterCtx
        )
      ).not.toThrow();
    });

    it('rejects a non-member', () => {
      expect(() =>
        policy.canViewCharacter(
          { userId: 'user-3', username: 'stranger' },
          characterCtx
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canManageCharacter', () => {
    const characterCtx = {
      campaignId: 'c-1',
      ownerId: 'user-1',
      members: [
        { userId: 'user-1', role: 'owner' },
        { userId: 'user-2', role: 'dm' },
        { userId: 'user-3', role: 'player' }
      ],
      characterId: 'character-1',
      characterOwnerUserId: 'user-3',
      characterSourceCharacterId: null,
      characterRevision: 1
    };

    it('allows the owner', () => {
      expect(() =>
        policy.canManageCharacter(
          { userId: 'user-1', username: 'ranger' },
          characterCtx
        )
      ).not.toThrow();
    });

    it('allows a DM', () => {
      expect(() =>
        policy.canManageCharacter(
          { userId: 'user-2', username: 'bard' },
          characterCtx
        )
      ).not.toThrow();
    });

    it('rejects a player even if they own the character', () => {
      expect(() =>
        policy.canManageCharacter(
          { userId: 'user-3', username: 'player' },
          characterCtx
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canEditOwnedCharacter', () => {
    const baseCtx = {
      campaignId: 'c-1',
      ownerId: 'user-1',
      members: [
        { userId: 'user-1', role: 'owner' },
        { userId: 'user-2', role: 'dm' },
        { userId: 'user-3', role: 'player' }
      ],
      characterId: 'character-1',
      characterSourceCharacterId: null,
      characterRevision: 1
    };

    it('allows the owner of the campaign (DM path)', () => {
      expect(() =>
        policy.canEditOwnedCharacter(
          { userId: 'user-1', username: 'ranger' },
          { ...baseCtx, characterOwnerUserId: 'user-3' }
        )
      ).not.toThrow();
    });

    it('allows a DM (manager path)', () => {
      expect(() =>
        policy.canEditOwnedCharacter(
          { userId: 'user-2', username: 'bard' },
          { ...baseCtx, characterOwnerUserId: 'user-3' }
        )
      ).not.toThrow();
    });

    it('allows the player who owns the character', () => {
      expect(() =>
        policy.canEditOwnedCharacter(
          { userId: 'user-3', username: 'player' },
          { ...baseCtx, characterOwnerUserId: 'user-3' }
        )
      ).not.toThrow();
    });

    it('rejects a different player', () => {
      expect(() =>
        policy.canEditOwnedCharacter(
          { userId: 'user-4', username: 'other' },
          { ...baseCtx, characterOwnerUserId: 'user-3' }
        )
      ).toThrow(ForbiddenException);
    });

    it('rejects a player when the character has no owner', () => {
      expect(() =>
        policy.canEditOwnedCharacter(
          { userId: 'user-3', username: 'player' },
          { ...baseCtx, characterOwnerUserId: null }
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canPublishCharacter', () => {
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
        policy.canPublishCharacter(
          { userId: 'user-2', username: 'bard' },
          campaignCtx
        )
      ).not.toThrow();
    });

    it('rejects a non-member', () => {
      expect(() =>
        policy.canPublishCharacter(
          { userId: 'user-3', username: 'stranger' },
          campaignCtx
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('campaign workspace identities', () => {
    const campaignCtx = {
      campaignId: 'c-1',
      ownerId: 'user-1',
      members: [
        { userId: 'user-1', role: 'owner' },
        { userId: 'user-2', role: 'player' }
      ]
    };

    it('allows a player to bind only their own active player character', () => {
      expect(() =>
        policy.canBindCharacter(
          { userId: 'user-2', username: 'bard' },
          campaignCtx,
          'user-2',
          {
            ownerUserId: 'user-2',
            characterType: 'player',
            status: 'active'
          }
        )
      ).not.toThrow();
    });

    it('rejects a player binding another member character', () => {
      expect(() =>
        policy.canBindCharacter(
          { userId: 'user-2', username: 'bard' },
          campaignCtx,
          'user-2',
          {
            ownerUserId: 'user-1',
            characterType: 'player',
            status: 'active'
          }
        )
      ).toThrow(ForbiddenException);
    });

    it('allows a DM to speak as an active temporary NPC', () => {
      expect(() =>
        policy.canSpeakAsCharacter(
          { userId: 'user-1', username: 'dm' },
          campaignCtx,
          { ownerUserId: null, characterType: 'npc', status: 'active' }
        )
      ).not.toThrow();
    });

    it('rejects speaking through an archived character', () => {
      expect(() =>
        policy.canSpeakAsCharacter(
          { userId: 'user-1', username: 'dm' },
          campaignCtx,
          { ownerUserId: null, characterType: 'npc', status: 'archived' }
        )
      ).toThrow(ForbiddenException);
    });
  });
});
