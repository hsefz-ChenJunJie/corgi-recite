import 'package:flutter/material.dart';
import '../services/quiz_service.dart';
import '../services/context_quiz_service.dart';
import '../config/app_config.dart';
import 'recite_screen.dart';
import '../models/word_item.dart';
import '../models/word_meaning_pair.dart';

class SmartQuizScreen extends StatefulWidget {
  final int? quizCount;
  final List<WordItem>? wordItems; // 用于双向测试
  final bool isBidirectionalQuiz; // 是否是双向测试
  final List<WordMeaningPair>? specificPairs; // 用于指定抽查
  final bool isSpecificQuiz; // 是否是指定抽查

  const SmartQuizScreen({
    super.key,
    this.quizCount,
    this.wordItems,
    this.isBidirectionalQuiz = false,
    this.specificPairs,
    this.isSpecificQuiz = false,
  });

  @override
  State<SmartQuizScreen> createState() => _SmartQuizScreenState();
}

class _SmartQuizScreenState extends State<SmartQuizScreen> {
  final QuizService _quizService = QuizService();
  final ContextQuizService _contextQuizService = ContextQuizService();
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  
  List<QuizItem> _quizItems = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _isLoading = true;
  bool _isAnswered = false;
  bool _isCorrect = false;
  final List<QuizItem> _incorrectItems = [];

