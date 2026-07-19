import { ForbiddenException, Injectable } from '@nestjs/common';
import { AccessTokenPayload } from '../../auth/auth.types';
import type { CampaignContext } from '../../campaigns/policies/campaign.policy';

const MANAGE_ROLES = new Set(['owner', 'dm']);
const VIEW_ROLES = new Set(['owner', 'dm', 'player', 'spectator']);

/// Spec §旧代码清理: 原 `sessions/policies/session.policy.ts` 的迁移版本.
/// 旧 sessions 模块已删除, 但 check-requests 仍需要基于 CampaignContext
/// 的角色校验, 因此把 policy 收纳到本模块内部.
@Injectable()
export class SessionPolicy {
  canStartSession(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.assertCanManage(actor, campaign, 'Only the owner or a DM can start a session');
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

  canViewDMContent(
    actor: AccessTokenPayload,
    campaign: CampaignContext
  ): void {
    this.assertCanManage(actor, campaign, 'Only the owner or a DM can view DM content');
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
