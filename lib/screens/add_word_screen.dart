import 'package:flutter/material.dart';
import '../models/word_item.dart';
import '../database/database_helper.dart';
import '../config/app_config.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;
  bool _isBatchMode = false;

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  List<WordItem> _parseBatchInput(String input) {
    final lines = input.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final wordItems = <WordItem>[];
    final now = DateTime.now();

    for (final line in lines) {
      final parts = line.split('=');
      if (parts.length == 2) {
        final word = parts[0].trim();
        final meaning = parts[1].trim();
        if (word.isNotEmpty && meaning.isNotEmpty) {
          wordItems.add(WordItem(
            word: word,
            meaning: meaning,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }
    }

    return wordItems;
  }

  Future<void> _saveWords() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        List<WordItem> wordsToSave;
        
        if (_isBatchMode) {
          wordsToSave = _parseBatchInput(_batchController.text);
          if (wordsToSave.isEmpty) {
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入有效的词语格式：词语=意项')),
              );
            }
            return;
          }
        } else {
          return; // 单个模式已移除
        }

        final savedItems = <WordItem>[];
        for (final wordItem in wordsToSave) {
          final id = await _dbHelper.insertWordItem(wordItem);
          savedItems.add(wordItem.copyWith(id: id));
        }

        if (mounted) {
          final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('添加成功'),
              content: Text('已成功添加${savedItems.length}个词语！\n现在开始背诵这些词语。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('稍后'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('开始背诵'),
                ),
              ],
            ),
          );

          if (confirmed == true && mounted) {
            // 返回新保存的词语列表，让主屏幕处理后续导航
            Navigator.pop(context, savedItems);
          } else {
            // 用户点击了“稍后”或关闭了对话框，仅返回true以刷新主页
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('批量添加词语'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: AppConfig.showBackButtonInAddPage,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '格式说明：',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('每行一个词语，格式为：词语=意项'),
                    Text('例如：'),
                    Text('apple=苹果'),
                    Text('book=书籍'),
                    Text('computer=计算机'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextFormField(
                  controller: _batchController,
                  decoration: const InputDecoration(
                    labelText: '批量输入词语',
                    hintText: '请按照格式输入多个词语...\n例如：\napple=苹果\nbook=书籍',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入词语';
                    }
                    final lines = value.split('\n').where((line) => line.trim().isNotEmpty).toList();
                    bool hasValidFormat = false;
                    for (final line in lines) {
                      final parts = line.split('=');
                      if (parts.length == 2 && parts[0].trim().isNotEmpty && parts[1].trim().isNotEmpty) {
                        hasValidFormat = true;
                        break;
                      }
                    }
                    if (!hasValidFormat) {
                      return '请按照格式输入：词语=意项';
                    }
                    return null;
                  },
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _isBatchMode = true;
                  });
                  _saveWords();
                },
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('批量保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}