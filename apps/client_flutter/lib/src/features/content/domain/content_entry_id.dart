/// 条目 id 的**传输前缀**归一化（唯一实现）。
///
/// `CampaignAwareContentRepository` 会把条目 id 重写成 `local:<id>`（本地资料）与
/// `campaign:<campaignId>:<id>`（战役缓存），而**用户的覆盖选择**
/// （`data.ruleOverrides` 的 `disabledOriginIds` / `pinned`）与规则声明的 `originId`
/// 都会带上同一个前缀。同一个角色在"本地角色列表"与"战役角色卡"两个入口打开时
/// 用的是**同一份角色数据**，所以覆盖选择必须按**规范 id** 比较与持久化，否则
/// 在战役视图里关掉的来源回到本地视图就不再生效（S3 已知限制）。
///
/// 规则（只剥传输前缀，不碰包 id 本身）：
/// - `local:<id>` → `<id>`；
/// - `campaign:<campaignId>:<id>` → `<id>`（注意包 id 允许含 `:`，所以只剥到第二个
///   冒号为止：`campaign:c1:errata:class/wizard` → `errata:class/wizard`）；
/// - 其它一律原样返回（`<entry>` 这类占位符、已经是规范 id 的值都不受影响）。
String canonicalContentEntryId(String id) {
  final value = id.trim();
  const localPrefix = 'local:';
  const campaignPrefix = 'campaign:';
  if (value.startsWith(localPrefix)) {
    return value.substring(localPrefix.length);
  }
  if (value.startsWith(campaignPrefix)) {
    final rest = value.substring(campaignPrefix.length);
    final split = rest.indexOf(':');
    if (split > 0) return rest.substring(split + 1);
  }
  return value;
}