  @override
  void initState() {
    super.initState();
    _loadQuizItems();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuizItems() async {
    try {
      List<QuizItem> items;
      
      if (widget.isSpecificQuiz && widget.specificPairs != null) {
        // 指定抽查模式：使用指定的词语-意项对进行测试
        items = await _quizService.getSpecificQuizItems(widget.specificPairs!);
      } else if (widget.isBidirectionalQuiz && widget.wordItems != null) {
        // 双向测试模式：使用新添加的词语进行双向测试
        items = await _quizService.getBidirectionalQuizItems(widget.wordItems!);
      } else {
        // 随机抽查模式：默认使用意项到词语的测试模式
        final count = widget.quizCount ?? 10; // 默认10个
        items = await _quizService.getMeaningToWordsQuizItems(count);
      }
      
      setState(() {
        _quizItems = items;
        _isLoading = false;
      });
      _setupCurrentQuestion();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载测试失败: $e')),
        );
      }
    }
  }

  void _setupCurrentQuestion() {
    // 清理旧的控制器
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();

    if (_currentIndex < _quizItems.length) {
      final currentItem = _quizItems[_currentIndex];
      final inputCount = currentItem.inputCount;
      
      for (int i = 0; i < inputCount; i++) {
        _controllers.add(TextEditingController());
        _focusNodes.add(FocusNode());
      }
      
      setState(() {
        _isAnswered = false;
        _isCorrect = false;
      });

      // 自动聚焦第一个输入框
      if (_controllers.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNodes.first.requestFocus();
        });
      }
    }
  }

  void _submitAnswer() {
    if (_currentIndex >= _quizItems.length) return;
    
    final currentItem = _quizItems[_currentIndex];
    final userAnswers = _controllers.map((c) => c.text).toList();
    
    final isCorrect = _quizService.validateAnswer(currentItem, userAnswers);
    
    setState(() {
      _isAnswered = true;
      _isCorrect = isCorrect;
    });

    if (isCorrect) {
      _correctCount++;
    } else {
      _incorrectItems.add(currentItem);
      
      // 如果是双向测试且答错，立即保存进度并返回背诵
      if (widget.isBidirectionalQuiz) {
        _handleBidirectionalError();
        return;
      }
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _quizItems.length - 1) {
      _currentIndex++;
      _setupCurrentQuestion();
    } else {
      _showResults();
    }
  }

  void _showResults() {
    final hasErrors = _incorrectItems.isNotEmpty;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(hasErrors ? '测试完成 - 有错误' : '测试完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('总题数: ${_quizItems.length}'),
            Text('正确数: $_correctCount'),
            Text('错误数: ${_incorrectItems.length}'),
            if (hasErrors) ...[
              const SizedBox(height: 16),
              const Text('需要重新背诵错误的词语。'),
            ],
          ],
        ),
        actions: [
          if (hasErrors) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startReviewIncorrectItems();
              },
              child: const Text('开始背诵'),
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('完成'),
            ),
          ],
        ],
      ),
    );
  }

  String _getLabelText(QuizItem item, int index) {
    switch (item.type) {
      case QuizItemType.meaningToWords:
        return '词语 ${index + 1}';
      case QuizItemType.wordToMeanings:
        return '意项 ${index + 1}';
      case QuizItemType.wordToMeaning:
        return '答案';
    }
  }

  void _handleBidirectionalError() {
    // 保存当前测试进度
    _saveQuizProgress();
    
    // 显示错误对话框并导航到背诵页面
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('答错了'),
        content: const Text('请先重新背诵错误的词语，背诵完成后会自动回到测试继续。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startImmediateReview();
            },
            child: const Text('开始背诵'),
          ),
        ],
      ),
    );
  }

  void _saveQuizProgress() {
    // 这里可以保存到数据库或SharedPreferences
    // 现在先用简单的临时存储
    // TODO: 实现进度持久化存储
  }

  void _startImmediateReview() {
    // 创建错误词语的WordItem列表
    final errorItem = _incorrectItems.last;
    final incorrectWordItems = <WordItem>[];
    
    if (errorItem.type == QuizItemType.meaningToWords) {
      // 意项到词语：为每个词语创建WordItem
      for (final word in errorItem.requiredWords) {
        incorrectWordItems.add(WordItem(
          word: word.text,
          meaning: errorItem.meaning!.text,
          createdAt: word.createdAt,
          updatedAt: word.updatedAt,
        ));
      }
    } else if (errorItem.type == QuizItemType.wordToMeanings) {
      // 词语到意项：为每个意项创建WordItem
      for (final meaning in errorItem.requiredMeanings) {
        incorrectWordItems.add(WordItem(
          word: errorItem.word!.text,
          meaning: meaning.text,
          createdAt: errorItem.word!.createdAt,
          updatedAt: errorItem.word!.updatedAt,
        ));
      }
    }

    if (incorrectWordItems.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReciteScreen(
            wordItems: incorrectWordItems,
            startFromWord: incorrectWordItems.first,
            isImmediateReview: true, // 标记为立即复习模式
          ),
        ),
      ).then((_) {
        // 背诵完成后恢复测试进度
        _resumeQuizAfterReview();
      });
    }
  }

  void _resumeQuizAfterReview() {
    // 从错误列表中移除刚刚背诵的词语
    if (_incorrectItems.isNotEmpty) {
      _incorrectItems.removeLast();
    }
    
    // 重置当前题目状态，让用户重新回答刚才答错的题目
    setState(() {
      _isAnswered = false;
      _isCorrect = false;
    });
    
    // 清空输入框
    for (final controller in _controllers) {
      controller.clear();
    }
    
    // 不调用_nextQuestion()，保持在当前题目让用户重新作答
    // 重新设置当前题目的输入框
    _setupCurrentQuestion();
  }

  void _startReviewIncorrectItems() {
    // 将错误的QuizItem转换为WordItem供背诵界面使用
    final incorrectWordItems = <WordItem>[];
    
    for (final item in _incorrectItems) {
      if (item.type == QuizItemType.meaningToWords) {
        // 意项到词语：为每个词语创建WordItem
        for (final word in item.requiredWords) {
          incorrectWordItems.add(WordItem(
            word: word.text,
            meaning: item.meaning!.text,
            createdAt: word.createdAt,
            updatedAt: word.updatedAt,
          ));
        }
      } else if (item.type == QuizItemType.wordToMeanings) {
        // 词语到意项：为每个意项创建WordItem
        for (final meaning in item.requiredMeanings) {
          incorrectWordItems.add(WordItem(
            word: item.word!.text,
            meaning: meaning.text,
            createdAt: item.word!.createdAt,
            updatedAt: item.word!.updatedAt,
          ));
        }
      }
    }

    if (incorrectWordItems.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReciteScreen(
            wordItems: incorrectWordItems,
            startFromWord: incorrectWordItems.first,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isBidirectionalQuiz ? '双向测试' : '智能抽查'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isBidirectionalQuiz ? '双向测试' : '智能抽查'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Text('没有可测试的内容'),
        ),
      );
    }

    final currentItem = _quizItems[_currentIndex];
    final progress = (_currentIndex + 1) / _quizItems.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.isBidirectionalQuiz ? '双向测试' : '智能抽查'} (${_currentIndex + 1}/${_quizItems.length})'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: AppConfig.showBackButtonInLearningFlow 
            ? null 
            : Container(), // 隐藏返回按钮（正式版）
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      currentItem.displayText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentItem.questionHint,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (currentItem.needsMultipleInputs) ...[
                      // 多个输入框
                      for (int i = 0; i < _controllers.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            decoration: InputDecoration(
                              labelText: _getLabelText(currentItem, i),
                              border: const OutlineInputBorder(),
                              enabled: !_isAnswered,
                            ),
                            onSubmitted: (_) {
                              if (i < _focusNodes.length - 1) {
                                _focusNodes[i + 1].requestFocus();
                              } else if (!_isAnswered) {
                                _submitAnswer();
                              }
                            },
                          ),
                        ),
                    ] else ...[
                      // 单个输入框
                      TextField(
                        controller: _controllers.first,
                        focusNode: _focusNodes.first,
                        decoration: const InputDecoration(
                          labelText: '答案',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_isAnswered,
                        onSubmitted: (_) {
                          if (!_isAnswered) {
                            _submitAnswer();
                          }
                        },
                      ),
                    ],
                    if (_isAnswered) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isCorrect ? Colors.green[50] : Colors.red[50],
                          border: Border.all(
                            color: _isCorrect ? Colors.green : Colors.red,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isCorrect ? '✓ 正确！' : '✗ 错误',
                              style: TextStyle(
                                color: _isCorrect ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!_isCorrect) ...[
                              const SizedBox(height: 8),
                              Text('正确答案: ${currentItem.expectedAnswerText}'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAnswered ? null : _submitAnswer,
                    child: const Text('提交答案'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAnswered ? _nextQuestion : null,
                    child: Text(_currentIndex < _quizItems.length - 1 ? '下一题' : '完成'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}