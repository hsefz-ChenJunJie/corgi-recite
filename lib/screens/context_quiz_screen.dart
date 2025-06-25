import 'package:flutter/material.dart';
import '../models/word_meaning_pair.dart';
import '../models/word_item.dart';
import '../services/context_quiz_service.dart';
import '../services/context_parser.dart';
import '../config/app_config.dart';
import 'smart_recite_screen.dart';

/// 上下文感知测试界面
/// 支持传统问答题和智能填空题的混合测试
class ContextQuizScreen extends StatefulWidget {
  final int? quizCount;
  final List<WordItem>? wordItems; // 用于双向测试
  final bool isBidirectionalQuiz; // 是否是双向测试
  final List<WordMeaningPair>? specificPairs; // 用于指定抽查
  final bool isSpecificQuiz; // 是否是指定抽查

  const ContextQuizScreen({
    super.key,
    this.quizCount,
    this.wordItems,
    this.isBidirectionalQuiz = false,
    this.specificPairs,
    this.isSpecificQuiz = false,
  });

  @override
  State<ContextQuizScreen> createState() => _ContextQuizScreenState();
}

class _ContextQuizScreenState extends State<ContextQuizScreen> {
  final ContextQuizService _contextQuizService = ContextQuizService();
  final List<TextEditingController> _blankControllers = [];
  final List<FocusNode> _blankFocusNodes = [];
  final TextEditingController _traditionalController = TextEditingController();
  final FocusNode _traditionalFocusNode = FocusNode();
  
  List<SmartQuizItem> _quizItems = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _isLoading = true;
  bool _isAnswered = false;
  bool _isCorrect = false;
  final List<SmartQuizItem> _incorrectItems = [];
  String _currentPhase = '第一阶段：词语→意项';
  bool _isFirstPhase = true;

  @override
  void initState() {
    super.initState();
    _loadQuizItems();
  }

