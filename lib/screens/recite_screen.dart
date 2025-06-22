import 'package:flutter/material.dart';
import '../models/word_item.dart';
import '../config/app_config.dart';
import 'quiz_screen.dart';

class ReciteScreen extends StatefulWidget {
  final List<WordItem> wordItems;
  final WordItem? startFromWord;
  final Map<String, dynamic>? savedQuizProgress;
  final bool isImmediateReview; // 是否是立即复习模式（来自测试中的错误处理）

  const ReciteScreen({
    super.key,
    required this.wordItems,
    this.startFromWord,
    this.savedQuizProgress,
    this.isImmediateReview = false,
  });

  @override
  State<ReciteScreen> createState() => _ReciteScreenState();
}

class _ReciteScreenState extends State<ReciteScreen> {
  int _currentIndex = 0;
  bool _showMeaning = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    if (widget.startFromWord != null) {
      _currentIndex = widget.wordItems.indexWhere(
        (item) => item.id == widget.startFromWord!.id,
      );
      if (_currentIndex == -1) _currentIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextWord() {
    if (_currentIndex < widget.wordItems.length - 1) {
      setState(() {
        _currentIndex++;
        _showMeaning = false;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showCompletionDialog();
    }
  }

  void _previousWord() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showMeaning = false;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleMeaning() {
    setState(() {
      _showMeaning = !_showMeaning;
    });
  }

  void _showCompletionDialog() {
    final hasQuizProgress = widget.savedQuizProgress != null;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('背诵完成'),
        content: Text(widget.isImmediateReview
          ? '恭喜！你已经完成了错误词语的背诵。\n现在回到测试继续作答。'
          : hasQuizProgress 
            ? '恭喜！你已经完成了错误词语的背诵。\n现在继续之前的测试。'
            : '恭喜！你已经完成了所有词语的背诵。\n现在开始双向默写测试。'),
        actions: [
          if (widget.isImmediateReview) ...[
            // 立即复习模式：简单返回到调用的测试界面
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 关闭对话框
                Navigator.pop(context); // 返回到调用的测试界面
              },
              child: const Text('回到测试'),
            ),
          ] else if (hasQuizProgress) ...[
            // 如果有保存的测试进度，只显示"继续测试"，不显示"完成"
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 恢复之前的测试进度
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(
                      wordItems: widget.wordItems, // 这个参数在恢复时不会被使用
                      savedProgress: widget.savedQuizProgress,
                    ),
                  ),
                );
              },
              child: const Text('继续测试'),
            ),
          ] else ...[
            // 如果是正常的背诵后双向测试，强制进入测试，不提供"完成"选项
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 开始新的双向测试
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(
                      wordItems: widget.wordItems,
                      isBidirectional: true,
                      isRandomQuiz: false,
                    ),
                  ),
                );
              },
              child: const Text('开始测试'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wordItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('背诵模式'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          automaticallyImplyLeading: AppConfig.showBackButtonInLearningFlow,
        ),
        body: const Center(
          child: Text('没有词语可以背诵'),
        ),
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: Text('背诵模式 (${_currentIndex + 1}/${widget.wordItems.length})'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: AppConfig.showBackButtonInLearningFlow,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _showMeaning = false;
          });
        },
        itemCount: widget.wordItems.length,
        itemBuilder: (context, index) {
          final wordItem = widget.wordItems[index];
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          wordItem.word,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _showMeaning ? null : 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _showMeaning ? 1.0 : 0.0,
                            child: Column(
                              children: [
                                const Divider(),
                                const SizedBox(height: 16),
                                Text(
                                  wordItem.meaning,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _toggleMeaning,
                  child: Text(_showMeaning ? '隐藏释义' : '显示释义'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _currentIndex > 0 ? _previousWord : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('上一个'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _nextWord,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_currentIndex < widget.wordItems.length - 1 ? '下一个' : '完成'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}