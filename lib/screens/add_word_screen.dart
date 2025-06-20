import 'package:flutter/material.dart';
import '../models/word_item.dart';
import '../database/database_helper.dart';
import 'recite_screen.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _meaningController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  Future<void> _saveWord() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final now = DateTime.now();
        final wordItem = WordItem(
          word: _wordController.text.trim(),
          meaning: _meaningController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );

        final id = await _dbHelper.insertWordItem(wordItem);
        final savedItem = wordItem.copyWith(id: id);

        if (mounted) {
          Navigator.pop(context, true);
          
          if (mounted) {
            final shouldStartRecite = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('添加成功'),
                content: const Text('词语已添加，是否立即开始背诵？'),
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

            if (shouldStartRecite == true) {
              final allWords = await _dbHelper.getAllWordItems();
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReciteScreen(
                      wordItems: allWords,
                      startFromWord: savedItem,
                    ),
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加词语'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _wordController,
                decoration: const InputDecoration(
                  labelText: '词语',
                  hintText: '请输入要背诵的词语',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入词语';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _meaningController,
                decoration: const InputDecoration(
                  labelText: '意项',
                  hintText: '请输入词语的意思',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入意项';
                  }
                  return null;
                },
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveWord(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveWord,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}