# OhMyDungeon 客户端 UI 设计系统审查报告

> 依据 [google-labs-code/design.md](https://github.com/google-labs-code/design.md)（DESIGN.md 格式规范，
> version alpha）对 `apps/client_flutter` 全部 UI 元素进行审查。
>
> - 审查日期：2026-07-29（工作区基线）
> - 审查范围：`apps/client_flutter/lib/src` 下 70 个含 UI 的源文件，约 430 个 UI 元素
> - 审查方法：DESIGN.md skill 规则集 + 全量静态扫描 + 9 路并行逐文件审查 + Flutter SDK 实测对比度
> - 结论分级：`必须修复`（违反设计系统契约/不满足 WCAG AA）/ `建议修改`（漂移、不一致）/ `仅供参考`（魔数、体验细节）

---

## 0. 审查依据（skill 摘要）

DESIGN.md 是一种向编码代理描述视觉身份的文件格式：YAML front matter 承载机器可读的设计 token
（`colors`/`typography`/`rounded`/`spacing`/`components`，支持 `{path.to.token}` 引用），Markdown
正文按固定顺序提供人读的设计依据（Overview → Colors → Typography → Layout → Elevation & Depth →
Shapes → Components → Do's and Don'ts）。配套 lint 规则要求：token 引用可解析、必须存在 `primary`
颜色、组件 `backgroundColor`/`textColor` 满足 WCAG AA（正文 4.5:1）、颜色 token 不得成为孤儿、
圆角与间距保持统一刻度。

本次审查据此检查了每个 UI 元素：是否使用主题 token（`colorScheme` 角色 / `textTheme` / 组件主题）而
非硬编码值、圆角是否落在 8/16dp 契约内、间距是否落在 4/8px 韵律上、文字是否使用与背景匹配的
`on-*` 角色、投影/高度是否符合扁平化契约、以及无障碍（Tooltip/语义、触达尺寸）。

**项目现状**：仓库中**不存在 `DESIGN.md`**。但 `app_theme.dart` 实际上已是一个隐含的设计系统
（下文第 1 节"主题契约"），本次审查以该契约为事实标准，并在文末给出可直接采用的 `DESIGN.md`
草案（附录 B）。

---

## 1. 主题契约（事实标准，来自 `app_theme.dart`）

| 维度 | 契约 |
|---|---|
| 色彩 | Material 3 `ColorScheme.fromSeed(seed=用户偏好, brightness, contrastLevel 0/0.5, variant)`；全部颜色必须来自 `colorScheme` 角色 |
| 字体 | `NotoSansSC`（Variable，同时映射 Roboto 族避免 Web 外链）；文本一律使用 `textTheme` |
| 圆角 | 组件 8dp；对话框/底部弹层 16dp |
| 高度 | 扁平化：`elevation: 0`、`surfaceTint: transparent`（唯一例外：浮动 SnackBar） |
| 间距 | 8px 刻度 + 4px 半步（4/8/12/16/24/32/48…） |
| 组件色 | 填充按钮 primary/onPrimary；抬升按钮 surfaceContainerHigh/onSurface；卡片 surfaceContainerLow + outlineVariant 描边；chip surfaceContainerHigh（选中 secondaryContainer）；输入框填充 surfaceContainerHigh；对话框/弹层 surfaceContainerHigh；SnackBar inverseSurface 浮动式；导航 surfaceContainer + secondaryContainer 指示器；Switch 选中 primary 轨道 |
| 文字配对 | 彩色底上必须使用对应 `on-*` 角色（secondaryContainer 上 → onSecondaryContainer，errorContainer 上 → onErrorContainer…） |

---

## 2. 总体结论

### 2.1 做得好的地方（占比高，约 85% 元素合规）

- **零硬编码颜色**：全部 70 个文件未发现 `Color(0x…)` / `Colors.X` 直写（唯一合理解释是
  `seed_color_dialog.dart` 中 6 个预设 seed 常量与 `Colors.transparent` 墨迹层）。这是
  `ColorScheme.fromSeed` 架构的直接收益，也是 DESIGN.md "colors 全部 token 化" 规则的满分项。
- **对比度整体优秀**：对 6 个预设 seed × 亮/暗 × 对比度 0/0.5 × 5 种 dynamicSchemeVariant 实测
  312 + 14 组角色配对，**全部通过 WCAG AA**（最弱组合 fidelity 暗色
  secondaryContainer/onSecondaryContainer = 4.55:1，详见附录 A）。
- **扁平化基本落实**：除 3 处外无任何 `BoxShadow`/非零 `elevation`。
- **on-\* 配对正确率高**：冲突横幅（errorContainer/onErrorContainer）、对比块
  （primaryContainer/onPrimaryContainer、secondaryContainer/onSecondaryContainer）、Vault 错误条、
  头像倒地角标（error/onError）等均为典范实现。
- **无障碍意识好**：绝大多数纯图标控件带 `Tooltip`（统计 9 路审查仅发现 5 处缺失）；SelectableText
  用于邀请码等可复制文本；头像带 Semantics。

### 2.2 必须修复（5 类）

| # | 问题 | 影响 | 位置 |
|---|---|---|---|
| E1 | **选中态 Chip 文字角色错配（全局）**：`chipTheme.labelStyle` 固定为 `onSurface`，选中后背景变 `secondaryContainer`，文字仍是 `onSurface` 而非 `onSecondaryContainer`（checkmark 倒是用了 onSecondaryContainer，自相矛盾）。实测对比度仍过 AA，但违反 on-\* 契约 | 所有 ChoiceChip/FilterChip/InputChip 选中态 | `app_theme.dart:106`（配合 104） |
| E2 | **4 处彩色底未用 on-\* 文字**：secondaryContainer/primaryContainer 背景上直接使用默认 `onSurface` 文字 | 货币栏空态、角色摘要小格、装备预算摘要文字行、聊天 say 气泡 | `character_detail_page.dart:1377`、`characters_tab_page.dart:1489-1490`、`character_editor_page.dart:3846-3851`、`campaign_chat_bubble.dart:103-107` |
| E3 | **4 处用 `colorScheme.outline` 作为正文文字颜色**：outline 是描边/提示角色，实测仅 ~4.1–4.3:1，**低于 WCAG AA 4.5:1** | 空态/提示文字可读性 | `campaign_chat_page.dart:215-217`、`campaign_detail_page.dart:161-163`、`gameplay_settings_section.dart:267-272`（另有 content 区多处空态图标用 outline，图标不受 4.5 约束） |
| E4 | **对话框继承了 M3 默认 elevation 3.0**：`dialogTheme` 未显式 `elevation: 0`（bottomSheetTheme 设了 `modalElevation: 0`，dialogTheme 漏了） | 全应用 AlertDialog/SimpleDialog 出现投影，破坏扁平化 | `app_theme.dart:134-138` |
| E5 | **SearchBar 完全未主题化**：无 `searchBarTheme`，回落到 Flutter M3 默认 `StadiumBorder`（≈28dp 胶囊）+ `elevation: 6`（已核对 SDK 源码 `search_anchor.dart:1847-1860`） | 搜索框与 8dp 输入框契约、扁平契约双违 | `app_theme.dart`（缺 searchBarTheme）；使用处 `app_search_bar.dart:24`、`dm_quick_ops_sheet.dart:531`、`campaign_character_picker_sheet.dart:68` |

### 2.3 建议修改（高频漂移）

- **输入框圆角系统性漂移**：35 处（9 个文件）`border: OutlineInputBorder()`（不带 radius）把主题 8dp 输入框
  重置为 Flutter 默认 4dp，且丢掉主题的聚焦 2dp 边框；同一页面里另一些输入框依赖主题（8dp），
  形成同元素双风格。见 4.1 节清单。
- **间距漂移泛滥**：off-scale 值 2/5/6/7/10/14/18/20/40/80/96 出现在 20+ 文件中（详见 4.2 节）。
- **圆角漂移**：6（档案标签徽标）、12（概览面板卡片×2、资料库分类卡）、24（seed 色板 InkWell、
  聊天气泡胶囊为有意为之）、28/2（筛选弹层）见 4.3 节。
- **"搜索栏/表单" 与 "8dp 输入框" 两种输入风格并存**，以及部分页面容器半径 8/12 混用。

### 2.4 仅供参考

- 魔数：固定输入宽度 72/96/104/120、对话框内容尺寸 440/480×420/560/620/760/960、`heightFactor`
  0.78/0.82、网格 `mainAxisExtent 78`、图标尺寸 18/19/40/48/56/64 等，建议沉淀为 token。
- 少量颜色-only 的 `TextStyle(color: …)`（约 15 处），无字号/字重漂移，建议统一为
  `textTheme.x.copyWith` 以利全局改版。
- 触达尺寸：`visualDensity.compact` 的货币增减按钮、资源 pip（约 40px）低于 48dp 建议值；
  CampaignAvatar 默认触达 = 视觉尺寸 40px（提供 `tapTargetSize` 参数）。
- 语义：批量导入勾选 Checkbox 未与条目名关联；`character_conflict_resolution_page` 等文件
  无实质问题。
- 死控件：资料库分类卡 `InkWell(onTap: () {})` 空操作但呈可点击样式
  （`content_home_page.dart:108`）—— 建议隐藏或接入跳转，避免误导。
- 品牌字符串不一致：`AppIdentity.productName = 'OhMyDungeon'`（MaterialApp title）与
  `displayName = 'Oh My Dungeon!'`（`app_identity.dart:2-3`）并存；且 MaterialApp 未配置
  `localizationsDelegates`/`locale`，而全部可见文案为硬编码简体中文（`dnd_table_app.dart:339-346`）。

---

## 3. 按 skill 章节逐项审查

### 3.1 Overview（品牌定位）

现状：无文字化定位。从代码反推：**"安静的工具台"** —— 低饱和 M3 tonal 体系、8dp 圆角、零投影、
NotoSansSC 中文优先、信息密度中等偏密。相比 skill 示例（"Paws & Paths" 的品牌叙事），本应用缺少
可指导代理的 Overview 文案（色相随用户 seed 变化，更需要文字界定"不变的部分"）。建议在
DESIGN.md 中补写（附录 B 已拟）。

### 3.2 Colors

- **token 结构**：`ColorScheme.fromSeed` 全角色可用；无自定义扩展色；6 个预设 seed（Material 紫/
  蓝/绿/青/橙/中性 + 自定义 hex）+ 高对比（contrastLevel 0.5）+ 4 种 scheme variant。
- **硬编码核查**：唯一硬编码是 seed 预设（`seed_color_dialog.dart:29-34`），属于 sanctioned
  exception；其余 `Colors.transparent` 仅用于墨迹/消除 tint。
- **对比度**：全角色配对实测全部 ≥4.55:1（附录 A）。注意 E3 中 `outline` 被误用作文字色。
- **语义色运用**：error 用于破坏性/错误（正确）；primary 用于主操作/图标强调；tertiary 仅出现在
  CampaignAvatar 生命环"受伤"档 —— tertiary 角色整体使用不足，符合 DESIGN.md "至少一个 primary"
  的最低要求，但建议在 Components 中显式定义。

### 3.3 Typography

- 基础：`fontFamily: NotoSansSC`，未自定义 `textTheme` → 全部为 M3 默认层级（displayLarge 57 …
  labelSmall 11），字号随用户"字体缩放"偏好。
- **自定义 TextStyle 清单（19 个文件内 27 处）**：
  - 颜色-only（约 15 处）：error/onSurfaceVariant/outline 着色，无字号字重漂移 —— 建议改
    `copyWith` 统一（`auth_page.dart:151`、`data_management_page.dart:161`、`characters_tab_page.dart:483/1376`、
    `content_search_page.dart:180`、`vault_settings_section.dart:100` 等）。
  - 语义性字号/字重（建议 token 化，而非删除）：JSON 预览 `monospace 13`（`campaign_json_import_dialog.dart:106`）、
    骰式 `monospace`（`content_block_view.dart:316-318`）、引用斜体（`content_block_view.dart:147`）、
    旁白 w500+斜体（`campaign_chat_bubble.dart:218-222`）、系统消息 bold（`campaign_chat_bubble.dart:251-253`）、
    掷骰预览 bold（`dice_tray_dialog.dart:270`）。
  - 与 textTheme 冲突的硬编码字号：邀请码 `24/bold/letterSpacing 2`（`campaign_detail_page.dart:67-70`）、
    邀请码 `bold/letterSpacing 1`（`campaign_invite_tile.dart:25`）、邀请卡 `fontSize 12/12w600`
    （`campaign_overview_panel.dart:403-406`，固定字号会失效字体缩放）。
  - 动态字号：头像首字母 `size*0.32/w600`（`campaign_avatar.dart:116-119`，视觉合理，建议 FittedBox+token）。

### 3.4 Layout & Spacing

- 全局以 4/8px 韵律为主（SizedBox 8/12/16、EdgeInsets 16/24 为最大宗）。
- **off-scale 汇总**（建议修复，全部为"建议修改"级）：见 4.2 节完整清单，代表性位置：
  - 列表底部 FAB 让位 `96/80`（`campaigns_tab_page.dart:233`、`characters_tab_page.dart:266/501`、
    `character_editor_page.dart:247`）；
  - 区块节奏 10/14/18/20 散布（`campaign_overview_panel.dart:79/251`、`character_editor_page.dart:2272/3345`、
    `campaigns_tab_page.dart:734/768`、`content_detail_page.dart:225` 等）；
  - Chip Wrap `spacing 6`（`publish_character_sheet.dart:51-52/72-73`、`character_detail_page.dart:2895`、
    `characters_tab_page.dart:1311` 等 8 处）；
  - 微距 2（`campaign_list_tile.dart:256`、`archive_panel` 多处、`data_management_page.dart:199`、`character_detail_page.dart:3573`）。
  - 同名区块组件节奏不一致：`character_detail_page.dart` 的 `_Section` 底部 padding 20，而
    `character_editor_page.dart`（L3974）与 `character_upgrade_page.dart`（L262）均为 24。

### 3.5 Elevation & Depth

- 契约：扁平（tonal layers + 描边表达层级，无投影）。
- 违反：
  - **E5** SearchBar 默认 elevation 6（全局 3 处）；
  - 构建器底部栏 `Material(elevation: 2)`（`character_editor_page.dart:2186`）；
  - **E4** 对话框继承默认 elevation 3.0（全应用）。
- 正确范例：SnackBar 浮动式（主题内定义）、BottomSheet `modalElevation: 0`、全部卡片 `elevation: 0`
  + `surfaceTint: transparent`。

### 3.6 Shapes

- 契约：组件 8 / 对话框与弹层 16。
- **漂移清单**（详见 4.3）：6（`campaign_archive_editor_page.dart:435`、`campaign_archive_panel.dart:403`）、
  12（`campaign_overview_panel.dart:190/195/197/383/385`、`content_home_page.dart:105/107`）、
  24（`seed_color_dialog.dart:91`、`campaign_chat_composer.dart:75` —— 后者为有意为之的聊天气泡胶囊，
  建议显式 token 化）、28/2（`content_search_page.dart:372/384`）、4（全部 OutlineInputBorder 覆盖点）。
- 同文件内 8/12 并存（`campaign_overview_panel.dart` 三个兄弟容器 8/12/12），属不一致。

### 3.7 Components（按 skill 组件清单逐项）

#### 按钮（Buttons）
- 契约：filled primary/onPrimary、elevated surfaceContainerHigh/onSurface、text primary、
  outlined primary/outline、tonal secondaryContainer/onSecondaryContainer，全部 8dp。
- 现状：**全面合规**；`FilledButton.tonal`/`IconButton.filledTonal` 的 on-\* 配对正确
  （`dm_quick_ops_sheet.dart:301-318`、`server_and_account_section.dart:119`）。
- 不一致：破坏性操作样式混用 —— 资料包页"清空"入口 outlined+error，但删除/清空确认对话框却是
  primary FilledButton（`content_package_settings_page.dart:116/148/223`）。建议统一为 error 确认。
- 细节：发送按钮禁用态用 `onSurface 0.12/0.38` 透明度（`campaign_chat_composer.dart`），可接受。

#### Chips（含选中态问题 E1）
- 契约：surfaceContainerHigh、选中 secondaryContainer、8dp、outlineVariant 描边。
- **E1** 为全局选中态角色错配（`app_theme.dart:106`）。
- 间距不一致：publish 页 Wrap 6 vs DM 弹层 8（同元素不同节奏）。

#### Lists
- 全面使用默认 ListTile + dividerTheme（outlineVariant 1px）—— 合规。
- 细节：`campaign_list_tile.dart:391-393` 分组头计数用裸 TextStyle 而同类标签用 labelMedium.copyWith，
  文件内不一致；私聊/小群缩进 48 与 M3 规范一致。

#### Tooltips（无障碍）
- 纯图标控件 Tooltip 覆盖率高；缺失 5 处：档案编辑器"添加标签"后缀按钮
  （`campaign_archive_editor_page.dart:249`）、角色行"正在发言"图标（`campaign_characters_panel.dart:189`）、
  资料包删除按钮（`content_package_settings_page.dart:207-210`）。
- 触达尺寸：`visualDensity.compact` 的货币/资源控件与 40px 头像低于 48dp（`character_detail_page.dart:3579`、
  `campaign_avatar.dart`）。

#### Checkbox / Radio
- Checkbox 使用主题（primary）—— 合规（`dm_quick_ops_sheet.dart:283-296`、`campaign_archive_editor_page.dart:321`）。
- "切换服务器"用 radio 图标 + 禁用当前项表达选中（`server_and_account_section.dart:147-156`）——
  选中项被禁用置灰而非高亮，属可读性瑕疵（参考）。
- 批量导入 Checkbox 缺语义关联（`batch_import_wizard_dialog.dart:207`）。

#### 输入框（Input fields）—— 本应用最大漂移面
- 主题输入框（8dp 填充式）≈ 24 处合规（`campaigns_tab_page.dart:477` 为标准范例）。
- **35 处 `border: OutlineInputBorder()` 覆盖**（见 4.1 清单）—— 4dp 圆角 + 丢失聚焦边框，
  且与同页合规输入框并存。
- `isDense: true` 使输入高度低于 M3 56dp 建议（`campaign_content_editor.dart:93/102`、
  `campaign_json_import_dialog.dart:104`）。

#### 搜索框（SearchBar）—— 未主题化（E5）
- `app_search_bar.dart` 封装良好（Tooltip、Badge 计数），但主题层缺 `searchBarTheme`。

#### 对话框 / 底部弹层
- 颜色与圆角 16 全面合规（dialogTheme/bottomSheetTheme 单一来源）。
- **E4**：对话框投影。底部弹层 `modalElevation: 0` 正确。
- 内容尺寸魔数：420/440/480×420/560/620/760/960 各对话框自选，无统一 token。

#### SnackBar
- 全部浮动式 inverseSurface/onInverseSurface/8dp —— 契约完美执行。

#### 导航
- NavigationBar/Rail、TabBar、SegmentedButton 全部主题化（secondaryContainer 指示器 +
  onSecondaryContainer 选中）—— 合规典范。

#### 头像 / Badge / 进度 / 空态
- CampaignAvatar：角色环 primary/tertiary/error/outline、倒地角标 error/onError + Tooltip + Semantics
  —— 优秀；初始字与触达尺寸见 3.3/3.7。
- Badge（未读/筛选计数）用主题 error/onError —— 合规。
- 空态风格未统一：有带图标+CTA 的完整空态、有纯文字（`dm_quick_ops_sheet.dart:560` 无内边距 vs
  `campaign_character_picker_sheet.dart:79` 有 24 内边距）；多处空态文字用 outline（E3）。

### 3.8 Do's and Don'ts（现状对照）

| skill 建议 | 本项目现状 |
|---|---|
| Do 每屏只用一个主操作色 | ✅ primary 只用于主 CTA；tonal 作次操作 |
| Don't 混用圆角 | ❌ 8/4/6/12/24/28 并存（见 4.3） |
| Do 保持 WCAG AA | ✅ 角色配对全部达标；❌ outline 文字 4 处不达标（E3） |
| Don't 一屏超过两个字重 | ✅ 主 UI 未发现字重滥用（头像/邀请码 3 处例外） |
| Do 使用 token 而非裸值 | ✅ 颜色/圆角/高度；❌ 间距/输入框边框/对话框尺寸存在裸值 |
| Do 有 `primary` 颜色 | ✅ seed 派生，恒有 primary |

---

## 4. 重点问题定位（必须修复 / 建议修改速查）

### 4.1 输入框圆角覆盖清单（共 35 处，9 个文件）

`core/widgets/numeric_input_field.dart:72`；`core/dice/dice_tray_dialog.dart:211`；
`campaign_chat_page.dart:999, 1417`；`campaigns_tab_page.dart:604, 820, 829`；
`check_request_sheet.dart:107, 126`；`campaign_content_editor.dart:92, 101`；
`campaign_json_import_dialog.dart:101`；`character_detail_page.dart:2017, 2237, 2981, 3064, 3176, 3186, 3238, 3248, 3257`；
`character_editor_page.dart:269, 282, 293, 348, 416, 431, 450, 488, 506, 542, 560, 580, 2147, 3256`。

修复方式：删除 `border:` 覆盖，统一走 `inputDecorationTheme`（参考 `campaigns_tab_page.dart:477` 的
join-dialog 输入框）。

### 4.2 间距漂移代表位置（完整清单见 3.4）

96/80（FAB 让位：`campaigns_tab_page.dart:233`、`characters_tab_page.dart:266,501`、
`character_editor_page.dart:247`）；20（`campaigns_tab_page.dart:768,782`、`content_detail_page.dart:225`、
`content_entry_preview_page.dart:22,134,157`、`character_detail_page.dart:3345`、`character_editor_page.dart:2139,2279`、
`check_request_sheet.dart:141`、`campaign_archive_panel.dart:958`、`character_upgrade_page.dart:76`）；
6（Chip Wrap 8 处）；10/14/18（`campaign_overview_panel.dart:79,200,251`、`characters_tab_page.dart:1304`、
`character_editor_page.dart:2272,2500`）；2（9 处微距）。

### 4.3 圆角漂移代表位置

6：`campaign_archive_editor_page.dart:435`、`campaign_archive_panel.dart:403`；
12：`campaign_overview_panel.dart:190,195,197,383,385`、`content_home_page.dart:105,107`；
24：`seed_color_dialog.dart:91`（InkWell）、`campaign_chat_composer.dart:75`（有意，建议 token 化）；
28/2：`content_search_page.dart:372,384`。

---

## 5. 分区审查小结（9 区）

| 分区 | 文件数 | 硬编码颜色 | 主要问题 |
|---|---|---|---|
| core + 应用壳 | 7 | 0 | SearchBar 未主题化（E5）；NumericInputField/下拉 4dp；骰面 Chip Wrap 6 |
| shell / 设置 | 16 | 仅 6 seed | seed 色板 24dp InkWell；数据管理行距 2；空预设 outline 文字（E3）；radio 选中态可读性 |
| 战役核心页 | 4 | 0 | 输入框 4dp ×3；outline 空态文字（E3）；列表 96 让位 |
| 战役中心面板 | 4 | 0 | 容器 12 vs 8 不一致；TagChip 6dp；对话框投影（E4）；邀请卡 onSurface-on-secondaryContainer（E2） |
| 战役角色子页 | 4 | 0 | SearchBar ×2 未主题化（E5）；对话框尺寸魔数 420；Chip Wrap 6；选中态角色（E1） |
| 战役聊天 | 7 | 0 | 输入框 4dp ×2；say 气泡 onSurface-on-primaryContainer（E2）；composer 24 胶囊（有意）；旁白/系统消息微字重；off-scale 间距簇 |
| 战役内容+小组件 | 6 | 0 | 输入框 4dp ×4；JSON monospace 13；邀请码字距；头像初始字；头像底色角色不一致（primaryContainer vs surfaceContainerHighest） |
| 角色 | 8 | 0 | 输入框 4dp ×23（最大集群）；构建器底栏 elevation 2；货币箱/摘要格/预算文字 onSurface（E2）；间距漂移最密集 |
| 资料库 | 14 | 0 | 筛选弹层 28/2 + surface 覆盖；分类卡 12；页边距 20/28；调用块 on-\* 全对（亮点） |

---

## 6. 修复优先级建议

1. **P0（契约级，改动小收益大）**：E1 chip labelStyle → WidgetStateProperty 按选中态切换
   onSecondaryContainer；E4 `dialogTheme` 补 `elevation: 0`；E5 补 `searchBarTheme`
   （surfaceContainerHigh / 8dp / elevation 0）。
2. **P0**：E2/E3 七处文字角色与对比度修正（onSecondaryContainer / onPrimaryContainer / onSurfaceVariant）。
3. **P1**：删除 35 处 `border: OutlineInputBorder()` 覆盖；统一 Chip Wrap 间距为 8；
   对话框尺寸沉淀为 token（sm 440 / md 560 / lg 760 等）。
4. **P1**：圆角 6/12/24/28/2 收敛到 8/16 + 显式例外 token（composer 24 胶囊、筛选弹层 28）。
5. **P2**：补 5 处 Tooltip；触达尺寸 ≥48dp；空态统一组件；写 DESIGN.md（附录 B）。

---

## 7. 修复执行记录（2026-07-29，与审查同步完成）

| 项 | 状态 | 变更 |
|---|---|---|
| E1 chip 选中态角色 | ✅ 已修复 | `app_theme.dart` chipTheme 增加 `secondaryLabelStyle: onSecondaryContainer`（labelStyle 保持 onSurface），新增测试覆盖 |
| E4 对话框投影 | ✅ 已修复 | `app_theme.dart` dialogTheme 补 `elevation: 0`，新增测试覆盖 |
| E5 SearchBar 未主题化 | ✅ 已修复 | `app_theme.dart` 新增 searchBarTheme：elevation 0、surfaceTint transparent、surfaceContainerHigh、8dp、outlineVariant 描边，新增测试覆盖 |
| E2 彩色底 on-\* 文字 | ✅ 已修复 | 5 处：say 气泡（onPrimaryContainer）、货币栏空态与货币控件、角色摘要小格、装备预算（DefaultTextStyle 按 overBudget 切换）、邀请卡（IconTheme+DefaultTextStyle） |
| E3 outline 文字对比度 | ✅ 已修复 | 3 处 outline → onSurfaceVariant：空聊天、暂无描述、空预设提示 |
| 输入框 border 覆盖 | ✅ 已修复 | 9 个文件 35 处 `border: OutlineInputBorder()` 全部移除，回归主题 8dp 填充式输入框（含聚焦态） |
| DESIGN.md | ✅ 已落盘 | 仓库根 `DESIGN.md`（即附录 B 版本，经结构验证：无 broken ref、章节顺序正确、组件对比度达标） |
| 验证 | ✅ | `flutter analyze` 0 问题；新增 3 个主题测试通过；相关 widget 测试 47/47 通过；全量测试套件结果见下 |

第二批修复（同日完成）：

| 项 | 状态 | 变更 |
|---|---|---|
| Tooltip/语义 | ✅ 已修复 | 档案编辑器"添加标签"后缀按钮、资料包删除按钮补 Tooltip；角色行"正在发言"图标包 Tooltip |
| 死控件 | ✅ 已修复 | `content_home_page.dart` 分类卡移除空 InkWell，改静态卡片（无跳转目标不假装可点），圆角随同 12→8 |
| 圆角收敛 | ✅ 已修复 | 6→8（档案标签徽标、_TagChip）、12→8（概览面板 DM 入口/邀请卡、分类卡）、28→16 与 2→4（筛选弹层）、seed 色板涟漪 24→48（圆形）；唯一保留例外：composer 24 胶囊（已入 DESIGN.md `rounded.pill`） |
| 间距收敛 | ✅ 已修复 | Chip/Wrap spacing·runSpacing 6→8（22 处）；SizedBox 2/5/6/10/14/20 → 4/8/12/16；EdgeInsets 微距 2/6/7/10/14/18/20 归位；`_Section` 底部 20→24 统一；角色头 Wrap 10/2→8/4；FAB 让位 80→96 统一为单一常量；Divider 6→8；运行时网格 gap 10→8。扫描确认无残留 off-scale（`ringWidth + 2` 徽标偏移为派生值，保留） |
| 对话框尺寸 token | ✅ 已修复 | 新增 `core/presentation/dialog_sizes.dart`：form 420 / narrow 440 / compact 480 / standard 560 / wide 760 / full 960 / pickerHeight 416（420 归位 8px 节奏）/ guideHeight 620 / detailHeight 720，替换 6 处魔数（archive_panel 私有常量并入 wide） |
| 验证 | ✅ | `flutter analyze` 0 问题；全量 `flutter test` 结果见下 |

第三批（第 1 类代码修复 + 第 2 类设计系统治理）：

| 项 | 状态 | 变更 |
|---|---|---|
| 破坏性操作统一 | ✅ | 资料包删除/清空确认按钮 → error/onError 角色（`content_package_settings_page.dart`），与 outlined+error 入口一致 |
| 空态组件统一 | ✅ | 新增 `core/widgets/empty_state.dart`（图标+标题+可选说明/操作），替换 8 处空态（物品/角色拾取、条目详情×2、角色面板、DM 目录、战役离线/登录提示、服务器列表、资料库空态） |
| 头像底色统一 | ✅ | 战役列表头像 primaryContainer → surfaceContainerHighest/onSurfaceVariant（与 avatar_picker、campaign_avatar 一致） |
| TextStyle 统一 | ✅ | 16 处颜色-only `TextStyle(color:)` → `textTheme.x.copyWith`（含菜单项用 bodyLarge） |
| 选中服务器可读性 | ✅ | 当前项由禁用置灰改为 `selected` 高亮，点击选中项不产生操作 |
| 触达尺寸 ≥48dp | ✅ | 5 处 `visualDensity.compact` 移除（货币增减、资源 pip、装备消耗）；CampaignAvatar 默认触达 48；聊天模式切换 48dp 触达（InkResponse radius 24 + 40dp 视觉圆） |
| Checkbox 语义 | ✅ | 批量导入勾选包 `Semantics(label: 包名)` |
| DESIGN.md CI | ✅ | root `lint:design` 脚本 + GitHub Actions `design` job（`npx -y -p @google/design.md designmd lint DESIGN.md`）；未并入本地 `check` 链（避免离线环境破坏门禁） |
| 主题契约回归测试 | ✅ | `app_theme_test.dart` 新增 10 项契约断言（卡片/对话框/弹层/snackbar/导航/输入框/分隔线/按钮五态/开关/分段控件），共 21 项 |
| Golden 测试 | ✅ | `dart_test.yaml` + `test/golden/`：3 个代表性基线（say 气泡、邀请卡、EmptyState），默认跳过，`--tags golden --dart-define=GOLDEN_TESTS=true --update-goldens` 启用；基线已用 flutter_tester（确定性软件渲染 + 资产字体）生成并验证匹配；CI 新增 `golden` job 在 Linux 上以验证模式自动检验跨平台一致性（固定 flutter-version 3.41.4 与基线生成环境一致），无需人工干预 |
| 语义排版 token | ✅ | 新增 `app/theme/app_text_styles.dart`（mono-code/narrator/system-message/dice-notation/invite-code/invite-code-compact/avatar-initials + monoFamily），替换 8 处散落样式；DESIGN.md typography 同步新增 6 个 token |
| 验证 | ✅ | `flutter analyze` 0 问题；全量 `flutter test` 868 通过 / 5 跳过（3 golden 默认跳过） |

第四批（复核补漏 + DESIGN.md lint 真实接入）：

| 项 | 状态 | 变更 |
|---|---|---|
| 官方 CLI 安装 | ✅ | `npm install --save-dev @google/design.md`（^0.4.0，74 包，0 漏洞）；`lint:design` 改用本地 bin（离线可用）；CI `design` job 改为 `npm ci` + `npm run lint:design` |
| 官方 lint 结果 | ✅ | `npm run lint:design` → **errors 0 / warnings 0 / infos 1**（21 色 / 20 排版 / 3 圆角 / 7 间距 / 24 组件） |
| 触达尺寸补漏 | ✅ | 再移除 4 处 `visualDensity.compact`（构建器查看按钮×2、装备多选查看、升级规则查看）——上轮仅处理 character_detail_page，本次全库清零 |
| 空态补漏 | ✅ | 再替换 6 处裸空态（暂无其他成员、聊天空、未找到战役、没有匹配的怪物、没有可添加的条目、角色已不存在）；错误信息空态（error!）保留原样式 |
| TextStyle 补漏 | ✅ | 邀请卡 12px 副标题 → bodySmall（修复固定字号失效字体缩放）；检定卡标题 bold → titleMedium.copyWith；引用块 → 新增 `AppTextStyles.quote` token（DESIGN.md 同步新增 `quote` 排版 token） |
| 复核扫描 | ✅ | 全库扫描确认：无残留 compact、无裸空态（仅错误态保留）、无颜色-only TextStyle（除有意 DefaultTextStyle） |
| 验证 | ✅ | `flutter analyze` 0 问题；全量 `flutter test` 868 通过 / 5 跳过 |

仍保留的文档化例外：构建器底栏 `elevation: 2`（`character_editor_page.dart:2186`，悬浮底栏）；
输入框宽度 72/96/104/120/136/160 与元数据标签列 80 为功能性尺寸（建议后续并入尺寸 token，未纳入
本次节奏收敛）；批量导入加载占位高 80 同理。

---

## 附录 A：对比度实测（Flutter SDK material_color_utilities 0.13.0）

6 预设 seed × 亮/暗 × contrastLevel 0/0.5（tonalSpot）共 **312 个角色配对，全部 ≥ 4.5:1**；
默认紫 seed 的 fidelity/expressive/vibrant/neutral 变体另测 14 组，全部达标。最弱值：

| 配对 | 场景 | 比值 |
|---|---|---|
| secondaryContainer / onSecondaryContainer | fidelity 暗色 | 4.55:1 |
| error / onError | 亮色（全部变体） | 6.44–6.46:1 |
| primary / onPrimary | 亮色（全部变体） | 6.44–6.46:1 |
| surfaceContainerHigh / onSurface | 亮色 | 13.9–14.0:1 |

不达标项仅为 E3 的 `outline` 文字色：on surface 4.32:1、on surfaceContainerLow 4.13:1。

## 附录 B：DESIGN.md 草案（可直接落盘为仓库根 `DESIGN.md`）

```markdown
---
name: OhMyDungeon
description: 离线优先 D&D 跑团辅助客户端的 Material 3 设计系统。颜色随用户偏好 seed 动态派生。
colors:
  # 默认 seed（Material 紫 #6750A4, tonalSpot, 亮色）基线角色；实际值由
  # ColorScheme.fromSeed(seed, brightness, contrastLevel, variant) 派生，用户可选
  # 6 个预设 seed 或自定义 hex。以下为契约角色，非固定字面值。
  seed-default: "#6750A4"
  primary: "{colors.seed-default}"
  on-primary: "#FFFFFF"
  secondary: "#625B71"  # 保留角色（当前仅经 secondary-container 使用）
  secondary-container: "#E8DEF8"
  on-secondary-container: "#4A4458"
  tertiary: "#7D5260"
  error: "#BA1A1A"
  on-error: "#FFFFFF"
  error-container: "#FFDAD6"
  on-error-container: "#93000A"
  surface: "#FDF7FF"
  on-surface: "#1D1B20"
  surface-container-low: "#F8F2FA"
  surface-container-high: "#ECE6EE"
  surface-container-highest: "#E6E0E9"
  on-surface-variant: "#49454E"
  outline: "#79747E"
  outline-variant: "#CAC4D0"
  inverse-surface: "#322F35"
  on-inverse-surface: "#F5EFF7"
typography:
  # 全部层级使用 NotoSansSC（Variable），字号为 M3 默认；随用户字体缩放偏好变化。
  display-large: { fontFamily: NotoSansSC, fontSize: 57px, fontWeight: 400, lineHeight: 64px, letterSpacing: -0.25px }
  display-small: { fontFamily: NotoSansSC, fontSize: 36px, fontWeight: 400, lineHeight: 44px }
  headline-large: { fontFamily: NotoSansSC, fontSize: 32px, fontWeight: 400, lineHeight: 40px }
  headline-small: { fontFamily: NotoSansSC, fontSize: 24px, fontWeight: 400, lineHeight: 32px }
  title-large: { fontFamily: NotoSansSC, fontSize: 22px, fontWeight: 400, lineHeight: 28px }
  title-medium: { fontFamily: NotoSansSC, fontSize: 16px, fontWeight: 500, lineHeight: 24px, letterSpacing: 0.15px }
  title-small: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 500, lineHeight: 20px, letterSpacing: 0.1px }
  body-large: { fontFamily: NotoSansSC, fontSize: 16px, fontWeight: 400, lineHeight: 24px, letterSpacing: 0.5px }
  body-medium: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 400, lineHeight: 20px, letterSpacing: 0.25px }
  body-small: { fontFamily: NotoSansSC, fontSize: 12px, fontWeight: 400, lineHeight: 16px, letterSpacing: 0.4px }
  label-large: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 500, lineHeight: 20px, letterSpacing: 0.1px }
  label-medium: { fontFamily: NotoSansSC, fontSize: 12px, fontWeight: 500, lineHeight: 16px, letterSpacing: 0.5px }
  label-small: { fontFamily: NotoSansSC, fontSize: 11px, fontWeight: 500, lineHeight: 16px, letterSpacing: 0.5px }
  mono-code: { fontFamily: monospace, fontSize: 13px, fontWeight: 400 }  # JSON 预览（骰式用 title-medium + mono-family）
  narrator: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 500 }  # 聊天旁白（斜体）
  system-message: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 700 }  # 聊天系统消息
  dice-notation: { fontFamily: NotoSansSC, fontSize: 16px, fontWeight: 700 }  # 掷骰表达式预览
  invite-code: { fontFamily: NotoSansSC, fontSize: 24px, fontWeight: 700, letterSpacing: 2px }  # 邀请码展示
  invite-code-compact: { fontFamily: NotoSansSC, fontSize: 16px, fontWeight: 700, letterSpacing: 1px }  # 邀请码行内
  avatar-initials: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 600 }  # 头像首字母（FittedBox 缩放）
  quote: { fontFamily: NotoSansSC, fontSize: 14px, fontWeight: 400 }  # 引用块（斜体）
rounded:
  sm: 8px      # 组件（卡片/按钮/输入框/chip）
  md: 16px     # 对话框 / 底部弹层
  pill: 24px   # 聊天气泡（唯一有意例外）
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  xxxl: 48px
components:
  button-primary: { backgroundColor: "{colors.primary}", textColor: "{colors.on-primary}", rounded: "{rounded.sm}" }
  button-elevated: { backgroundColor: "{colors.surface-container-high}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}" }
  button-text: { textColor: "{colors.primary}", rounded: "{rounded.sm}" }
  button-outlined: { textColor: "{colors.primary}", rounded: "{rounded.sm}" }
  button-tonal: { backgroundColor: "{colors.secondary-container}", textColor: "{colors.on-secondary-container}", rounded: "{rounded.sm}" }
  chip: { backgroundColor: "{colors.surface-container-high}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}" }
  chip-selected: { backgroundColor: "{colors.secondary-container}", textColor: "{colors.on-secondary-container}", rounded: "{rounded.sm}" }
  card: { backgroundColor: "{colors.surface-container-low}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}", padding: "{spacing.lg}" }
  input-field: { backgroundColor: "{colors.surface-container-high}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}" }
  dialog: { backgroundColor: "{colors.surface-container-high}", rounded: "{rounded.md}" }
  bottom-sheet: { backgroundColor: "{colors.surface-container-high}", rounded: "{rounded.md}" }
  snackbar: { backgroundColor: "{colors.inverse-surface}", textColor: "{colors.on-inverse-surface}", rounded: "{rounded.sm}" }
  search-bar: { backgroundColor: "{colors.surface-container-high}", textColor: "{colors.on-surface}", rounded: "{rounded.sm}" }
  nav-indicator: { backgroundColor: "{colors.secondary-container}" }
  nav-icon-selected: { textColor: "{colors.on-secondary-container}" }
  nav-icon-unselected: { textColor: "{colors.on-surface-variant}" }
  page: { backgroundColor: "{colors.surface}" }
  text-secondary: { textColor: "{colors.on-surface-variant}" }
  badge-status: { backgroundColor: "{colors.error}", textColor: "{colors.on-error}", rounded: "{rounded.sm}" }
  callout-error: { backgroundColor: "{colors.error-container}", textColor: "{colors.on-error-container}", rounded: "{rounded.sm}" }
  avatar-ring-injured: { textColor: "{colors.tertiary}" }
  divider: { backgroundColor: "{colors.outline-variant}" }
  icon-muted: { textColor: "{colors.outline}" }
  composer-pill: { backgroundColor: "{colors.surface-container-highest}", rounded: "{rounded.pill}" }
---

## Overview

OhMyDungeon 是离线优先的 D&D 跑团辅助工具，界面语言是"安静的工具台"：以 Material 3 动态色
（用户可选 6 个预设 seed 或自定义色）为唯一色彩来源，8dp 圆角、零投影的扁平层级、NotoSansSC
中文排版。整体气质克制、信息密度中高，让位于规则文本与角色数据本身。

## Colors

所有颜色由 `ColorScheme.fromSeed` 派生，**禁止硬编码字面颜色**（唯一例外：seed 选择器中的预设
色）。文字必须使用与背景匹配的 `on-*` 角色。`outline` 仅用于描边与图标，不得作为正文文字色。
`secondary` 为保留角色，当前仅经 secondaryContainer 参与组件；`tertiary` 用于头像生命环"受伤"档。

## Typography

统一 NotoSansSC（Variable），层级即 M3 默认 textTheme，随用户字体缩放偏好缩放。正文 14–16px；
标题 22–32px；元数据用 label 系列。代码/骰式用 `mono-code` 13px。不要用固定字号覆盖字体缩放。

## Layout

8px 刻度 + 4px 半步（xs 4 / sm 8 / md 12 / lg 16 / xl 24 / xxl 32 / xxxl 48）。列表底部为 FAB
让位时用 96px 单一常量。区块垂直节奏 24px；卡片内边距 16–24px。

## Elevation & Depth

**扁平化**：所有表面 `elevation: 0`、`surfaceTint: transparent`（含对话框）。层级用色调层
（surfaceContainerLow → High）与 1px outlineVariant 描边表达。唯一浮动元素为 SnackBar。

## Shapes

组件统一 8dp（卡片/按钮/输入框/chip）；对话框与底部弹层 16dp；聊天气泡胶囊 24dp 为唯一例外。
不得混用其他圆角值。

## Components

按钮五态（filled/elevated/text/outlined/tonal）如 token 定义，破坏性操作统一 error 角色。
Chip 选中态必须使用 onSecondaryContainer。输入框一律走 `inputDecorationTheme`（8dp 填充式），
不覆写 border。对话框内容宽度取 token（440/560/760）。所有纯图标控件必须带 Tooltip。

## Do's and Don'ts

- Do 只用 colorScheme 角色取色，文字配 on-* 角色
- Do 保持 4/8px 间距韵律与 8/16dp 圆角契约
- Do 为纯图标控件提供 Tooltip，触达尺寸 ≥ 48dp
- Don't 硬编码颜色、字号或间距
- Don't 覆写 `border: OutlineInputBorder()`（丢失主题 8dp 与聚焦态）
- Don't 在彩色底上使用默认 onSurface 文字
- Don't 引入非零 elevation（对话框、SearchBar 均需显式 0）
```
---

## 附：审查执行记录

- 静态扫描：全量 grep（`Color(0x`/`Colors.`/`TextStyle(`/`BorderRadius`/`SizedBox`/`EdgeInsets`/
  `BoxShadow`/`elevation`），`app_theme.dart` 主题契约核对，Flutter SDK 源码核对默认值
  （SearchBar `search_anchor.dart:1847-1860`、Dialog elevation 回退 `dialog.dart:125-140`）。
- 对比度：`material_color_utilities 0.13.0` 实测（见附录 A）。
- 逐文件审查：9 路并行子代理按统一规则集审查 70 个文件，本报告交叉核验了其中的关键断言
  （`elevation: 2` 底栏、货币箱配色、outline 对比度、对话框默认投影等）。
