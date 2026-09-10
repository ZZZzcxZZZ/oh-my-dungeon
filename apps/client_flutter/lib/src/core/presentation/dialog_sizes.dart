/// 对话框内容尺寸 token（DESIGN.md「Components」章节约定）。
///
/// 按用途命名而非数值，避免各对话框自选魔数（此前 420/440/480×420/
/// 560×620/760×720/960 散布在多个文件中）。页面级最大宽度（设置页
/// 760、资料库 960 等）不属于对话框，仍由各页面自行声明。
abstract final class DialogSizes {
  /// 单/双输入框的轻量表单对话框（如自定义动作、资源编辑）。
  static const double form = 420;

  /// 带选项列表/多字段的窄对话框（如状态选择）。
  static const double narrow = 440;

  /// 带搜索列表的拾取器对话框（如选择物品）。
  static const double compact = 480;

  /// 多步向导对话框（如创建战役引导）。
  static const double standard = 560;

  /// 详情阅读对话框（如档案详情、规则长文）。
  static const double wide = 760;

  /// 全宽内容阅读对话框（如资料条目详情）。
  static const double full = 960;

  /// 拾取器对话框内容高度：420 归位到 8px 节奏（52×8 = 416）。
  static const double pickerHeight = 416;

  /// 多步向导内容高度上限。
  static const double guideHeight = 620;

  /// 详情阅读对话框内容高度上限。
  static const double detailHeight = 720;
}
