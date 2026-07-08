import { ForbiddenException, Injectable } from '@nestjs/common';
import { AccessTokenPayload } from '../../auth/auth.types';
import type { CampaignContext } from '../../campaigns/policies/campaign.policy';

const MANAGE_ROLES = new Set(['owner', 'dm']);
const VIEW_ROLES = new Set(['owner', 'dm', 'player', 'spectator']);

@Injectable()
export class SessionPolicy {
  canCreateSession(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.assertCanManage(actor, campaign, 'Only the owner or a DM can create a session');
  }

  canStartSession(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.assertCanManage(actor, campaign, 'Only the owner or a DM can start a session');
  }

  canEndSession(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.assertCanManage(actor, campaign, 'Only the owner or a DM can end a session');
  }

  canViewSession(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    if (actor.userId === campaign.ownerId) return;

    const membership = campaign.members.find(
      (member) => member.userId === actor.userId
    );
    if (!membership || !VIEW_ROLES.has(membership.role)) {
      throw new ForbiddenException(
        'You are not a member of this campaign'
      );
    }
  }

  canSendDMMessage(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.assertCanManage(actor, campaign, 'Only the owner or a DM can send DM messages');
  }

  canViewDMContent(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.assertCanManage(actor, campaign, 'Only the owner or a DM can view DM content');
  }

  canRollDM(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.assertCanManage(actor, campaign, 'Only the owner or a DM can roll DM dice');
  }

  private assertCanManage(
    actor: AccessTokenPayload,
    campaign: CampaignContext,
    message: string
  ): void {
    if (actor.userId === campaign.ownerId) return;

    const membership = campaign.members.find(
      (member) => member.userId === actor.userId
    );
    if (!membership || !MANAGE_ROLES.has(membership.role)) {
      throw new ForbiddenException(message);
    }
  }
}
