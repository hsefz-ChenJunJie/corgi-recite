import 'package:flutter/material.dart';
import '../models/word_item.dart';
import '../database/database_helper.dart';
import '../config/app_config.dart';
import 'confirm_words_screen.dart';

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

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  Future<void> _saveWords() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final lines = _batchController.text.split('\n').where((line) => line.trim().isNotEmpty).toList();
        final wordsToSave = lines.where((line) => line.contains('=')).toList();
        
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

        // 使用新的多对多系统保存
        final addedIds = await _dbHelper.addWordMeaningPairs(wordsToSave);
        
        // 获取新添加的配对
        final allPairs = await _dbHelper.getAllWordMeaningPairs();
        final newPairs = allPairs.take(addedIds.length).toList();
        
        // 为了向后兼容，也创建WordItem列表
        final savedItems = newPairs.map((pair) => WordItem(
          word: pair.wordText,
          meaning: pair.meaningText,
          createdAt: pair.createdAt,
          updatedAt: pair.updatedAt,
        )).toList();

        if (mounted) {
          // 导航到确认页面
          final result = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (context) => ConfirmWordsScreen(
                wordItems: savedItems,
                wordMeaningPairs: newPairs,
              ),
            ),
          );

          if (result == true && mounted) {
            // 用户选择开始背诵，返回新保存的词语列表，让主屏幕处理后续导航
            Navigator.pop(context, savedItems);
          } else if (result == 'cancel' && mounted) {
            // 用户取消添加，删除刚才保存的数据
            try {
              await _dbHelper.deleteWordMeaningPairs(newPairs);
              setState(() {
                _isLoading = false;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已取消添加')),
                );
              }
            } catch (e) {
              setState(() {
                _isLoading = false;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('取消操作失败: $e')),
                );
              }
            }
          } else {
            // 其他情况（如系统返回），保持在当前页面
            setState(() {
              _isLoading = false;
            });
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
                    SizedBox(height: 8),
                    Text('注意：系统会自动处理重复的词语和意项，建立多对多关系'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextFormField(
                  controller: _batchController,
                  decoration: const InputDecoration(
                    labelText: '批量输入词语',
                    hintText: '请按照格式输入多个词语...\n例如：\napple=苹果\nbook=书籍\ncomputer=计算机',
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
                onPressed: _isLoading ? null : _saveWords,
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