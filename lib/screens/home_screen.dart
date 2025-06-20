import 'package:flutter/material.dart';
import '../models/word_item.dart';
import '../database/database_helper.dart';
import 'add_word_screen.dart';
import 'recite_screen.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<WordItem> _wordItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWordItems();
  }

  Future<void> _loadWordItems() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final wordItems = await _dbHelper.getAllWordItems();
      setState(() {
        _wordItems = wordItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteWordItem(int id) async {
    try {
      await _dbHelper.deleteWordItem(id);
      await _loadWordItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('词语已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corgi Recite'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _wordItems.isNotEmpty
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReciteScreen(
                                        wordItems: _wordItems,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.school),
                          label: const Text('开始背诵'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _wordItems.isNotEmpty
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => QuizScreen(
                                        wordItems: _wordItems,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.quiz),
                          label: const Text('随机抽查'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _wordItems.isEmpty
                      ? const Center(
                          child: Text(
                            '还没有词语\n点击右下角按钮添加',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _wordItems.length,
                          itemBuilder: (context, index) {
                            final wordItem = _wordItems[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                title: Text(
                                  wordItem.word,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(wordItem.meaning),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('确认删除'),
                                        content: Text('确定要删除词语"${wordItem.word}"吗？'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteWordItem(wordItem.id!);
                                            },
                                            child: const Text('删除'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddWordScreen(),
            ),
          );
          if (result == true) {
            _loadWordItems();
          }
        },
        tooltip: '添加词语',
        child: const Icon(Icons.add),
      ),
    );
  }
}