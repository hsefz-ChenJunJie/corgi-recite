class AppConfig {
  // 版本控制：true为测试版（显示返回按钮），false为正式版（隐藏返回按钮）
  static const bool isDebugVersion = false;
  
  // 在学习流程中是否显示返回按钮（背诵和测试页面）
  static bool get showBackButtonInLearningFlow => isDebugVersion;
  
  // 在测试页面是否显示返回按钮
  static bool get showBackButtonInQuiz => isDebugVersion;
  
  // 在添加页面始终显示返回按钮
  static bool get showBackButtonInAddPage => true;
  
  // 版本信息
  static String get versionName => isDebugVersion ? 'Debug' : 'Release';
  
  // 应用标题
  static String get appTitle => isDebugVersion ? 'Corgi Recite (Debug)' : 'Corgi Recite';
}