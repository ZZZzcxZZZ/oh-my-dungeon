# 正式自动登录设计

## 目标

删除通过编译参数注入账号密码的 Debug 自动登录，提供所有构建都可使用的正式自动登录能力。

## 行为

- 登录页显示 Material 3「自动登录」开关，按服务器 profile 独立保存，默认开启。
- 开启时，登录或注册成功后持久化 access token 与 refresh token。
- 应用启动时先使用 access token 获取当前用户；access token 失效时使用 refresh token 换取新 access token，再恢复用户会话。
- 关闭时立即删除该服务器已持久化的 token，但不结束当前内存会话；之后的登录只在本次应用运行期间有效。
- 退出登录始终撤销 refresh token、清除本地 token 和当前内存会话。
- 不保存用户名或密码，不增加匿名认证或服务端后门。

## 错误处理

- access token 与 refresh token 均被服务端拒绝时，清除持久化 token 并显示登录页。
- 网络或服务端临时异常不删除 refresh token，避免一次离线启动永久退出账号。
- 自动登录失败不阻止离线角色、资料库和设置功能。

## 数据边界

`AuthTokenStore` 同时保存每个服务器的 token 与 `autoLoginEnabled` 偏好。自动登录偏好默认 `true`；关闭时由 `AuthController` 清除持久 token。

## 验证

- token store 测试覆盖默认值、按服务器隔离和跨实例持久化。
- controller 测试覆盖 access token 直接恢复、401 后 refresh 恢复、refresh 失效清理、关闭后不持久化。
- widget 测试覆盖登录页开关默认状态和切换行为。
