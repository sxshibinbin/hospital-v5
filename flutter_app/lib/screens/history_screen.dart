import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_storage_service.dart';
import '../utils/privacy_formatter.dart';
import '../widgets/app_message.dart';
import '../constants/ai_watermark.dart';

const _relationLabels = <String, String>{
  'self': '本人',
  'mother': '母亲',
  'father': '父亲',
  'spouse': '配偶',
  'child': '孩子',
  'sibling': '兄弟姐妹',
  'other': '其他家人',
};

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  final AppStorageService _storageService = AppStorageService.instance;

  List<ChatSessionSummary> _chatSessions = <ChatSessionSummary>[];
  List<SavedConsultationRecord> _consultationRecords =
      <SavedConsultationRecord>[];
  List<HealthProfile> _profiles = <HealthProfile>[];
  bool _isLoading = true;
  bool _isDeletingSession = false;
  bool _isSelectionMode = false;
  String? _observedToken;
  int? _selectedProfileFilterId;
  String _sessionModeFilter = 'all';
  String _sessionSearchQuery = '';
  final Set<int> _selectedSessionIds = <int>{};
  int _batchDeleteTotal = 0;
  int _batchDeleteProcessed = 0;
  Set<int> _failedBatchDeleteIds = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) {
      return;
    }

    final nextToken = authProvider.token;
    if (_observedToken == nextToken) {
      return;
    }

    _observedToken = nextToken;
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    final token = _observedToken;
    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _chatSessions = <ChatSessionSummary>[];
        _consultationRecords = <SavedConsultationRecord>[];
        _profiles = <HealthProfile>[];
        _selectedProfileFilterId = null;
        _isLoading = false;
      });
      return;
    }

    final cachedSessions = await _storageService.readChatSessions();
    final cachedRecords = await _storageService.readConsultationRecords();
    final cachedProfiles = await _storageService.readProfiles();
    if (!mounted) {
      return;
    }

    if (cachedSessions.isNotEmpty ||
        cachedRecords.isNotEmpty ||
        cachedProfiles.isNotEmpty) {
      cachedSessions.sort(
        (left, right) => right.updatedAt.compareTo(left.updatedAt),
      );
      cachedRecords.sort(
        (left, right) => right.createdAt.compareTo(left.createdAt),
      );
      cachedProfiles.sort((left, right) {
        if (left.relation == 'self' && right.relation != 'self') {
          return -1;
        }
        if (left.relation != 'self' && right.relation == 'self') {
          return 1;
        }
        return left.id.compareTo(right.id);
      });
      setState(() {
        _chatSessions = cachedSessions;
        _consultationRecords = cachedRecords;
        _profiles = cachedProfiles;
        if (_selectedProfileFilterId != null &&
            !cachedProfiles.any(
              (profile) => profile.id == _selectedProfileFilterId,
            )) {
          _selectedProfileFilterId = null;
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results = await Future.wait([
        _apiService.fetchChatSessions(token),
        _apiService.fetchConsultationRecords(token),
        _apiService.fetchProfiles(token),
      ]);
      if (!mounted) {
        return;
      }
      final sessions = (results[0] as List<ChatSessionSummary>)
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      final records = (results[1] as List<SavedConsultationRecord>)
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      final profiles = (results[2] as List<HealthProfile>)
        ..sort((left, right) {
          if (left.relation == 'self' && right.relation != 'self') {
            return -1;
          }
          if (left.relation != 'self' && right.relation == 'self') {
            return 1;
          }
          return left.id.compareTo(right.id);
        });
      await Future.wait([
        _storageService.writeChatSessions(sessions),
        _storageService.writeConsultationRecords(records),
        _storageService.writeProfiles(profiles),
      ]);
      setState(() {
        _chatSessions = sessions;
        _consultationRecords = records;
        _profiles = profiles;
        if (_selectedProfileFilterId != null &&
            !profiles.any(
              (profile) => profile.id == _selectedProfileFilterId,
            )) {
          _selectedProfileFilterId = null;
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '获取历史记录失败'),
      );
    }
  }

  List<SavedConsultationRecord> get _displayedRecords {
    if (_selectedProfileFilterId == null) {
      return _consultationRecords;
    }
    return _consultationRecords
        .where((record) => record.profileId == _selectedProfileFilterId)
        .toList();
  }

  List<ChatSessionSummary> get _displayedSessions {
    final normalizedQuery = _sessionSearchQuery.trim().toLowerCase();
    return _chatSessions.where((session) {
      final matchesMode =
          _sessionModeFilter == 'all' || session.mode == _sessionModeFilter;
      if (!matchesMode) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final title = session.title.toLowerCase();
      final lastMessage = (session.lastMessage ?? '').toLowerCase();
      return title.contains(normalizedQuery) ||
          lastMessage.contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          if (_displayedSessions.isNotEmpty)
            IconButton(
              onPressed: _toggleSessionSelectionMode,
              icon: Icon(
                _isSelectionMode ? Icons.close_fullscreen : Icons.checklist,
              ),
            ),
          if (_isSelectionMode && _selectedSessionIds.isNotEmpty)
            IconButton(
              onPressed: _deleteSelectedSessions,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          IconButton(
            onPressed: _loadHistoryData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistoryData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionHeader(
                    context,
                    title: '咨询对话历史',
                    subtitle: '继续查看或恢复之前的聊天上下文',
                  ),
                  const SizedBox(height: 12),
                  if (_chatSessions.isNotEmpty) ...[
                    _buildSessionToolbar(context),
                    const SizedBox(height: 12),
                  ],
                  if (_displayedSessions.isEmpty)
                    _buildEmptyCard(
                      context,
                      icon: Icons.chat_bubble_outline,
                      title: _chatSessions.isEmpty ? '还没有咨询对话历史' : '没有匹配的咨询对话',
                      description: _chatSessions.isEmpty
                          ? '去首页开启一次问诊后，这里会自动记录你的聊天会话。'
                          : '可以调整模式筛选或搜索关键词后再试一次。',
                    )
                  else
                    ..._buildGroupedSessionSections(context),
                  const SizedBox(height: 28),
                  _buildSectionHeader(
                    context,
                    title: '个人问诊记录',
                    subtitle: '已保存的 AI 导诊总结会展示在这里',
                  ),
                  const SizedBox(height: 12),
                  if (_profiles.isNotEmpty) ...[
                    _buildProfileFilterBar(context),
                    const SizedBox(height: 12),
                  ],
                  if (_displayedRecords.isEmpty)
                    _buildEmptyCard(
                      context,
                      icon: Icons.description_outlined,
                      title: _selectedProfileFilterId == null
                          ? '还没有个人问诊记录'
                          : '当前咨询人还没有问诊记录',
                      description: _selectedProfileFilterId == null
                          ? '在 AI 导诊保存问诊总结后，这里会展示对应记录。'
                          : '切换筛选或继续在 AI 导诊中保存问诊总结。',
                    )
                  else
                    ..._displayedRecords.map(_buildRecordCard),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedSessionSections(BuildContext context) {
    final groupedSessions = _groupedSessions(_displayedSessions);
    final widgets = <Widget>[];
    groupedSessions.forEach((label, sessions) {
      widgets.add(_buildSessionGroupHeader(context, label));
      widgets.add(const SizedBox(height: 8));
      widgets.addAll(sessions.map(_buildSessionCard));
    });
    return widgets;
  }

  Widget _buildSessionGroupHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }

  Map<String, List<ChatSessionSummary>> _groupedSessions(
    List<ChatSessionSummary> sessions,
  ) {
    final grouped = <String, List<ChatSessionSummary>>{};
    for (final session in sessions) {
      grouped
          .putIfAbsent(_groupLabel(session.updatedAt), () => [])
          .add(session);
    }
    return grouped;
  }

  String _groupLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final diff = today.difference(target).inDays;
    if (diff <= 0) {
      return '今天';
    }
    if (diff == 1) {
      return '昨天';
    }
    return '更早';
  }

  Widget _buildHighlightedText(
    String text, {
    TextStyle? baseStyle,
    int? maxLines,
  }) {
    final query = _sessionSearchQuery.trim();
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final matchIndex = lowerText.indexOf(lowerQuery, start);
      if (matchIndex < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      if (matchIndex > start) {
        spans.add(TextSpan(text: text.substring(start, matchIndex)));
      }

      final matchEnd = matchIndex + lowerQuery.length;
      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchEnd),
          style: baseStyle?.copyWith(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = matchEnd;
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }

  Widget _buildSessionCard(ChatSessionSummary session) {
    final modeLabel = session.mode == 'medical' ? 'AI 导诊' : '健康问答';
    final preview = (session.lastMessage ?? '').trim();
    final isSelected = _selectedSessionIds.contains(session.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            child: _isSelectionMode
                ? Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  )
                : Icon(
                    session.mode == 'medical'
                        ? Icons.local_hospital_outlined
                        : Icons.favorite_outline,
                  ),
          ),
          title: _buildHighlightedText(
            session.title,
            baseStyle: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$modeLabel · ${_formatDateTime(session.updatedAt)}'),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildHighlightedText(
                    preview,
                    baseStyle: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isSelectionMode && !_isDeletingSession)
                IconButton(
                  tooltip: '删除对话',
                  onPressed: () => _deleteSession(session),
                  icon: const Icon(Icons.delete_outline),
                ),
              if (!_isSelectionMode)
                const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
          selected: isSelected,
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedSessionIds.remove(session.id);
                } else {
                  _selectedSessionIds.add(session.id);
                }
              });
              return;
            }
            context.push(
              '/chat',
              extra: {
                'profileId': null,
                'initialQuestion': null,
                'sessionId': session.id,
              },
            );
          },
          onLongPress: () {
            if (_isSelectionMode) {
              return;
            }
            setState(() {
              _isSelectionMode = true;
              _selectedSessionIds.add(session.id);
            });
          },
        ),
      ),
    );
  }

  Widget _buildSessionToolbar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: '搜索标题或消息摘要',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _sessionSearchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      setState(() {
                        _sessionSearchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onChanged: (value) {
            setState(() {
              _sessionSearchQuery = value;
            });
          },
        ),
        if (_batchDeleteTotal > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDeletingSession
                      ? '正在删除 $_batchDeleteProcessed/$_batchDeleteTotal 条对话历史'
                      : _failedBatchDeleteIds.isEmpty
                      ? '最近一次批量删除已完成'
                      : '最近一次批量删除失败 ${_failedBatchDeleteIds.length} 条',
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _batchDeleteTotal == 0
                      ? null
                      : _batchDeleteProcessed / _batchDeleteTotal,
                ),
                if (!_isDeletingSession &&
                    _failedBatchDeleteIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _retryFailedBatchDelete,
                      child: const Text('重试失败项'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('全部模式'),
              selected: _sessionModeFilter == 'all',
              onSelected: (_) {
                setState(() {
                  _sessionModeFilter = 'all';
                });
              },
            ),
            ChoiceChip(
              label: const Text('AI 导诊'),
              selected: _sessionModeFilter == 'medical',
              onSelected: (_) {
                setState(() {
                  _sessionModeFilter = 'medical';
                });
              },
            ),
            ChoiceChip(
              label: const Text('健康问答'),
              selected: _sessionModeFilter == 'normal',
              onSelected: (_) {
                setState(() {
                  _sessionModeFilter = 'normal';
                });
              },
            ),
          ],
        ),
        if (_isSelectionMode) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('已选择 ${_selectedSessionIds.length} 条对话历史'),
                ),
                TextButton(
                  onPressed: _displayedSessions.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _selectedSessionIds
                              ..clear()
                              ..addAll(
                                _displayedSessions.map((session) => session.id),
                              );
                          });
                        },
                  child: const Text('全选当前结果'),
                ),
                TextButton(
                  onPressed: _selectedSessionIds.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _selectedSessionIds.clear();
                          });
                        },
                  child: const Text('清空'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordCard(SavedConsultationRecord record) {
    final department = _cleanText(
      record.recommendedDepartment,
      fallback: '待定科室',
    );
    final summary = _cleanText(record.summary, fallback: '暂无问诊摘要');
    final relationLabel = _relationLabels[record.relation] ?? record.relation;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showRecordDetails(record),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _recordProfileName(record),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '$relationLabel · ${_formatDateTime(record.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  department,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(summary),
                if (_hasText(record.analysis)) ...[
                  const SizedBox(height: 8),
                  Text(
                    _cleanText(record.analysis, fallback: ''),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '查看完整详情',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  kAiWatermark,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileFilterBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('按咨询人筛选问诊记录', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('全部'),
                  selected: _selectedProfileFilterId == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedProfileFilterId = null;
                    });
                  },
                ),
              ),
              ..._profiles.map(
                (profile) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${maskName(profile.name, fallback: '成员')} · ${_relationLabels[profile.relation] ?? profile.relation}',
                    ),
                    selected: _selectedProfileFilterId == profile.id,
                    onSelected: (_) {
                      setState(() {
                        _selectedProfileFilterId = profile.id;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteSession(ChatSessionSummary session) async {
    final token = _observedToken;
    if (token == null || token.isEmpty || _isDeletingSession) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条对话历史？'),
        content: Text('“${session.title}” 删除后将无法恢复，但不会影响已保存的问诊记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isDeletingSession = true;
    });

    try {
      await _apiService.deleteChatSession(token, session.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _chatSessions = _chatSessions
            .where((item) => item.id != session.id)
            .toList();
      });
      await _storageService.writeChatSessions(_chatSessions);
      _showSuccessMessage('已删除这条对话历史');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '删除对话历史失败'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingSession = false;
        });
      }
    }
  }

  Future<void> _deleteSelectedSessions() async {
    await _runBatchDelete(_selectedSessionIds.toList());
  }

  Future<void> _retryFailedBatchDelete() async {
    if (_failedBatchDeleteIds.isEmpty) {
      return;
    }
    await _runBatchDelete(_failedBatchDeleteIds.toList(), confirm: false);
  }

  Future<void> _runBatchDelete(
    List<int> deletingIds, {
    bool confirm = true,
  }) async {
    final token = _observedToken;
    if (token == null ||
        token.isEmpty ||
        _isDeletingSession ||
        deletingIds.isEmpty) {
      return;
    }

    final count = deletingIds.length;
    if (confirm) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('批量删除对话历史？'),
          content: Text('确定要删除选中的 $count 条对话历史吗？该操作无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        ),
      );

      if (shouldDelete != true) {
        return;
      }
    }

    setState(() {
      _isDeletingSession = true;
      _batchDeleteTotal = count;
      _batchDeleteProcessed = 0;
      _failedBatchDeleteIds = <int>{};
    });

    final deletedIds = <int>[];
    final failedIds = <int>{};

    for (final sessionId in deletingIds) {
      try {
        await _apiService.deleteChatSession(token, sessionId);
        deletedIds.add(sessionId);
      } catch (_) {
        failedIds.add(sessionId);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _batchDeleteProcessed += 1;
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _chatSessions = _chatSessions
          .where((session) => !deletedIds.contains(session.id))
          .toList();
      _selectedSessionIds.removeWhere(deletedIds.contains);
      _failedBatchDeleteIds = failedIds;
      _isDeletingSession = false;
      if (_selectedSessionIds.isEmpty && failedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
    await _storageService.writeChatSessions(_chatSessions);

    if (failedIds.isEmpty) {
      _showSuccessMessage('已删除 $count 条对话历史');
      return;
    }

    _showWarningMessage('已删除 ${deletedIds.length} 条，失败 ${failedIds.length} 条');
  }

  void _toggleSessionSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedSessionIds.clear();
        _failedBatchDeleteIds = <int>{};
        _batchDeleteTotal = 0;
        _batchDeleteProcessed = 0;
      }
    });
  }

  Future<void> _showRecordDetails(SavedConsultationRecord record) async {
    final relationLabel = _relationLabels[record.relation] ?? record.relation;
    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(_recordProfileName(record)),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$relationLabel · ${_formatDateTime(record.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailBlock(
                    context,
                    label: '推荐科室',
                    value: _cleanText(
                      record.recommendedDepartment,
                      fallback: '待定科室',
                    ),
                  ),
                  _buildDetailBlock(
                    context,
                    label: '问诊摘要',
                    value: _cleanText(record.summary, fallback: '暂无问诊摘要'),
                  ),
                  _buildDetailBlock(
                    context,
                    label: '病情分析',
                    value: _cleanText(record.analysis, fallback: '暂无病情分析'),
                  ),
                  _buildDetailBlock(
                    context,
                    label: '就医建议',
                    value: _cleanText(
                      record.hospitalSuggestion,
                      fallback: '暂无就医建议',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kAiWatermark,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailBlock(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  String _cleanText(String? value, {required String fallback}) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? fallback : normalized;
  }

  String _recordProfileName(SavedConsultationRecord record) {
    return maskName(record.profileName, fallback: '成员');
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  void _showSuccessMessage(String message) {
    AppMessage.showSuccess(context, message);
  }

  void _showWarningMessage(String message) {
    AppMessage.showWarning(context, message);
  }

  void _showErrorMessage(String message) {
    AppMessage.showError(context, message);
  }
}
