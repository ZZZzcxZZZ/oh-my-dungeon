# 统一资料 Schema 与本地自制内容

## 目标

资料库是职业、子职、特性、种族、背景、专长、法术、物品、状态和怪物的统一仓库。内置资料包、用户导入包、本地自制条目与当前战役条目都转换为 `ContentEntry`，使用同一套查询、筛选和详情渲染逻辑。

## 类型边界

顶级类型由客户端固定，不允许资料包任意创建新的顶级分类：

`class`、`subclass`、`classFeature`、`species`、`background`、`feat`、`spell`、`item`、`condition`、`monster`、`custom`。

`equipment` 是 `item` 的兼容类型；`equipmentBundle` 与 `rule` 只保留旧包读取兼容，不作为资料库顶级入口。自定义职业、法术或怪物必须复用对应标准类型。无法归类的叙事资料才使用 `custom`。

## 单一注册表

`ContentSchemaRegistry` 是类型标签、标准字段、筛选字段、字段类型、必填约束和兼容别名的唯一数据源。导入校验、本地创建表单、搜索筛选和详情元数据不得各自维护字段清单。

每个字段定义包含稳定键名、用户可读标签、数据类型、必填约束、筛选能力、旧字段别名，以及可选的枚举值与显示标签。规范化发生在写入前，读取时仍兼容旧资料包。怪物类型只能产生 D&D 官方 14 个大类。

## 本地自制包

每个工作区拥有一个 `local-homebrew` 包。工作区已经按匿名 `local` 或 `serverInstanceId + userId` 隔离，因此固定包 ID 不会造成账号串数据。

本地创建器通过 `LocalHomebrewContentService` 写入该包：

1. 根据注册表验证类型与字段；
2. 规范化 `structured` 数据；
3. 生成稳定 slug 与条目 ID；
4. 以单条 upsert 更新包，不整体替换包，不破坏其他条目的收藏和笔记；
5. 通知资料库刷新。

资料包导入保持只读替换语义；用户若要修改导入条目，应复制到 `local-homebrew` 后编辑。

## 公共操作边界

界面、批量导入器、未来资料包制作器与 Agent 工具不得直接写 Drift 表。读取统一经过
`ContentRepository`，用户自制内容的修改统一经过
`LocalHomebrewContentService`：

```text
search(ContentQuery) -> List<ContentEntry>
getByKey(entryKey) -> ContentEntry?
create(type, name, summary, description, structured, tags) -> ContentEntry
update(existing, name, summary, description, structured, tags) -> ContentEntry
delete(entry) -> void
```

`ContentSchemaRegistry.validateForCreation` 在写入前负责类型、必填字段、字段数据类型、
数值范围和枚举值校验。未知扩展字段会被保留，便于扩展包增加规则数据；未知顶级类型
则归入 `custom`，不会污染固定分类导航。

## 数据流

```text
内置包 / 文件导入 / 本地创建 / 战役同步
                    ↓
              ContentEntry
                    ↓
         ContentSchemaRegistry 规范化
                    ↓
       CampaignAwareContentRepository
                    ↓
      搜索、筛选、详情、角色规则与 AI 工具
```

## 首轮范围

本轮实现固定类型注册表、数据驱动筛选、类型级校验和本地自制包的
创建/编辑/删除底层接口。自制内容 GUI、任意类型插件、复杂富文本编辑器与完整
资料包制作器均暂不向用户开放，待交互流程完整设计后再接入。
