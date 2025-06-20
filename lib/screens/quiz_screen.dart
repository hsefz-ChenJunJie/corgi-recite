import 'package:flutter/material.dart';
import 'dart:math';
import '../models/word_item.dart';

class QuizScreen extends StatefulWidget {
  final List<WordItem> wordItems;
  final bool isBidirectional;

  const QuizScreen({
    super.key,
    required this.wordItems,
    this.isBidirectional = false,
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
  
  final TextEditingController _answerController = TextEditingController();
  String _currentAnswer = '';

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _initializeQuiz() {
    _shuffledWords = List.from(widget.wordItems);
    _shuffledWords.shuffle(Random());
    
    if (widget.isBidirectional) {
      List<WordItem> bidirectionalList = [];
      for (final word in _shuffledWords) {
        bidirectionalList.add(word);
        bidirectionalList.add(word);
      }
      _shuffledWords = bidirectionalList;
      _shuffledWords.shuffle(Random());
    }
    
    _setQuestionType();
  }

  void _setQuestionType() {
    if (widget.isBidirectional) {
      _isWordToMeaning = Random().nextBool();
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
      if (_isCorrect) {
        _correctCount++;
      }
      
      _currentAnswer = _answerController.text.trim();
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _shuffledWords.length - 1) {
      setState(() {
        _currentIndex++;
        _showingResult = false;
        _answerController.clear();
        _currentAnswer = '';
        _setQuestionType();
      });
    } else {
      _showFinalResults();
    }
  }

  void _retryQuestion() {
    setState(() {
      _showingResult = false;
      _answerController.clear();
      _currentAnswer = '';
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
            const SizedBox(height: 16),
            Text(
              _correctCount == _totalCount
                  ? '太棒了！全部正确！'
                  : _correctCount / _totalCount >= 0.8
                      ? '很好！继续加油！'
                      : '还需要多练习哦！',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('返回首页'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restartQuiz();
            },
            child: const Text('重新测试'),
          ),
        ],
      ),
    );
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _correctCount = 0;
      _totalCount = 0;
      _showingResult = false;
      _answerController.clear();
      _currentAnswer = '';
    });
    _initializeQuiz();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wordItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isBidirectional ? '双向默写' : '随机抽查'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
          '${widget.isBidirectional ? '双向默写' : '随机抽查'} (${_currentIndex + 1}/${_shuffledWords.length})',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                onPressed: _answerController.text.trim().isNotEmpty ? _submitAnswer : null,
                child: const Text('提交答案'),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!_isCorrect)
                    ElevatedButton.icon(
                      onPressed: _retryQuestion,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重答'),
                    ),
                  ElevatedButton.icon(
                    onPressed: _nextQuestion,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(_currentIndex < _shuffledWords.length - 1 ? '下一题' : '完成'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}