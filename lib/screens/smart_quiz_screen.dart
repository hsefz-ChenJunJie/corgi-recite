import 'package:flutter/material.dart';
import '../services/context_quiz_service.dart';
import '../services/context_parser.dart';
import '../config/app_config.dart';
import 'recite_screen.dart';
import '../models/word_item.dart';
import '../models/word_meaning_pair.dart';
import '../models/word.dart';
import '../models/meaning.dart';
import '../database/database_helper.dart';

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
  final ContextQuizService _contextQuizService = ContextQuizService();
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  
  List<SmartQuizItem> _quizItems = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _isLoading = true;
  bool _isAnswered = false;
  bool _isCorrect = false;
  final List<SmartQuizItem> _incorrectItems = [];

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
      List<SmartQuizItem> items;
      
      if (widget.isSpecificQuiz && widget.specificPairs != null) {
        // 指定抽查模式：使用指定的词语-意项对进行单向测试（意项→词语）
        items = await _contextQuizService.generateRandomQuizItems(widget.specificPairs!);
      } else if (widget.isBidirectionalQuiz && widget.wordItems != null) {
        // 双向测试模式：使用新添加的词语进行双向测试
        final pairs = await _convertWordItemsToPairs(widget.wordItems!);
        items = await _contextQuizService.generateSmartQuizItems(pairs);
      } else {
        // 随机抽查模式：只生成意项→词语的单向测试
        final count = widget.quizCount ?? 10; // 默认10个
        final pairs = await _getRandomPairs(count);
        items = await _contextQuizService.generateRandomQuizItems(pairs);
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

  /// 将WordItem列表转换为WordMeaningPair列表
  Future<List<WordMeaningPair>> _convertWordItemsToPairs(List<WordItem> wordItems) async {
    final dbHelper = DatabaseHelper();
    final pairs = <WordMeaningPair>[];
    
    for (final item in wordItems) {
      // 从数据库获取或创建Word和Meaning，确保有正确的id
      final word = await dbHelper.getWordByText(item.word) ?? 
        Word(id: null, text: item.word, createdAt: item.createdAt, updatedAt: item.updatedAt);
      final meaning = await dbHelper.getMeaningByText(item.meaning) ?? 
        Meaning(id: null, text: item.meaning, createdAt: item.createdAt, updatedAt: item.updatedAt);
      
      pairs.add(WordMeaningPair(word: word, meaning: meaning));
    }
    
    return pairs;
  }

  /// 获取随机词语-意项配对
  Future<List<WordMeaningPair>> _getRandomPairs(int count) async {
    final pairs = await DatabaseHelper().getAllWordMeaningPairs();
    if (pairs.isEmpty) return [];
    
    pairs.shuffle();
    return pairs.take(count).toList();
  }

  /// 获取当前测试项需要的输入框数量
  int _getInputCount(SmartQuizItem item) {
    if (item.quizType == QuizType.blank) {
      // 检查是否有多个填空项（多特殊信息）
      if (item.blankQuizItems != null && item.blankQuizItems!.isNotEmpty) {
        int totalBlanks = 0;
        for (final blankQuiz in item.blankQuizItems!) {
          totalBlanks += blankQuiz.blanks.length;
        }
        return totalBlanks;
      } else if (item.blankQuiz != null) {
        // 单个填空项（向后兼容）
        return item.blankQuiz!.blanks.length;
      } else {
        return 1; // 默认至少一个输入框
      }
    } else {
      // 传统题目：如果有多个期望答案，则需要多个输入框
      return item.expectedAnswers.length;
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
      final inputCount = _getInputCount(currentItem);
      
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
    
    // 根据题目类型决定传递答案的格式
    final dynamic userAnswer;
    if (currentItem.quizType == QuizType.blank) {
      // 填空题传递答案列表
      userAnswer = userAnswers;
    } else {
      // 传统题目：如果有多个期望答案，传递答案列表；否则传递单个答案
      if (currentItem.expectedAnswers.length > 1) {
        userAnswer = userAnswers;
      } else {
        userAnswer = userAnswers.first;
      }
    }
    
    final result = _contextQuizService.validateAnswer(currentItem, userAnswer);
    final isCorrect = result.isCorrect;
    
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

  String _getLabelText(SmartQuizItem item, int index) {
    if (item.quizType == QuizType.blank) {
      // 检查是否有多个填空项（多特殊信息）
      if (item.blankQuizItems != null && item.blankQuizItems!.isNotEmpty) {
        // 计算当前输入框属于哪个填空项
        int currentBlankIndex = 0;
        
        for (int wordIdx = 0; wordIdx < item.blankQuizItems!.length; wordIdx++) {
          final blankQuiz = item.blankQuizItems![wordIdx];
          if (index < currentBlankIndex + blankQuiz.blanks.length) {
            // 找到对应的填空项
            final blankIndex = index - currentBlankIndex;
            final blankAnswer = blankQuiz.blanks[blankIndex];
            return blankAnswer.hint ?? '第${wordIdx + 1}个词语-答案${blankIndex + 1}';
          }
          currentBlankIndex += blankQuiz.blanks.length;
        }
        return '答案 ${index + 1}';
      } else if (item.blankQuiz != null) {
        // 单个填空项（向后兼容）
        final blankAnswer = item.blankQuiz!.blanks[index];
        return blankAnswer.hint ?? '答案 ${index + 1}';
      } else {
        return '答案 ${index + 1}';
      }
    } else {
      // 传统题目：如果有多个答案，显示编号
      if (item.expectedAnswers.length > 1) {
        return '答案 ${index + 1}';
      } else {
        return '答案';
      }
    }
  }

  /// 获取显示文本
  String _getDisplayText(SmartQuizItem item) {
    if (item.quizType == QuizType.blank) {
      // 检查是否有多个填空项（多特殊信息）
      if (item.blankQuizItems != null && item.blankQuizItems!.isNotEmpty) {
        // 显示多个填空模板
        final templates = <String>[];
        for (int i = 0; i < item.blankQuizItems!.length; i++) {
          final blankQuiz = item.blankQuizItems![i];
          templates.add('第${i + 1}个词语：${blankQuiz.template}');
        }
        return templates.join('\n');
      } else if (item.blankQuiz != null) {
        // 单个填空项（向后兼容）
        return item.blankQuiz!.template;
      } else {
        return item.question;
      }
    } else {
      return item.question;
    }
  }

  /// 获取问题提示
  String _getQuestionHint(SmartQuizItem item) {
    if (item.quizType == QuizType.blank) {
      // 检查是否有多个填空项（多特殊信息）
      if (item.blankQuizItems != null && item.blankQuizItems!.isNotEmpty) {
        final totalBlanks = _getInputCount(item);
        return '请根据上述模板填入合适的内容（共$totalBlanks个空格）：';
      } else if (item.blankQuiz != null) {
        return '请根据模板填入合适的内容：';
      } else {
        return '请输入答案：';
      }
    } else {
      final targetType = item.direction == QuizDirection.wordToMeaning ? '意项' : '词语';
      if (item.expectedAnswers.length > 1) {
        return '请输入所有对应的$targetType（共${item.expectedAnswers.length}个）：';
      } else {
        return '请输入对应的$targetType：';
      }
    }
  }

  /// 是否需要多个输入框
  bool _needsMultipleInputs(SmartQuizItem item) {
    return _getInputCount(item) > 1;
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
    
    // 从SmartQuizItem的pairs中提取WordItem
    for (final pair in errorItem.pairs) {
      incorrectWordItems.add(WordItem(
        word: pair.word.text,
        meaning: pair.meaning.text,
        createdAt: pair.createdAt,
        updatedAt: pair.updatedAt,
      ));
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
    // 将错误的SmartQuizItem转换为WordItem供背诵界面使用
    final incorrectWordItems = <WordItem>[];
    
    for (final item in _incorrectItems) {
      for (final pair in item.pairs) {
        incorrectWordItems.add(WordItem(
          word: pair.word.text,
          meaning: pair.meaning.text,
          createdAt: pair.createdAt,
          updatedAt: pair.updatedAt,
        ));
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
                    // 对于填空题，分别显示问题和填空模板
                    if (currentItem.quizType == QuizType.blank && currentItem.blankQuiz != null) ...[
                      // 显示问题（意项）
                      Text(
                        '问题：${currentItem.question}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // 显示填空模板
                      Text(
                        '填空：${currentItem.blankQuiz!.template}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      // 传统题目只显示问题
                      Text(
                        _getDisplayText(currentItem),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      _getQuestionHint(currentItem),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (_needsMultipleInputs(currentItem)) ...[
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
                              Text('正确答案: ${currentItem.expectedAnswer}'),
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