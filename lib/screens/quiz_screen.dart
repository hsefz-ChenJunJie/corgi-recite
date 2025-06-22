import 'package:flutter/material.dart';
import 'dart:math';
import '../models/word_item.dart';
import '../config/app_config.dart';
import 'recite_screen.dart';

class QuizScreen extends StatefulWidget {
  final List<WordItem> wordItems;
  final bool isBidirectional;
  final bool isRandomQuiz;
  final Map<String, dynamic>? savedProgress;

  const QuizScreen({
    super.key,
    required this.wordItems,
    this.isBidirectional = false,
    this.isRandomQuiz = false,
    this.savedProgress,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<WordItem> _shuffledWords;
  int _currentIndex = 0;
  int _correctCount = 0;
  int _totalCount = 0;
  bool _showingResult = false;
  bool _isCorrect = false;
  bool _isWordToMeaning = true;
  bool _hasAnswer = false;
  final List<WordItem> _wrongWords = [];
  bool _isPhase1 = true; // true: 词语→意项, false: 意项→词语
  
  final TextEditingController _answerController = TextEditingController();
  String _currentAnswer = '';

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
    _answerController.addListener(_onAnswerChanged);
  }

  void _onAnswerChanged() {
    setState(() {
      _hasAnswer = _answerController.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _initializeQuiz() {
    if (widget.savedProgress != null) {
      // 从保存的进度恢复
      _restoreFromProgress(widget.savedProgress!);
    } else {
      if (widget.isRandomQuiz) {
        // 随机抽查：只进行意项→词语
        _shuffledWords = List.from(widget.wordItems);
        _shuffledWords.shuffle(Random());
        _isWordToMeaning = false;
      } else if (widget.isBidirectional) {
        // 背诵后的双向测试：按顺序进行
        _shuffledWords = List.from(widget.wordItems);
        _isPhase1 = true;
        _isWordToMeaning = true;
      } else {
        // 默认情况
        _shuffledWords = List.from(widget.wordItems);
        _shuffledWords.shuffle(Random());
        _isWordToMeaning = false;
      }
    }
  }

  void _restoreFromProgress(Map<String, dynamic> progress) {
    _shuffledWords = (progress['wordItems'] as List<dynamic>)
        .map((item) => WordItem.fromMap(item as Map<String, dynamic>))
        .toList();
    _currentIndex = progress['currentIndex'] ?? 0;
    _correctCount = progress['correctCount'] ?? 0;
    _totalCount = progress['totalCount'] ?? 0;
    _isPhase1 = progress['isPhase1'] ?? true;
    _isWordToMeaning = progress['isWordToMeaning'] ?? true;
    
    // 恢复错误词语列表
    if (progress['wrongWords'] != null) {
      _wrongWords.clear();
      _wrongWords.addAll((progress['wrongWords'] as List<dynamic>)
          .map((item) => WordItem.fromMap(item as Map<String, dynamic>))
          .toList());
    }
    
    // 直接使用保存的 _isWordToMeaning 值，不需要重新设置
  }

  Map<String, dynamic> _saveProgress() {
    return {
      'wordItems': _shuffledWords.map((item) => item.toMap()).toList(),
      'currentIndex': _currentIndex,
      'correctCount': _correctCount,
      'totalCount': _totalCount,
      'isPhase1': _isPhase1,
      'isWordToMeaning': _isWordToMeaning,
      'isBidirectional': widget.isBidirectional,
      'isRandomQuiz': widget.isRandomQuiz,
      'wrongWords': _wrongWords.map((item) => item.toMap()).toList(),
    };
  }

  void _setQuestionType() {
    if (widget.isRandomQuiz) {
      _isWordToMeaning = false;
    } else if (widget.isBidirectional) {
      // 双向测试时根据阶段确定
      _isWordToMeaning = _isPhase1;
    } else {
      _isWordToMeaning = false;
    }
  }

  void _submitAnswer() {
    if (_answerController.text.trim().isEmpty) return;

    setState(() {
      _showingResult = true;
      _totalCount++;
      
      final currentWord = _shuffledWords[_currentIndex];
      final userAnswer = _answerController.text.trim().toLowerCase();
      final correctAnswer = (_isWordToMeaning ? currentWord.meaning : currentWord.word).toLowerCase();
      
      _isCorrect = userAnswer == correctAnswer;
      _currentAnswer = _answerController.text.trim();
      
      if (_isCorrect) {
        _correctCount++;
      } else {
        // 记录错误的词语
        if (!_wrongWords.any((w) => w.id == currentWord.id)) {
          _wrongWords.add(currentWord);
        }
      }
    });
    
    // 只在双向测试时立即处理错误，随机抽查等到所有题目完成后处理
    if (!_isCorrect && _isBidirectionalTest()) {
      _showImmediateErrorDialog(_shuffledWords[_currentIndex]);
    }
  }

  bool _isBidirectionalTest() {
    // 如果是从保存进度恢复，检查保存的状态
    if (widget.savedProgress != null) {
      return widget.savedProgress!['isBidirectional'] ?? false;
    }
    // 否则使用Widget参数
    return widget.isBidirectional;
  }

  void _showImmediateErrorDialog(WordItem wrongWord) {
    final correctAnswer = (_isWordToMeaning ? wrongWord.meaning : wrongWord.word);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('答错了！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('你的答案: $_currentAnswer'),
            const SizedBox(height: 8),
            Text('正确答案: $correctAnswer'),
            const SizedBox(height: 16),
            const Text('需要重新背诵这个词语，完成后会回到当前进度继续测试。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 关闭对话框
              _handleImmediateError(wrongWord);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('重新背诵'),
          ),
        ],
      ),
    );
  }

  void _handleImmediateError(WordItem wrongWord) {
    // 保存当前进度
    final progress = _saveProgress();
    
    // 导航到背诵界面，背诵错误的词语
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReciteScreen(
          wordItems: [wrongWord],
          savedQuizProgress: progress,
        ),
      ),
    );
  }

