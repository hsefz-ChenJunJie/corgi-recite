import 'package:flutter/material.dart';
import '../models/word_item.dart';
import '../models/word_meaning_pair.dart';

class ConfirmWordsScreen extends StatefulWidget {
  final List<WordItem> wordItems;
  final List<WordMeaningPair> wordMeaningPairs;

  const ConfirmWordsScreen({
    super.key,
    this.wordItems = const [],
    this.wordMeaningPairs = const [],
  });

  @override
  State<ConfirmWordsScreen> createState() => _ConfirmWordsScreenState();
}

class _ConfirmWordsScreenState extends State<ConfirmWordsScreen> {
  bool get _useNewSystem => widget.wordMeaningPairs.isNotEmpty;
  
  int get _totalCount => _useNewSystem ? widget.wordMeaningPairs.length : widget.wordItems.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('确认添加内容'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context, 'cancel');
          },
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回修改',
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  '添加成功！',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '已成功添加 $_totalCount 个词语-意项配对',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '添加的内容：',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_totalCount 项',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _totalCount,
              itemBuilder: (context, index) {
                if (_useNewSystem) {
                  final pair = widget.wordMeaningPairs[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        pair.wordText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(pair.meaningText),
                      trailing: Icon(
                        Icons.done,
                        color: Colors.green.shade600,
                      ),
                    ),
                  );
                } else {
                  final wordItem = widget.wordItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        wordItem.word,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(wordItem.meaning),
                      trailing: Icon(
                        Icons.done,
                        color: Colors.green.shade600,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '建议立即开始背诵，趁热打铁效果更好！',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, 'cancel');
                        },
                        icon: const Icon(Icons.cancel),
                        label: const Text('取消添加'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('开始背诵'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}