import 'package:flutter/material.dart';
import '../services/data_port_service.dart';

/// 数据导入导出界面
class DataPortScreen extends StatefulWidget {
  const DataPortScreen({super.key});

  @override
  State<DataPortScreen> createState() => _DataPortScreenState();
}

class _DataPortScreenState extends State<DataPortScreen> {
  final DataPortService _dataPortService = DataPortService();
  DatabaseStats? _stats;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _dataPortService.getDatabaseStats();
    setState(() {
      _stats = stats;
    });
  }

  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _dataPortService.shareExportData();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showResultDialog(
          title: result.success ? '导出成功' : '导出失败',
          message: result.message,
          isSuccess: result.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showResultDialog(
          title: '导出失败',
          message: '发生错误：$e',
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      print('🔍 [UI-DEBUG] 开始导入数据流程...');
      
      // 直接调用文件选择，不显示加载状态（避免MacOS下的冲突）
      print('🔍 [UI-DEBUG] 调用 _dataPortService.importDataFromFile()...');
      final result = await _dataPortService.importDataFromFile();
      
      print('🔍 [UI-DEBUG] 导入结果 - 成功: ${result.success}, 消息: ${result.message}');
      
      if (mounted) {
        // 只有在实际处理文件时才显示加载状态
        if (result.success || result.message.contains('正在处理')) {
          print('🔍 [UI-DEBUG] 显示加载状态...');
          setState(() {
            _isLoading = true;
          });
          
          // 给一点时间显示加载状态
          await Future.delayed(const Duration(milliseconds: 500));
          
          setState(() {
            _isLoading = false;
          });
        }

        print('🔍 [UI-DEBUG] 显示结果对话框...');
        _showResultDialog(
          title: result.success ? '导入成功' : '导入失败',
          message: result.message,
          isSuccess: result.success,
        );

        if (result.success) {
          print('🔍 [UI-DEBUG] 重新加载统计信息...');
          // 重新加载统计信息
          _loadStats();
        }
      }
    } catch (e, stackTrace) {
      print('🔍 [UI-DEBUG] 导入过程发生异常: $e');
      print('🔍 [UI-DEBUG] 堆栈跟踪: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showResultDialog(
          title: '导入失败',
          message: '发生错误：$e\n\n请确保：\n1. 已授权应用访问文件\n2. 选择的是有效的JSON文件\n3. 文件格式正确',
          isSuccess: false,
        );
      }
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showImportWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('导入确认'),
          ],
        ),
        content: const Text(
          '导入操作将会添加新的词语和意项到现有词库中。\n\n'
          '• 重复的词语和意项将被跳过\n'
          '• 新的词语和意项将被添加\n'
          '• 现有数据不会被删除\n\n'
          '点击"确认导入"后将打开文件选择器。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              print('🔍 [UI-DEBUG] 用户点击了确认导入按钮');
              Navigator.of(context).pop();
              print('🔍 [UI-DEBUG] 对话框已关闭，等待300ms...');
              // 添加小延迟确保对话框完全关闭后再执行文件选择
              await Future.delayed(const Duration(milliseconds: 300));
              print('🔍 [UI-DEBUG] 延迟完成，开始调用_importData()');
              _importData();
            },
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 当前数据统计
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前词库统计',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_stats != null) ...[
                      _buildStatRow('词语数量', '${_stats!.totalWords} 个'),
                      _buildStatRow('意项数量', '${_stats!.totalMeanings} 个'),
                      _buildStatRow('关联关系', '${_stats!.totalRelations} 个'),
                    ] else ...[
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // 导出功能
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.upload, size: 24, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          '导出词库',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '将当前词库导出为JSON文件，可用于备份或分享给其他设备。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _exportData,
                        icon: const Icon(Icons.file_download),
                        label: const Text('导出词库'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 导入功能
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.download, size: 24, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          '导入词库',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '从JSON文件导入词库数据。重复的词语和意项将被跳过，新的内容将被添加到现有词库中。',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showImportWarningDialog,
                        icon: const Icon(Icons.file_upload),
                        label: const Text('导入词库'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 说明信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          '使用说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 导出的文件包含完整的词语、意项和关联关系\n'
                      '• 支持跨设备数据迁移和备份恢复\n'
                      '• 导入时会智能处理重复数据，避免冲突\n'
                      '• 建议定期导出数据进行备份',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在处理，请稍候...'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}