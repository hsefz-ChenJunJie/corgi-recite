import 'package:flutter/material.dart';
import '../models/word_meaning_pair.dart';
import '../database/database_helper.dart';
import '../config/app_config.dart';
import 'smart_quiz_screen.dart';

class SearchQuizScreen extends StatefulWidget {
  const SearchQuizScreen({super.key});

  @override
  State<SearchQuizScreen> createState() => _SearchQuizScreenState();
}

class _SearchQuizScreenState extends State<SearchQuizScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  
  List<WordMeaningPair> _allPairs = [];
  List<WordMeaningPair> _filteredPairs = [];
  Set<int> _selectedIndices = {};
  bool _isLoading = true;
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    _loadAllPairs();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPairs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final pairs = await _dbHelper.getAllWordMeaningPairs();
      setState(() {
        _allPairs = pairs;
        _filteredPairs = pairs;
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

  void _searchPairs(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredPairs = _allPairs;
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      _filteredPairs = _allPairs.where((pair) {
        return pair.wordText.toLowerCase().contains(query.toLowerCase()) ||
               pair.meaningText.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices = Set.from(List.generate(_filteredPairs.length, (i) => i));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  void _startQuiz() {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一项进行抽查')),
      );
      return;
    }

    final selectedPairs = _selectedIndices
        .map((index) => _filteredPairs[index])
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SmartQuizScreen(
          specificPairs: selectedPairs,
          isSpecificQuiz: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('指定内容抽查'),
        leading: AppConfig.isDebugVersion
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (_filteredPairs.isNotEmpty) ...[
            TextButton(
              onPressed: _selectedIndices.length == _filteredPairs.length
                  ? _clearSelection
                  : _selectAll,
              child: Text(
                _selectedIndices.length == _filteredPairs.length ? '取消全选' : '全选',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索栏
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: '搜索词语或意项',
                      hintText: '输入关键词进行搜索...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchPairs('');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: _searchPairs,
                  ),
                ),
                
                // 结果统计
                if (_filteredPairs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Text(
                          _isSearching 
                              ? '搜索结果: ${_filteredPairs.length} 项'
                              : '全部内容: ${_filteredPairs.length} 项',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          '已选择: ${_selectedIndices.length} 项',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _selectedIndices.isNotEmpty 
                                ? Theme.of(context).primaryColor 
                                : null,
                            fontWeight: _selectedIndices.isNotEmpty 
                                ? FontWeight.bold 
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                
                // 搜索结果列表
                Expanded(
                  child: _filteredPairs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isSearching ? Icons.search_off : Icons.quiz,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isSearching ? '没有找到匹配的内容' : '还没有词语',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                              if (_isSearching) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '请尝试其他关键词',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredPairs.length,
                          itemBuilder: (context, index) {
                            final pair = _filteredPairs[index];
                            final isSelected = _selectedIndices.contains(index);
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              color: isSelected 
                                  ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                  : null,
                              child: ListTile(
                                title: Text(
                                  pair.wordText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected 
                                        ? Theme.of(context).primaryColor
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  pair.meaningText,
                                  style: TextStyle(
                                    color: isSelected 
                                        ? Theme.of(context).primaryColor
                                        : null,
                                  ),
                                ),
                                leading: Checkbox(
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    _toggleSelection(index);
                                  },
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).primaryColor,
                                      )
                                    : null,
                                onTap: () => _toggleSelection(index),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _selectedIndices.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _startQuiz,
              icon: const Icon(Icons.quiz),
              label: Text('开始抽查 (${_selectedIndices.length})'),
            )
          : null,
    );
  }
}