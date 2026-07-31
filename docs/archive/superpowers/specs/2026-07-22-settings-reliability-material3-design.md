# 0.1 设置可靠性与 Material 3 设置页设计

## 目标

让所有可见设置在应用重启后可靠保留，并把服务器、账号、自动登录、同步状态等在线能力集中为一个清晰区域。设置页继续保持离线可用，并使用 Material 3 的标准列表、分段按钮、开关、对话框和颜色角色。

## 已确认问题

- `ClientModeController` 仅保存在内存中，重启后总是回到 Player。
- `SharedPreferencesAppPreferencesStore.save()` 连续写入多个键但忽略布尔返回值，写入失败无法反馈。
- 默认骰子的 `TextEditingController` 在每次 build 时创建，既不稳定也没有 dispose。
- 主题虽然已经用 `ColorScheme.fromSeed()` 生成，但设置页只有固定 `ChoiceChip`，没有自定义 seed color。
- 全局 `ThemeData` 只有裸 `ColorScheme`，各功能区继续自行设置卡片、输入框、底部弹层和导航样式。
- 服务器、账号、同步、Vault 分散在页面后半段，用户无法快速判断当前在线状态。
- Vault 下载的 `preferences` 仍是 no-op；本阶段只保证本机设置可靠，不伪装跨设备偏好同步已经完成。

## 信息架构

设置页按以下顺序排列：

1. **在线服务**：当前服务器、账号/登录、自动登录、同步状态、Vault 入口。
2. **使用模式**：Player/DM 本机偏好，并明确战役权限仍由服务端 membership 决定。
3. **外观**：系统/浅色/深色、主题色、自定义颜色、高对比度。
4. **规则与角色**：默认创建方式、默认角色卡标签、跑团偏好。
5. **资料与本地数据**：资料包、备份恢复、缓存和索引维护。
6. **高级**：仅放真实存在且用户能够理解的诊断选项。

页面使用单一最大阅读宽度。区块不再各自套装饰性卡片；每个区块由标题和连续 `ListTile` 组成，必要时使用一个低强调容器承载整组设置。

## 持久化边界

- `AppPreferencesStore` 继续负责主题、规则、角色卡和跑团偏好。
- `ClientModeStore` 专门负责 Player/DM 本机偏好，`ClientModeController.initialize()` 在主壳显示前恢复。
- 每次更改立即保存。保存失败时保留旧值并通过设置页 `SnackBar` 提示，不能只在内存中显示成功。
- Web 使用 `shared_preferences` 的 Local Storage 实现；Android/桌面沿用插件对应实现。
- 服务器 Profile 和认证 Token 保持现有存储边界，不迁入 AppPreferences。
- 本阶段不把 UI 偏好上传到战役服务器；Vault 偏好接收另列为后续同步任务。

## 主题与自主选色

- 新增 `AppTheme`，统一从 `ColorScheme.fromSeed()` 生成亮暗主题。
- seed color 只用于生成色板，页面不得把 seed color 直接当背景色。
- 主题色设置入口使用 `ListTile` 显示当前色板预览；点击打开 Material 3 对话框。
- 对话框提供常用色板、色相/饱和度/明度滑杆和十六进制输入。使用 Flutter 官方 Material 控件实现，不引入完整第三方主题框架。
- 输入的颜色必须规范为不透明 ARGB；非法十六进制值在输入框中显示错误，不修改当前主题。
- 颜色变化先在对话框内预览，点击“应用”才持久化，取消不改变主题。
- `AppTheme` 统一 AppBar、NavigationBar、NavigationRail、Card、ListTile、InputDecoration、Dialog、BottomSheet、Chip 和按钮主题。

## 响应式与无障碍

- 360/390px 使用单列，分段按钮允许换行或缩为图标加短标签。
- 600px 以上限制内容宽度，不把设置项拉满桌面。
- 所有开关整行可点击，颜色选项提供文本名称和选中状态，不能只依赖色觉。
- 交互目标至少 48px；自定义颜色对话框支持键盘输入和屏幕阅读器标签。

## 非目标

- 不在本阶段实现账号资料编辑、服务器管理后台或公开主题市场。
- 不实现系统壁纸动态取色；后续可在 Android 单独接入 dynamic color。
- 不承诺设置跨设备同步，直到 Vault preferences 的下载应用与冲突策略完成。

## 验收

1. Player/DM、主题模式、seed color 和所有可见偏好在应用重启后保持。
2. 任意一次本地写入失败都会回滚 UI 并显示错误。
3. 自定义 seed color 可通过滑杆或十六进制输入完成，并正确生成亮暗 ColorScheme。
4. 在线服务集中显示服务器、账号和同步状态；离线时不影响本地设置。
5. 360、390、600、900 和 1280px 无溢出、嵌套卡片或不可点击的狭小控件。

