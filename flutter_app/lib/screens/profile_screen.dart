import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_storage_service.dart';
import '../utils/privacy_formatter.dart';
import '../widgets/app_message.dart';

const _relationOptions = <String, String>{
  'self': '本人',
  'mother': '母亲',
  'father': '父亲',
  'spouse': '配偶',
  'child': '孩子',
  'sibling': '兄弟姐妹',
  'other': '其他家人',
};

const _genderOptions = <String>['男', '女', '未填写'];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  final AppStorageService _storageService = AppStorageService.instance;

  List<HealthProfile> _profiles = <HealthProfile>[];
  bool _isLoading = true;
  String? _observedToken;

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

  Future<void> _loadProfiles() async {
    final token = _observedToken;
    if (token == null || token.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = <HealthProfile>[];
        _isLoading = false;
      });
      return;
    }

    final cachedProfiles = await _storageService.readProfiles();
    if (!mounted) {
      return;
    }

    if (cachedProfiles.isNotEmpty) {
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
        _profiles = cachedProfiles;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final profiles = await _apiService.fetchProfiles(token);
      if (!mounted) {
        return;
      }
      profiles.sort((left, right) {
        if (left.relation == 'self' && right.relation != 'self') {
          return -1;
        }
        if (left.relation != 'self' && right.relation == 'self') {
          return 1;
        }
        return left.id.compareTo(right.id);
      });
      await _storageService.writeProfiles(profiles);
      setState(() {
        _profiles = profiles;
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
        ApiService.extractErrorMessage(error, fallback: '获取健康档案失败'),
      );
    }
  }

  Future<void> _showProfileEditor({HealthProfile? profile}) async {
    final token = _observedToken;
    if (token == null || token.isEmpty) {
      _showWarningMessage('请先登录后再管理健康档案');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: profile?.name ?? '');
    final medicalHistoryController = TextEditingController(
      text: profile?.medicalHistory ?? '',
    );
    final allergiesController = TextEditingController(
      text: profile?.allergies ?? '',
    );

    var relation =
        profile?.relation ??
        (_profiles.any((item) => item.relation == 'self') ? 'mother' : 'self');
    var gender = profile?.gender ?? '未填写';
    var age = profile?.age ?? 30;
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(profile == null ? '新建档案' : '编辑档案'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: '姓名'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '请填写姓名'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: relation,
                          decoration: const InputDecoration(labelText: '关系'),
                          items: _relationOptions.entries
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              relation = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: gender,
                          decoration: const InputDecoration(labelText: '性别'),
                          items: _genderOptions
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              gender = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: '$age',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '年龄'),
                          validator: (value) {
                            final parsedAge = int.tryParse(value ?? '');
                            if (parsedAge == null ||
                                parsedAge < 0 ||
                                parsedAge > 120) {
                              return '请填写正确的年龄';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            age = int.tryParse(value) ?? age;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: medicalHistoryController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '既往病史',
                            hintText: '如高血压、糖尿病、手术史等',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: allergiesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: '过敏信息',
                            hintText: '如药物、食物或环境过敏',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                if (profile != null)
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final shouldDelete = await showDialog<bool>(
                              context: dialogContext,
                              builder: (context) => AlertDialog(
                                title: const Text('删除该档案？'),
                                content: const Text('删除后将无法恢复，请谨慎操作。'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('确认删除'),
                                  ),
                                ],
                              ),
                            );
                            if (shouldDelete != true) {
                              return;
                            }
                            setDialogState(() {
                              isSubmitting = true;
                            });
                            try {
                              await _apiService.deleteProfile(
                                token: token,
                                profileId: profile.id,
                              );
                              if (!mounted) {
                                return;
                              }
                              await _loadProfiles();
                              _showSuccessMessage(
                                '已删除${_displayName(profile)}的档案',
                              );
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            } catch (error) {
                              if (!mounted) {
                                return;
                              }
                              _showErrorMessage(
                                ApiService.extractErrorMessage(
                                  error,
                                  fallback: '删除档案失败',
                                ),
                              );
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  isSubmitting = false;
                                });
                              }
                            }
                          },
                    child: const Text('删除'),
                  ),
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          final payload = HealthProfilePayload(
                            name: nameController.text.trim(),
                            relation: relation,
                            gender: gender,
                            age: age,
                            medicalHistory: _nullableText(
                              medicalHistoryController.text,
                            ),
                            allergies: _nullableText(allergiesController.text),
                          );
                          try {
                            final savedProfile = profile == null
                                ? await _apiService.createProfile(
                                    token,
                                    payload,
                                  )
                                : await _apiService.updateProfile(
                                    token: token,
                                    profileId: profile.id,
                                    payload: payload,
                                  );
                            if (!mounted) {
                              return;
                            }
                            await _loadProfiles();
                            _showSuccessMessage(
                              profile == null
                                  ? '已创建${_displayName(savedProfile)}的档案'
                                  : '已更新${_displayName(savedProfile)}的档案',
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (error) {
                            if (!mounted) {
                              return;
                            }
                            _showErrorMessage(
                              ApiService.extractErrorMessage(
                                error,
                                fallback: profile == null ? '创建档案失败' : '更新档案失败',
                              ),
                            );
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                            }
                          }
                        },
                  child: Text(profile == null ? '创建档案' : '保存修改'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    medicalHistoryController.dispose();
    allergiesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('档案管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _profiles.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 56,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '还没有健康档案',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '可以先为本人或家人创建一份健康档案，方便后续 AI 导诊关联问诊记录。',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _showProfileEditor,
                                icon: const Icon(Icons.add),
                                label: const Text('新建档案'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _profiles.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final profile = _profiles[index];
                          final subtitleParts = <String>[
                            _relationOptions[profile.relation] ??
                                profile.relation,
                            profile.gender,
                            '${profile.age} 岁',
                            if ((profile.medicalHistory ?? '')
                                .trim()
                                .isNotEmpty)
                              '病史：${profile.medicalHistory!.trim()}',
                            if ((profile.allergies ?? '').trim().isNotEmpty)
                              '过敏：${profile.allergies!.trim()}',
                          ];

                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(_displayName(profile)),
                                  ),
                                ),
                              ),
                              title: Text(_displayName(profile)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(subtitleParts.join(' · ')),
                              ),
                              trailing: IconButton(
                                onPressed: () =>
                                    _showProfileEditor(profile: profile),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              onTap: () => _showProfileEditor(profile: profile),
                            ),
                          );
                        },
                      ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showProfileEditor,
        icon: const Icon(Icons.add),
        label: const Text('新建档案'),
      ),
    );
  }

  String? _nullableText(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _displayName(HealthProfile profile) {
    return maskName(profile.name, fallback: '成员');
  }

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
