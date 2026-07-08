import { ForbiddenException } from '@nestjs/common';
import { SessionPolicy } from './session.policy';
import type { CampaignContext } from '../../campaigns/policies/campaign.policy';

const actor = (userId: string, username = 'hero') => ({
  userId,
  username
});

const ctx = (ownerId: string, members: Array<{ userId: string; role: string }>): CampaignContext => ({
  campaignId: 'c-1',
  ownerId,
  members
});

describe('SessionPolicy', () => {
  let policy: SessionPolicy;

  beforeEach(() => {
    policy = new SessionPolicy();
  });

  describe('canCreateSession', () => {
    it('allows owner to create a session', () => {
      expect(() =>
        policy.canCreateSession(
          actor('user-1'),
          ctx('user-1', [{ userId: 'user-1', role: 'owner' }])
        )
      ).not.toThrow();
    });

    it('allows dm to create a session', () => {
      expect(() =>
        policy.canCreateSession(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'dm' }
          ])
        )
      ).not.toThrow();
    });

    it('rejects player', () => {
      expect(() =>
        policy.canCreateSession(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'player' }
          ])
        )
      ).toThrow(ForbiddenException);
    });

    it('rejects non-member', () => {
      expect(() =>
        policy.canCreateSession(
          actor('user-3'),
          ctx('user-1', [{ userId: 'user-1', role: 'owner' }])
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canStartSession', () => {
    it('allows owner to start a session', () => {
      expect(() =>
        policy.canStartSession(
          actor('user-1'),
          ctx('user-1', [{ userId: 'user-1', role: 'owner' }])
        )
      ).not.toThrow();
    });

    it('allows dm to start a session', () => {
      expect(() =>
        policy.canStartSession(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'dm' }
          ])
        )
      ).not.toThrow();
    });

    it('rejects player', () => {
      expect(() =>
        policy.canStartSession(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'player' }
          ])
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canEndSession', () => {
    it('allows owner to end a session', () => {
      expect(() =>
        policy.canEndSession(
          actor('user-1'),
          ctx('user-1', [{ userId: 'user-1', role: 'owner' }])
        )
      ).not.toThrow();
    });

    it('allows dm to end a session', () => {
      expect(() =>
        policy.canEndSession(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'dm' }
          ])
        )
      ).not.toThrow();
    });

    it('rejects player', () => {
      expect(() =>
        policy.canEndSession(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'player' }
          ])
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canViewSession', () => {
    it('allows owner to view', () => {
      expect(() =>
        policy.canViewSession(
          actor('user-1'),
          ctx('user-1', [{ userId: 'user-1', role: 'owner' }])
        )
      ).not.toThrow();
    });

    it('allows player to view', () => {
      expect(() =>
        policy.canViewSession(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'player' }
          ])
        )
      ).not.toThrow();
    });

    it('allows spectator to view', () => {
      expect(() =>
        policy.canViewSession(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'spectator' }
          ])
        )
      ).not.toThrow();
    });

    it('rejects non-member', () => {
      expect(() =>
        policy.canViewSession(
          actor('user-3'),
          ctx('user-1', [{ userId: 'user-1', role: 'owner' }])
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canSendDMMessage', () => {
    it('allows owner to send dm messages', () => {
      expect(() =>
        policy.canSendDMMessage(
          actor('user-1'),
          ctx('user-1', [{ userId: 'user-1', role: 'owner' }])
        )
      ).not.toThrow();
    });

    it('allows dm to send dm messages', () => {
      expect(() =>
        policy.canSendDMMessage(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'dm' }
          ])
        )
      ).not.toThrow();
    });

    it('rejects player', () => {
      expect(() =>
        policy.canSendDMMessage(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'player' }
          ])
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canViewDMContent', () => {
    it('allows owner to view dm content', () => {
      expect(() =>
        policy.canViewDMContent(
          actor('user-1'),
          ctx('user-1', [{ userId: 'user-1', role: 'owner' }])
        )
      ).not.toThrow();
    });

    it('allows dm to view dm content', () => {
      expect(() =>
        policy.canViewDMContent(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'dm' }
          ])
        )
      ).not.toThrow();
    });

    it('rejects player', () => {
      expect(() =>
        policy.canViewDMContent(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'player' }
          ])
        )
      ).toThrow(ForbiddenException);
    });
  });

  describe('canRollDM', () => {
    it('allows owner to roll dm dice', () => {
      expect(() =>
        policy.canRollDM(
          actor('user-1'),
          ctx('user-1', [{ userId: 'user-1', role: 'owner' }])
        )
      ).not.toThrow();
    });

    it('allows dm to roll dm dice', () => {
      expect(() =>
        policy.canRollDM(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'dm' }
          ])
        )
      ).not.toThrow();
    });

    it('rejects player', () => {
      expect(() =>
        policy.canRollDM(
          actor('user-2'),
          ctx('user-1', [
            { userId: 'user-1', role: 'owner' },
            { userId: 'user-2', role: 'player' }
          ])
        )
      ).toThrow(ForbiddenException);
    });
  });
});
