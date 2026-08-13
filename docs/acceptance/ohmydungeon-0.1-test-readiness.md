# OhMyDungeon 0.1 测试候选版验收

## 产品收敛

OhMyDungeon 0.1 是离线优先、可自托管的 D&D 角色与战役协作工具。竞品调研后的
取舍如下：

- 参考 D&D Beyond，把资料库作为角色创建、升级和日常管理的规则来源，而不是孤立 Wiki；
- 参考 Foundry VTT，把资料条目、角色状态和操作拆成可查询、可复用、可审计的边界；
- 参考即时通讯产品，把战役固定为长期存在的主聊、私聊和小群，不引入 Room/Session 前置流程；
- 0.1 不加入地图、战斗引擎或 AI Agent 运行时，未完成能力不显示入口。

## 发布边界

- 公开构建：`assets/bundled_content.json` 必须保持 `{}`，不包含商业规则正文；
- 私人构建：只允许通过 `scripts/build_private_client.ps1` 临时注入本地资料，并在构建后恢复占位文件；
- Android 应用 ID：`app.ohmydungeon.client`；正式公开测试必须使用稳定签名，配置见
  `apps/client_flutter/android/key.properties.example`；
- 新备份扩展名为 `.ohmydungeon-backup`，导入继续兼容 `.openquest-backup` 与
  `.dndtable-backup`；
- `dnd_table_client` Dart 包名和 `dnd-table-character/v2` 是兼容标识，本轮不做破坏性改名。

## 测试清单

- [ ] 首次启动、离线启动、账号登录与自动登录；
- [ ] 账号切换后本地角色与私人资料完全隔离；
- [ ] 角色创建、编辑、升级、Markdown 导入导出和自动镜像；
- [ ] 玩家加入战役、绑定角色、主聊发言、私聊与小群；
- [ ] DM 旁白/NPC 身份、角色管理、档案和快捷操作；
- [ ] Web 桌面和移动视口无溢出、空白页或控制台错误；
- [ ] Android 覆盖安装、图标、应用名、备份恢复和自建 HTTP 服务器连接；
- [ ] `npm run check`、Docker Compose 配置、公开 Web 构建、公开 APK 构建；
- [ ] 私人资料构建完成后 `bundled_content.json` 自动恢复为 `{}`。

## 发布前人工决策

`OhMyDungeon` 已完成初步同名检索，当前只发现一个同名像素素材包。公开发布前仍需
完成目标发行地区的正式商标、域名与应用商店检索；这不阻塞当前本地和受控私人测试。

## 调研来源

- [D&D Beyond 2024 角色创建流程](https://www.dndbeyond.com/posts/1787-how-to-create-a-character-using-the-2024-players)
- [D&D Beyond 玩家与角色工具](https://www.dndbeyond.com/en/players)
- [Foundry VTT D&D 5e 系统](https://foundryvtt.com/packages/dnd5e)
- [Foundry VTT Compendium Packs](https://foundryvtt.com/article/compendium/)
- [同名像素素材包](https://peb.blue/assets/oh-my-dungeon)
