# 0.1 角色呈现壳层重构实施计划

## 任务 1：提取角色卡响应式壳层

- [x] 为 390px TabBar、1280px NavigationRail、初始目标和内容切换编写失败测试。
- [x] 实现 `character_sheet_shell.dart`。
- [x] 将 `CharacterDetailPage` 改为声明 destinations 并交给壳层组装。
- [x] 运行 `character_pages_test.dart`。

## 任务 2：提取创建向导响应式壳层

- [ ] 为手机步骤选择、桌面 NavigationRail 和动作区编写失败测试。
- [ ] 实现 `character_builder_shell.dart`。
- [ ] 用壳层替换 `_StandardBuildPageState` 中的响应式 Scaffold 代码。
- [ ] 删除旧 `_MobileBuilderStepSelector`，保持规则状态与摘要逻辑不变。
- [ ] 运行标准创建与规则驱动测试。

## 任务 3：收口与验证

- [ ] 检查两份业务页面中的重复壳层代码与未使用 import。
- [ ] 更新执行状态文档。
- [ ] 运行 `flutter analyze`、`flutter test`、`flutter build web --release` 和 `npm run doctor`。
- [ ] 提交角色壳层重构。

## 后续边界

壳层稳定后，下一计划处理角色卡具体信息密度和创建步骤内容；其后再建立全局 Material 3 统一计划。
