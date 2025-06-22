# 版本发布说明

## 如何切换到正式版

要发布正式版本，请按照以下步骤操作：

### 1. 修改版本配置
编辑 `lib/config/app_config.dart` 文件：

```dart
class AppConfig {
  // 将此值改为 false 来发布正式版
  static const bool isDebugVersion = false; // 修改这里：true -> false
  
  // 其他配置保持不变...
}
```

### 2. 版本差异说明

#### 测试版 (isDebugVersion = true)
- 应用标题显示为 "Corgi Recite (Debug)"
- 背诵和测试界面显示返回按钮（方便测试）
- 添加词语界面显示返回按钮

#### 正式版 (isDebugVersion = false)
- 应用标题显示为 "Corgi Recite"
- **背诵和测试界面不显示返回按钮，强制用户完成学习流程**
- 添加词语界面仍然显示返回按钮

### 3. 构建正式版
修改配置后，运行以下命令构建正式版：

```bash
# macOS版本
flutter build macos --release

# Android版本
flutter build apk --release

# iOS版本
flutter build ios --release
```

### 4. 学习流程控制

正式版确保用户必须完成以下完整流程：
1. 添加词语 → 强制背诵 → 强制双向测试 → 回到主界面
2. 双向测试中答错 → 立即背诵错词 → 继续测试
3. 随机抽查答错 → 完成所有题目后强制背诵错词

用户无法在学习过程中退出到主界面，确保学习效果。