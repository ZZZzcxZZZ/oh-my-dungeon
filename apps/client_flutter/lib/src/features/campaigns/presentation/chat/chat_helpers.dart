import 'package:flutter/material.dart';

import '../../domain/campaign_actor.dart';

/// 战役聊天页共享的文本与常量资源。从 campaign_chat_page.dart 抽出，
/// 供聊天泡泡、成员列表、检定弹窗等子组件复用。
String chatText(String key) => switch (key) {
      'act' => '做',
      'actHint' => '描述动作...',
      'all' => '全部',
      'campaignChatRoom' => '战役聊天室',
      'campaignContentLibrary' => '战役资料库',
      'campaignMembers' => '战役成员',
      'characterSheet' => '角色卡',
      'checkRequest' => '检定请求',
      'checkRequestHint' => '向玩家发起属性、技能或豁免检定',
      'contentLibrary' => '资料库',
      'contentType' => '资料类型',
      'dmControl' => 'DM 控场',
      'dmControlDescription' => '这里会继续整合遭遇、成员状态和隐藏信息。',
      'dmControlHint' => '遭遇、成员状态和 DM 私有工具',
      'emptyMembers' => '还没有绑定角色',
      'emptyContent' => '没有找到可用资料',
      'emptyChat' => '还没有消息\n从下方开始说话或做动作',
      'encounterControl' => '遭遇控场',
      'encounterControlHint' => '管理先攻、回合、敌人生命值和状态',
      'members' => '成员',
      'memberStatus' => '成员状态',
      'memberStatusHint' => '查看角色 HP、AC、状态和可见信息',
      'moreTableTools' => '更多跑团功能',
      'noBoundCharacter' => '请先在战役中绑定角色',
      'invalidDice' => '掷骰表达式无效：',
      'quickRoll' => '快速掷骰',
      'retry' => '重试',
      'rollDice' => '掷骰',
      'say' => '说',
      'sayHint' => '说些什么...',
      'search' => '搜索',
      'searchContent' => '搜索资料',
      'sendFailed' => '发送失败',
      'send' => '发送',
      'tableLog' => '跑团日志',
      'tableLogHint' => '查看聊天、掷骰、状态变化和关键事件',
      'tableTools' => '桌面工具',
      'tableToolsDescription' => '桌面能力已经并入战役聊天室；常用操作从这里打开。',
      'tableToolsHint' => '检定、日志和战役现场工具',
      'unknownSpeaker' => '未知发言者',
      'unboundCharacter' => '未绑定角色',
      _ => key,
    };

const List<String> quickDice = [
  'd20',
  'd12',
  'd10',
  'd8',
  'd6',
  'd4',
  'd100',
];

const List<String> contentTypeFilters = [
  'spell',
  'equipment',
  'item',
  'species',
  'class',
  'background',
  'feat',
  'condition',
  'monster',
];

String avatarText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first;
}

String actorStatusLine(CampaignActor actor) {
  final currentHp = actor.sheet['currentHp'];
  final maxHp = actor.sheet['maxHp'];
  final armorClass = actor.sheet['armorClass'];
  final classSummary = actor.sheet['classSummary']?.toString().trim();
  final level = actor.sheet['level'];
  return [
    if (classSummary != null && classSummary.isNotEmpty)
      level is num ? '$classSummary ${level.toInt()}级' : classSummary,
    if (currentHp is num && maxHp is num)
      'HP ${currentHp.toInt()}/${maxHp.toInt()}',
    if (armorClass is num) 'AC ${armorClass.toInt()}',
  ].join(' · ');
}

String campaignRoleLabel(String role) => switch (role) {
      'owner' => '创建者',
      'dm' || 'manager' => 'DM',
      'spectator' => '旁观',
      _ => '玩家',
    };

String contentTypeLabel(String type) => switch (type) {
      'background' => '背景',
      'class' => '职业',
      'condition' => '状态',
      'equipment' => '装备',
      'feat' => '专长',
      'item' => '物品',
      'monster' => '怪物',
      'species' => '种族',
      'spell' => '法术',
      _ => type,
    };
