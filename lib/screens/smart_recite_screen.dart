import 'package:flutter/material.dart';
import '../services/recite_service.dart';
import '../models/word_item.dart';
import '../config/app_config.dart';
import 'smart_quiz_screen.dart';

class SmartReciteScreen extends StatefulWidget {
  final List<WordItem> wordItems;
  final ReciteItem? startFromItem;

  const SmartReciteScreen({
    super.key,
    required this.wordItems,
    this.startFromItem,
  });

  @override
  State<SmartReciteScreen> createState() => _SmartReciteScreenState();
}

class _SmartReciteScreenState extends State<SmartReciteScreen> {
  final ReciteService _reciteService = ReciteService();
  final PageController _pageController = PageController();
  
  List<ReciteItem> _reciteItems = [];
  int _currentIndex = 0;
  bool _showMeanings = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReciteItems();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReciteItems() async {
    try {
      final items = await _reciteService.getReciteItemsFromDatabase(widget.wordItems);
      setState(() {
        _reciteItems = items;
        _isLoading = false;
      });

      // 如果指定了起始项目，跳转到该项目
      if (widget.startFromItem != null) {
        final startIndex = _reciteItems.indexWhere(
          (item) => item.word == widget.startFromItem!.word,
        );
        if (startIndex != -1) {
          setState(() {
            _currentIndex = startIndex;
          });
          _pageController.animateToPage(
            startIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载背诵内容失败: $e')),
        );
      }
    }
  }

  void _toggleMeanings() {
    setState(() {
      _showMeanings = !_showMeanings;
    });
  }

  void _nextWord() {
    if (_currentIndex < _reciteItems.length - 1) {
      setState(() {
        _currentIndex++;
        _showMeanings = false;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishReciting();
    }
  }

  void _previousWord() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showMeanings = false;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishReciting() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('背诵完成'),
        content: Text('已完成${_reciteItems.length}个词语的背诵！\n现在开始双向测试。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startQuiz();
            },
            child: const Text('开始测试'),
          ),
        ],
      ),
    );
  }

  void _startQuiz() {
    // 转换为WordItem列表进行双向测试
    final allWordItems = <WordItem>[];
    for (final reciteItem in _reciteItems) {
      for (final meaning in reciteItem.meanings) {
        allWordItems.add(WordItem(
          word: reciteItem.word,
          meaning: meaning,
          createdAt: reciteItem.createdAt,
          updatedAt: reciteItem.createdAt,
        ));
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SmartQuizScreen(
          quizCount: allWordItems.length,
          wordItems: allWordItems,
          isBidirectionalQuiz: true, // 启用双向测试模式
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('智能背诵'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_reciteItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('智能背诵'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Text('没有可背诵的内容'),
        ),
      );
    }

    final progress = (_currentIndex + 1) / _reciteItems.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('智能背诵 (${_currentIndex + 1}/${_reciteItems.length})'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: AppConfig.showBackButtonInLearningFlow 
            ? null 
            : Container(),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _reciteItems.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _showMeanings = false;
                });
              },
              itemBuilder: (context, index) {
                final item = _reciteItems[index];
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Card(
                        elevation: 8,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.word,
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (item.hasMultipleMeanings) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '(${item.meaningCount}个意思)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: _showMeanings ? null : 0,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 300),
                                  opacity: _showMeanings ? 1.0 : 0.0,
                                  child: _showMeanings
                                      ? Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue[200]!),
                                          ),
                                          child: Text(
                                            item.meaningsText,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              height: 1.5,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _currentIndex > 0 ? _previousWord : null,
                            child: const Text('上一个'),
                          ),
                          ElevatedButton(
                            onPressed: _toggleMeanings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _showMeanings ? Colors.grey : null,
                            ),
                            child: Text(_showMeanings ? '隐藏意思' : '显示意思'),
                          ),
                          ElevatedButton(
                            onPressed: _nextWord,
                            child: Text(_currentIndex < _reciteItems.length - 1 ? '下一个' : '完成'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}