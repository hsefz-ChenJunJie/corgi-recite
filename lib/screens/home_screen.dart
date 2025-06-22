import 'package:flutter/material.dart';
import '../models/word_item.dart';
import '../models/word_meaning_pair.dart';
import '../database/database_helper.dart';
import '../config/app_config.dart';
import 'add_word_screen.dart';
import 'quiz_screen.dart';
import 'recite_screen.dart';
import 'smart_quiz_screen.dart';
import 'smart_recite_screen.dart';
import 'search_quiz_screen.dart';
import 'data_port_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<WordItem> _wordItems = [];
  List<WordMeaningPair> _wordMeaningPairs = [];
  bool _isLoading = true;
  final bool _useNewSystem = true; // 是否使用新的多对多系统

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
      if (_useNewSystem) {
        final wordMeaningPairs = await _dbHelper.getAllWordMeaningPairs();
        setState(() {
          _wordMeaningPairs = wordMeaningPairs;
          _isLoading = false;
        });
      } else {
        final wordItems = await _dbHelper.getAllWordItems();
        setState(() {
          _wordItems = wordItems;
          _isLoading = false;
        });
      }
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

  void _showQuizOptionsDialog() {
    final TextEditingController countController = TextEditingController();
    final int totalCount = _useNewSystem ? _wordMeaningPairs.length : _wordItems.length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('随机抽查设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前共有 $totalCount 个词语-意项配对'),
            const SizedBox(height: 16),
            TextField(
              controller: countController,
              decoration: InputDecoration(
                labelText: '抽查数量',
                hintText: '请输入1-$totalCount',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    countController.text = '5';
                  },
                  child: const Text('5个'),
                ),
                TextButton(
                  onPressed: () {
                    countController.text = '10';
                  },
                  child: const Text('10个'),
                ),
                TextButton(
                  onPressed: () {
                    countController.text = '$totalCount';
                  },
                  child: const Text('全部'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              countController.dispose();
              Navigator.pop(context);
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final count = int.tryParse(countController.text);
              if (count != null && count > 0 && count <= totalCount) {
                countController.dispose();
                Navigator.pop(context);
                _startQuiz(count);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入1-$totalCount之间的数字')),
                );
              }
            },
            child: const Text('开始抽查'),
          ),
        ],
      ),
    );
  }

  void _startQuiz(int count) {
    if (_useNewSystem) {
      // 使用新的智能抽查系统
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SmartQuizScreen(
            quizCount: count,
          ),
        ),
      );
    } else {
      // 使用传统的抽查系统
      final quizItems = count >= _wordItems.length 
          ? _wordItems 
          : (_wordItems..shuffle()).take(count).toList();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            wordItems: quizItems,
            isRandomQuiz: true,
          ),
        ),
      );
    }
  }

  Future<void> _navigateToAddWordScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddWordScreen(),
      ),
    );

    if (result is List<WordItem>) {
      // 用户选择背诵，导航到智能背诵页面
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _useNewSystem 
                ? SmartReciteScreen(wordItems: result)
                : ReciteScreen(
                    wordItems: result,
                    startFromWord: result.first,
                  ),
          ),
        );
        // 背诵完成后刷新主页
        _loadWordItems();
      }
    } else if (result == true) {
      // 用户选择稍后背诵或添加失败，仅刷新列表
      _loadWordItems();
    }
  }

  void _navigateToSearchQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchQuizScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corgi Recite'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DataPortScreen(),
                ),
              ).then((_) => _loadWordItems()); // 返回时刷新数据
            },
            icon: const Icon(Icons.settings),
            tooltip: '数据管理',
          ),
        ],
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
                          onPressed: (_useNewSystem ? _wordMeaningPairs.isNotEmpty : _wordItems.isNotEmpty)
                              ? () => _showQuizOptionsDialog()
                              : null,
                          icon: const Icon(Icons.quiz),
                          label: const Text('随机抽查'),
                        ),
                      ),
                      if (AppConfig.isDebugVersion && (_useNewSystem ? _wordMeaningPairs.isNotEmpty : _wordItems.isNotEmpty)) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToSearchQuiz(),
                            icon: const Icon(Icons.search),
                            label: const Text('指定抽查'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: (_useNewSystem ? _wordMeaningPairs.isEmpty : _wordItems.isEmpty)
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
                          itemCount: _useNewSystem ? _wordMeaningPairs.length : _wordItems.length,
                          itemBuilder: (context, index) {
                            if (_useNewSystem) {
                              final pair = _wordMeaningPairs[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  title: Text(
                                    pair.wordText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(pair.meaningText),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('确认删除'),
                                          content: Text('确定要删除词语"${pair.wordText}"吗？'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('取消'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                // TODO: 实现删除多对多关系的逻辑
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('多对多删除功能待实现')),
                                                );
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
                            } else {
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
                            }
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddWordScreen,
        tooltip: '添加词语',
        child: const Icon(Icons.add),
      ),
    );
  }
}