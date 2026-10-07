import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_storage_service.dart';
import '../utils/privacy_formatter.dart';
import '../widgets/app_message.dart';

const _relationLabels = <String, String>{
  'self': '本人',
  'mother': '母亲',
  'father': '父亲',
  'spouse': '配偶',
  'child': '孩子',
  'sibling': '兄弟姐妹',
  'other': '其他家人',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final AppStorageService _storageService = AppStorageService.instance;

  final List<String> _highFreqQuestions = [
    '宝宝发烧了怎么办？',
    '最近总是头痛失眠是什么原因？',
    '如何缓解肩颈酸痛？',
    '高血压日常需要注意什么？',
  ];

  List<HealthProfile> _profiles = <HealthProfile>[];
  int? _selectedProfileId;
  bool _isLoadingProfiles = true;
  String? _observedToken;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final isNotificationsEnabled = await _storageService
        .readNotificationsEnabled();
    if (!isNotificationsEnabled) {
      return;
    }
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final result = await Permission.notification.request();
        await _storageService.writeNotificationsEnabled(result.isGranted);
      }
    } catch (_) {
      await _storageService.writeNotificationsEnabled(false);
    }
  }

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
    _loadProfiles();
  }

  Future<void> _startConsultation([String? initialQuestion]) async {
    if (_selectedProfileId == null) {
      AppMessage.showWarning(context, '请先选择就诊人');
      return;
    }

    await context.push(
      '/chat',
      extra: {
        'profileId': _selectedProfileId,
        'initialQuestion': initialQuestion,
      },
    );

    if (mounted) {
      await _loadProfiles();
    }
  }

  Future<void> _loadProfiles() async {
    final token = _observedToken;
    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = <HealthProfile>[];
        _selectedProfileId = null;
        _isLoadingProfiles = false;
      });
      return;
    }

    final cachedProfiles = _sortProfiles(await _storageService.readProfiles());
    if (!mounted) {
      return;
    }

    if (cachedProfiles.isNotEmpty) {
      int? newSelectedProfileId = _selectedProfileId;
      if (newSelectedProfileId != null &&
          !cachedProfiles.any((p) => p.id == newSelectedProfileId)) {
        newSelectedProfileId = _resolveSelectedProfileId(cachedProfiles);
      } else if (newSelectedProfileId == null) {
        newSelectedProfileId = _resolveSelectedProfileId(cachedProfiles);
      }

      setState(() {
        _profiles = cachedProfiles;
        _selectedProfileId = newSelectedProfileId;
        _isLoadingProfiles = false;
      });
    } else {
      setState(() {
        _isLoadingProfiles = true;
      });
    }

    try {
      final profiles = await _apiService.fetchProfiles(token);
      if (!mounted) {
        return;
      }

      final sortedProfiles = _sortProfiles(profiles);
      await _storageService.writeProfiles(sortedProfiles);

      int? newSelectedProfileId = _selectedProfileId;
      if (newSelectedProfileId != null &&
          !sortedProfiles.any((p) => p.id == newSelectedProfileId)) {
        newSelectedProfileId = _resolveSelectedProfileId(sortedProfiles);
      } else if (newSelectedProfileId == null) {
        newSelectedProfileId = _resolveSelectedProfileId(sortedProfiles);
      }

      setState(() {
        _profiles = sortedProfiles;
        _selectedProfileId = newSelectedProfileId;
        _isLoadingProfiles = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingProfiles = false;
      });
      AppMessage.showError(
        context,
        ApiService.extractErrorMessage(error, fallback: '获取健康档案失败'),
      );
    }
  }

  List<HealthProfile> _sortProfiles(List<HealthProfile> profiles) {
    final sorted = [...profiles];
    sorted.sort((left, right) {
      if (left.relation == 'self' && right.relation != 'self') {
        return -1;
      }
      if (left.relation != 'self' && right.relation == 'self') {
        return 1;
      }
      return left.id.compareTo(right.id);
    });
    return sorted;
  }

  int? _resolveSelectedProfileId(List<HealthProfile> profiles) {
    if (profiles.isEmpty) {
      return null;
    }

    final selectedProfileId = _selectedProfileId;
    if (selectedProfileId != null &&
        profiles.any((profile) => profile.id == selectedProfileId)) {
      return selectedProfileId;
    }

    return profiles
        .firstWhere(
          (profile) => profile.relation == 'self',
          orElse: () => profiles.first,
        )
        .id;
  }

  String _relationLabel(String relation) =>
      _relationLabels[relation] ?? relation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('三十天时刻智护 - 问诊大厅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 就诊人选择区
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('选择就诊人', style: Theme.of(context).textTheme.titleMedium),
                  TextButton(
                    onPressed: () async {
                      await context.push('/profile');
                      await _loadProfiles();
                    },
                    child: const Text('档案管理'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoadingProfiles)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_profiles.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '还没有健康档案',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '请先创建本人或家人的健康档案，再开始问诊。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () async {
                          await context.push('/profile');
                          await _loadProfiles();
                        },
                        child: const Text('去创建档案'),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _profiles.length,
                    itemBuilder: (context, index) {
                      final profile = _profiles[index];
                      final isSelected = profile.id == _selectedProfileId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            '${maskName(profile.name, fallback: '成员')} · ${_relationLabel(profile.relation)}',
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (!selected) {
                              return;
                            }
                            setState(() {
                              _selectedProfileId = profile.id;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 24),

              // 快速问诊入口
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _startConsultation(),
                  icon: const Icon(Icons.chat),
                  label: const Text('快速开始问诊', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 高频问题区
              Text('常见问题', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _highFreqQuestions.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      title: Text(_highFreqQuestions[index]),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () =>
                          _startConsultation(_highFreqQuestions[index]),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // 历史记录入口
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/history'),
                  icon: const Icon(Icons.history),
                  label: const Text('查看历史问诊记录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