  void _nextQuestion() {
    if (_currentIndex < _shuffledWords.length - 1) {
      setState(() {
        _currentIndex++;
        _showingResult = false;
        _answerController.clear();
        _currentAnswer = '';
        _hasAnswer = false;
        _setQuestionType();
      });
    } else {
      // 检查是否需要进入第二阶段（双向测试）
      if (_isBidirectionalTest() && _isPhase1) {
        _startPhase2();
      } else {
        _showFinalResults();
      }
    }
  }

  void _startPhase2() {
    setState(() {
      _isPhase1 = false;
      _isWordToMeaning = false;
      _currentIndex = 0;
      _showingResult = false;
      _answerController.clear();
      _currentAnswer = '';
      _hasAnswer = false;
    });
  }


  void _showFinalResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('测试完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('总题数: $_totalCount'),
            Text('正确数: $_correctCount'),
            Text('正确率: ${(_correctCount / _totalCount * 100).toStringAsFixed(1)}%'),
            if (_wrongWords.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('错误词语: ${_wrongWords.length}个'),
              if (_isBidirectionalTest()) ...[
                const SizedBox(height: 8),
                const Text(
                  '在测试过程中答错的词语已经重新背诵过了。\n你可以选择完成测试或者再次背诵错误的词语。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Text(
              _correctCount == _totalCount
                  ? '太棒了！全部正确！'
                  : _correctCount / _totalCount >= 0.8
                      ? '很好！继续加油！'
                      : _isBidirectionalTest() 
                          ? '不错！错误词语已在过程中背诵过了。'
                          : '还需要多练习哦！',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (_wrongWords.isEmpty) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.pop(context, true); // Pop QuizScreen and return true
              },
              child: const Text('完成'),
            ),
          ] else ...[
            // 如果是双向测试，提供两个选项
            if (_isBidirectionalTest()) ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  Navigator.pop(context, true); // Pop QuizScreen and return true
                },
                child: const Text('完成'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startWrongWordsRecite();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('重新背诵错词'),
              ),
            ] else ...[
              // 随机抽查强制背诵错词
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startWrongWordsRecite();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('重新背诵'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _startWrongWordsRecite() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReciteScreen(
          wordItems: _wrongWords,
          // 对于随机抽查，不传递savedQuizProgress，这样背诵完成后会正常进入双向测试
          // 对于双向测试的重新背诵错词，也不需要传递savedQuizProgress，因为是额外的背诵
        ),
      ),
    );
  }

  String _getScreenTitle() {
    // 如果是从保存的进度恢复，使用保存的状态
    if (widget.savedProgress != null) {
      final isBidirectional = widget.savedProgress!['isBidirectional'] ?? false;
      final isRandomQuiz = widget.savedProgress!['isRandomQuiz'] ?? false;
      
      if (isRandomQuiz) {
        return '随机抽查';
      } else if (isBidirectional) {
        return _isPhase1 ? '双向默写-第一阶段' : '双向默写-第二阶段';
      } else {
        return '测试';
      }
    }
    
    // 正常情况下使用Widget参数
    if (widget.isRandomQuiz) {
      return '随机抽查';
    } else if (widget.isBidirectional) {
      return _isPhase1 ? '双向默写-第一阶段' : '双向默写-第二阶段';
    } else {
      return '测试';
    }
  }


  @override
  Widget build(BuildContext context) {
    if (widget.wordItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isBidirectional ? '双向默写' : '随机抽查'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          automaticallyImplyLeading: AppConfig.showBackButtonInLearningFlow,
        ),
        body: const Center(
          child: Text('没有词语可以测试'),
        ),
      );
    }

    final currentWord = _shuffledWords[_currentIndex];
    final questionText = _isWordToMeaning ? currentWord.word : currentWord.meaning;
    final answerText = _isWordToMeaning ? currentWord.meaning : currentWord.word;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_getScreenTitle()} (${_currentIndex + 1}/${_shuffledWords.length})',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: AppConfig.showBackButtonInLearningFlow,
        actions: [
          if (_totalCount > 0)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '$_correctCount/$_totalCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
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
                      _isWordToMeaning ? '请写出以下词语的意思：' : '请写出对应的词语：',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      questionText,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (!_showingResult) ...[
                      TextField(
                        controller: _answerController,
                        decoration: const InputDecoration(
                          labelText: '你的答案',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onSubmitted: (_) => _submitAnswer(),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isCorrect ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isCorrect ? Colors.green : Colors.red,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isCorrect ? Icons.check_circle : Icons.cancel,
                                  color: _isCorrect ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isCorrect ? '正确！' : '错误！',
                                  style: TextStyle(
                                    color: _isCorrect ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('你的答案: $_currentAnswer'),
                            if (!_isCorrect) ...[
                              const SizedBox(height: 4),
                              Text('正确答案: $answerText'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (!_showingResult) ...[
              ElevatedButton(
                onPressed: _hasAnswer ? _submitAnswer : null,
                child: const Text('提交答案'),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(Icons.arrow_forward),
                label: Text(_currentIndex < _shuffledWords.length - 1 ? '下一题' : '完成'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}