  @override
  void dispose() {
    for (final controller in _blankControllers) {
      controller.dispose();
    }
    for (final focusNode in _blankFocusNodes) {
      focusNode.dispose();
    }
    _traditionalController.dispose();
    _traditionalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadQuizItems() async {
    try {
      List<WordMeaningPair> pairs = [];
      
      if (widget.isSpecificQuiz && widget.specificPairs != null) {
        pairs = widget.specificPairs!;
      } else if (widget.isBidirectionalQuiz && widget.wordItems != null) {
        // 双向测试：从WordItem转换为WordMeaningPair
        // 这里需要从数据库重新获取WordMeaningPair
        // 暂时使用原有逻辑，后续可以优化
        pairs = widget.specificPairs ?? [];
      } else {
        // 随机抽查：从数据库获取指定数量的pairs
        // 这里需要实现随机获取逻辑
        pairs = [];
      }

      if (pairs.isNotEmpty) {
        final allQuizItems = await _contextQuizService.generateSmartQuizItems(pairs);
        
        if (widget.isBidirectionalQuiz) {
          // 双向测试：分两个阶段
          _quizItems = allQuizItems.where((item) => 
            item.direction == QuizDirection.wordToMeaning
          ).toList();
          _currentPhase = '第一阶段：词语→意项';
          _isFirstPhase = true;
        } else {
          // 其他测试：只测试意项→词语
          _quizItems = allQuizItems.where((item) => 
            item.direction == QuizDirection.meaningToWord
          ).toList();
          _currentPhase = '意项→词语测试';
        }
      }

      _initializeControllers();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载测试失败: $e')),
        );
      }
    }
  }

  void _initializeControllers() {
    // 清理现有控制器
    for (final controller in _blankControllers) {
      controller.dispose();
    }
    for (final focusNode in _blankFocusNodes) {
      focusNode.dispose();
    }
    _blankControllers.clear();
    _blankFocusNodes.clear();

    // 为当前题目初始化控制器
    if (_quizItems.isNotEmpty && _currentIndex < _quizItems.length) {
      final currentItem = _quizItems[_currentIndex];
      if (currentItem.quizType == QuizType.blank && currentItem.blankQuiz != null) {
        final blankCount = currentItem.blankQuiz!.blanks.length;
        for (int i = 0; i < blankCount; i++) {
          _blankControllers.add(TextEditingController());
          _blankFocusNodes.add(FocusNode());
        }
      }
    }
  }

  void _submitAnswer() {
    if (_isAnswered || _quizItems.isEmpty) return;

    final currentItem = _quizItems[_currentIndex];
    dynamic userAnswer;
    
    if (currentItem.quizType == QuizType.blank) {
      // 填空题：收集所有空白的答案
      userAnswer = _blankControllers.map((controller) => controller.text).toList();
    } else {
      // 传统题：单个文本答案
      userAnswer = _traditionalController.text;
    }

    final result = _contextQuizService.validateAnswer(currentItem, userAnswer);
    
    setState(() {
      _isAnswered = true;
      _isCorrect = result.isCorrect;
      if (_isCorrect) {
        _correctCount++;
      } else {
        _incorrectItems.add(currentItem);
      }
    });

    // 显示结果反馈
    _showAnswerFeedback(result);
  }

  void _showAnswerFeedback(QuizResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(result.isCorrect ? '正确！' : '错误'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!result.isCorrect) ...[
                Text('您的答案：${result.userAnswer}'),
                const SizedBox(height: 8),
                Text('正确答案：${result.correctAnswer}'),
                if (result.feedback.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('详细信息：${result.feedback}'),
                ],
              ] else ...[
                const Text('回答正确！'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (!_isCorrect) {
                  _handleIncorrectAnswer();
                } else {
                  _nextQuestion();
                }
              },
              child: Text(_isCorrect ? '继续' : '重新背诵'),
            ),
          ],
        );
      },
    );
  }

  void _handleIncorrectAnswer() {
    // 立即进入重新背诵
    final incorrectWordItems = <WordItem>[];
    
    // 将SmartQuizItem的pairs转换为WordItem以兼容SmartReciteScreen
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
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartReciteScreen(
          wordItems: incorrectWordItems,
        ),
      ),
    ).then((_) {
      // 背诵完成后，继续当前测试
      setState(() {
        _isAnswered = false;
        _isCorrect = false;
        _traditionalController.clear();
        for (final controller in _blankControllers) {
          controller.clear();
        }
      });
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _quizItems.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _isCorrect = false;
        _traditionalController.clear();
      });
      _initializeControllers();
    } else {
      _handleQuizCompletion();
    }
  }

  void _handleQuizCompletion() {
    if (widget.isBidirectionalQuiz && _isFirstPhase) {
      // 第一阶段完成，开始第二阶段
      _startSecondPhase();
    } else {
      // 测试完全完成
      _showCompletionDialog();
    }
  }

  void _startSecondPhase() {
    // 实现第二阶段逻辑
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('第一阶段完成'),
          content: Text('第一阶段正确率：${((_correctCount / _quizItems.length) * 100).toStringAsFixed(1)}%\n\n现在开始第二阶段：意项→词语'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadSecondPhase();
              },
              child: const Text('开始第二阶段'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSecondPhase() async {
    // 重置状态并加载第二阶段题目
    setState(() {
      _isLoading = true;
      _currentIndex = 0;
      _isFirstPhase = false;
      _currentPhase = '第二阶段：意项→词语';
    });

    // 这里需要重新生成第二阶段的题目
    // 暂时使用占位逻辑
    setState(() {
      _isLoading = false;
    });
  }

  void _showCompletionDialog() {
    final accuracy = _quizItems.isNotEmpty ? (_correctCount / _quizItems.length) * 100 : 0.0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('测试完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('总题数：${_quizItems.length}'),
              Text('正确数：$_correctCount'),
              Text('正确率：${accuracy.toStringAsFixed(1)}%'),
              if (_incorrectItems.isNotEmpty)
                Text('错误题数：${_incorrectItems.length}'),
            ],
          ),
          actions: [
            if (_incorrectItems.isNotEmpty) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _retestIncorrectItems();
                },
                child: const Text('重背错词'),
              ),
            ],
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context);
              },
              child: const Text('完成'),
            ),
          ],
        );
      },
    );
  }

  void _retestIncorrectItems() {
    final incorrectWordItems = <WordItem>[];
    
    // 将SmartQuizItem的pairs转换为WordItem以兼容SmartReciteScreen
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
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartReciteScreen(
          wordItems: incorrectWordItems,
        ),
      ),
    ).then((_) {
      // 背诵完成后，对错误的词语进行双向测试
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContextQuizScreen(
              specificPairs: _incorrectItems.expand((item) => item.pairs).toList(),
              isBidirectionalQuiz: true,
            ),
          ),
        ).then((_) {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    });
  }

  Widget _buildQuizContent() {
    if (_quizItems.isEmpty) {
      return const Center(
        child: Text('没有可测试的内容'),
      );
    }

    final currentItem = _quizItems[_currentIndex];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 进度指示器
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                _currentPhase,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _quizItems.length,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
              const SizedBox(height: 8),
              Text('${_currentIndex + 1} / ${_quizItems.length}'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // 题目内容
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    currentItem.quizType == QuizType.blank 
                        ? Icons.edit_outlined 
                        : Icons.quiz_outlined,
                    color: currentItem.quizType == QuizType.blank 
                        ? Colors.orange 
                        : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentItem.quizType == QuizType.blank 
                        ? '智能填空题' 
                        : '传统问答题',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: currentItem.quizType == QuizType.blank 
                          ? Colors.orange 
                          : Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '题目：',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                currentItem.question,
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // 答题区域
        if (currentItem.quizType == QuizType.blank) ...[
          _buildBlankQuizInput(currentItem),
        ] else ...[
          _buildTraditionalQuizInput(),
        ],
        
        const SizedBox(height: 24),
        
        // 提交按钮
        ElevatedButton(
          onPressed: _isAnswered ? null : _submitAnswer,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
          child: Text(
            _isAnswered ? '已提交' : '提交答案',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildBlankQuizInput(SmartQuizItem quizItem) {
    final blankQuiz = quizItem.blankQuiz!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '填空题：',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            blankQuiz.template,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text('请填入空白处：'),
          const SizedBox(height: 12),
          ...blankQuiz.blanks.asMap().entries.map((entry) {
            final index = entry.key;
            final blank = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text('第${index + 1}空：'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _blankControllers[index],
                      focusNode: _blankFocusNodes[index],
                      decoration: InputDecoration(
                        hintText: blank.hint ?? '请输入答案',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (index < _blankFocusNodes.length - 1) {
                          _blankFocusNodes[index + 1].requestFocus();
                        } else {
                          _submitAnswer();
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTraditionalQuizInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '请输入答案：',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _traditionalController,
            focusNode: _traditionalFocusNode,
            decoration: const InputDecoration(
              hintText: '在此输入您的答案',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submitAnswer(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSpecificQuiz 
            ? '指定内容测试' 
            : widget.isBidirectionalQuiz 
                ? '双向测试' 
                : '随机抽查'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: AppConfig.showBackButtonInQuiz,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('测试说明'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• 蓝色图标：传统问答题'),
                      Text('• 橙色图标：智能填空题'),
                      SizedBox(height: 8),
                      Text('智能填空题会根据输入时的上下文标记生成相应的空白，包括：'),
                      Text('  - 占位符：{something} → ___'),
                      Text('  - 介词：[at] → ___'),
                      Text('  - 关键词：big|large → ___'),
                      Text('  - 词性：(v.) → ___.'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('了解'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: _buildQuizContent(),
            ),
    );
  }
}