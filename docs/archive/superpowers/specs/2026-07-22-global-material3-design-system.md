# 0.1 全局 Material 3 视觉系统设计

## 目标

保留用户 seed color 与亮/暗模式，在应用级 ThemeData 中建立一致的 Material 3 组件规范，消除页面各自定义颜色、圆角、间距和控件状态。

## 主题架构

- 新增 `AppTheme`，继续使用 `ColorScheme.fromSeed` 生成标准 tonal palette。
- 用户主题色只作为 seed，不直接充当任意背景色；语义颜色统一取自 ColorScheme roles。
- 统一 AppBar、NavigationBar、NavigationRail、TabBar、Card、ListTile、InputDecoration、Dialog、BottomSheet、Chip 和按钮主题。
- 卡片圆角不超过 8px；页面区块保持无框，卡片只用于独立重复项和工具。
- 触控目标保持至少 48px，图标按钮提供 Tooltip 和 Semantics。

## 迁移顺序

1. 应用壳层与导航。
2. 设置与服务器页面。
3. 资料库。
4. 战役与聊天。
5. 角色卡与创建向导。

每个切片只删除该区域的硬编码视觉值，不同时重写业务逻辑。

## 验收

- 任意 seed color 的亮暗主题均保持可读对比度。
- 相同控件在不同功能区具有一致尺寸、圆角、状态和间距。
- 360、390、600、900、1280 宽度无溢出或文字遮挡。
- golden/widget 测试覆盖主题角色和关键组件状态。

