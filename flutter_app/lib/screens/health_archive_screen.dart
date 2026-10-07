import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/privacy_formatter.dart';
import '../widgets/app_message.dart';
import '../constants/ai_watermark.dart';

const _relationOptions = <String, String>{
  'self': '本人',
  'mother': '母亲',
  'father': '父亲',
  'spouse': '配偶',
  'child': '孩子',
  'sibling': '兄弟姐妹',
  'other': '其他家人',
};

const _archiveCategoryLabels = <String, String>{
  'all': '全部',
  'clinic': '问诊记录',
  // 'prescription': '门诊处方',
  // 'report': '体检报告',
};

const _healthSectionLabel = 'health';
const _archiveSectionLabel = 'archive';

const _genderOptions = <String>['男', '女'];

enum _RecordCardAction { delete }

const _relationPresets = <_RelationPreset>[
  _RelationPreset(
    backendValue: 'self',
    label: '本人',
    summaryLabel: '本人',
    icon: Icons.person_outline_rounded,
  ),
  _RelationPreset(
    backendValue: 'father',
    label: '爸爸',
    summaryLabel: '父亲',
    icon: Icons.man_rounded,
  ),
  _RelationPreset(
    backendValue: 'mother',
    label: '妈妈',
    summaryLabel: '母亲',
    icon: Icons.woman_rounded,
  ),
  _RelationPreset(
    backendValue: 'spouse',
    label: '老公',
    summaryLabel: '配偶',
    icon: Icons.favorite_outline_rounded,
  ),
  _RelationPreset(
    backendValue: 'spouse',
    label: '老婆',
    summaryLabel: '配偶',
    icon: Icons.favorite_outline_rounded,
  ),
  _RelationPreset(
    backendValue: 'child',
    label: '儿子',
    summaryLabel: '孩子',
    icon: Icons.face_4_outlined,
  ),
  _RelationPreset(
    backendValue: 'child',
    label: '女儿',
    summaryLabel: '孩子',
    icon: Icons.face_3_outlined,
  ),
  _RelationPreset(
    backendValue: 'sibling',
    label: '哥哥',
    summaryLabel: '兄弟姐妹',
    icon: Icons.people_outline_rounded,
  ),
  _RelationPreset(
    backendValue: 'sibling',
    label: '弟弟',
    summaryLabel: '兄弟姐妹',
    icon: Icons.people_outline_rounded,
  ),
  _RelationPreset(
    backendValue: 'sibling',
    label: '姐姐',
    summaryLabel: '兄弟姐妹',
    icon: Icons.people_outline_rounded,
  ),
  _RelationPreset(
    backendValue: 'sibling',
    label: '妹妹',
    summaryLabel: '兄弟姐妹',
    icon: Icons.people_outline_rounded,
  ),
  _RelationPreset(
    backendValue: 'other',
    label: '爷爷',
    summaryLabel: '其他家人',
    icon: Icons.elderly_outlined,
  ),
  _RelationPreset(
    backendValue: 'other',
    label: '奶奶',
    summaryLabel: '其他家人',
    icon: Icons.elderly_woman_outlined,
  ),
  _RelationPreset(
    backendValue: 'other',
    label: '外公',
    summaryLabel: '其他家人',
    icon: Icons.elderly_outlined,
  ),
  _RelationPreset(
    backendValue: 'other',
    label: '外婆',
    summaryLabel: '其他家人',
    icon: Icons.elderly_woman_outlined,
  ),
  _RelationPreset(
    backendValue: 'other',
    label: '其他',
    summaryLabel: '其他家人',
    icon: Icons.more_horiz_rounded,
  ),
];

class HealthArchiveScreen extends StatefulWidget {
  const HealthArchiveScreen({super.key});

  @override
  State<HealthArchiveScreen> createState() => _HealthArchiveScreenState();
}

class _HealthArchiveScreenState extends State<HealthArchiveScreen> {
  final ApiService _apiService = ApiService();
  final AppStorageService _storageService = AppStorageService.instance;

  List<HealthProfile> _profiles = <HealthProfile>[];
  List<SavedConsultationRecord> _records = <SavedConsultationRecord>[];
  bool _isLoading = true;
  String? _observedToken;
  int? _selectedProfileId;
  String _selectedBottomSection = _archiveSectionLabel;
  String _selectedArchiveCategory = 'all';
  bool _isRedirectingToLogin = false;
  bool _hasPromptedInitialSelfProfileCreation = false;
  bool _isNameVisible = false;
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

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

    _hasPromptedInitialSelfProfileCreation = false;
    _observedToken = nextToken;
    _loadArchiveData();
  }

  Future<void> _loadArchiveData() async {
    final authProvider = context.read<AuthProvider>();
    final token = _observedToken;
    if (token == null || token.isEmpty) {
      await _redirectToLoginForArchive(message: '登录后才能查看健康档案，是否前往登录？');
      return;
    }

    await authProvider.refreshCurrentUser();
    if (!mounted) {
      return;
    }
    if (!_hasUsableSession(authProvider)) {
      await _redirectToLoginForArchive(message: '当前登录状态已失效，请重新登录后查看健康档案。');
      return;
    }

    final cachedProfiles = _sortProfiles(await _storageService.readProfiles());
    final cachedRecords = await _storageService.readConsultationRecords();
    if (!mounted) {
      return;
    }

    if (cachedProfiles.isNotEmpty || cachedRecords.isNotEmpty) {
      setState(() {
        _profiles = cachedProfiles;
        _records = _sortRecords(cachedRecords);
        _selectedProfileId = _resolveSelectedProfileId(cachedProfiles);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final results = await Future.wait([
        _apiService.fetchProfiles(token),
        _apiService.fetchConsultationRecords(token),
      ]);
      if (!mounted) {
        return;
      }

      final profiles = _sortProfiles(results[0] as List<HealthProfile>);
      final records = _sortRecords(results[1] as List<SavedConsultationRecord>);
      await Future.wait([
        _storageService.writeProfiles(profiles),
        _storageService.writeConsultationRecords(records),
      ]);
      setState(() {
        _profiles = profiles;
        _records = records;
        _selectedProfileId = _resolveSelectedProfileId(profiles);
        _isLoading = false;
      });
      _maybePromptInitialSelfProfileCreation();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorizedError(error)) {
        await _redirectToLoginForArchive(message: '当前登录状态已失效，请重新登录后查看健康档案。');
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

  void _maybePromptInitialSelfProfileCreation() {
    if (!mounted ||
        _hasPromptedInitialSelfProfileCreation ||
        _isLoading ||
        _profiles.isNotEmpty ||
        _observedToken == null ||
        _observedToken!.isEmpty) {
      return;
    }

    _hasPromptedInitialSelfProfileCreation = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _profiles.isNotEmpty || _isLoading) {
        return;
      }
      unawaited(_showProfileEditor());
    });
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

  List<SavedConsultationRecord> _sortRecords(
    List<SavedConsultationRecord> records,
  ) {
    final sorted = [...records];
    sorted.sort((left, right) => right.createdAt.compareTo(left.createdAt));
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

  HealthProfile? get _selectedProfile {
    final selectedProfileId = _selectedProfileId;
    if (selectedProfileId == null) {
      return null;
    }
    for (final profile in _profiles) {
      if (profile.id == selectedProfileId) {
        return profile;
      }
    }
    return null;
  }

  List<SavedConsultationRecord> get _displayedRecords {
    final selectedProfileId = _selectedProfileId;
    if (selectedProfileId == null) {
      return _records;
    }
    return _records
        .where((record) => record.profileId == selectedProfileId)
        .toList(growable: false);
  }

  List<SavedConsultationRecord> get _filteredArchiveRecords {
    if (_selectedArchiveCategory == 'prescription' ||
        _selectedArchiveCategory == 'report') {
      return const <SavedConsultationRecord>[];
    }
    return _displayedRecords;
  }

  int _categoryCount(String category) {
    return switch (category) {
      'all' => _displayedRecords.length,
      'clinic' => _displayedRecords.length,
      'prescription' => 0,
      'report' => 0,
      _ => 0,
    };
  }

  Future<void> _showProfileEditor({HealthProfile? profile}) async {
    final token = _observedToken;
    if (token == null || token.isEmpty) {
      await _redirectToLoginForArchive(message: '登录后才能管理健康档案，是否前往登录？');
      return;
    }

    final formKey = GlobalKey<FormState>();
    var name = profile?.name ?? '';
    var medicalHistory = profile?.medicalHistory ?? '';
    var allergies = profile?.allergies ?? '';

    final hasSelfProfile = _profiles.any((item) => item.relation == 'self');
    final relationPresets = profile == null && hasSelfProfile
        ? _relationPresets
              .where((preset) => preset.backendValue != 'self')
              .toList(growable: false)
        : _relationPresets;
    var selectedPreset = _initialRelationPreset(
      profile,
      hasSelfProfile: hasSelfProfile,
    );
    var gender = _normalizeGender(profile?.gender);
    var birthDate = _estimateBirthDateFromAge(profile?.age ?? 30);
    var isSubmitting = false;

    final result = await showModalBottomSheet<_ProfileEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final age = _calculateAge(birthDate);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F2FF),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 30,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      profile == null
                                          ? (hasSelfProfile
                                                ? '添加家庭成员'
                                                : '创建本人档案')
                                          : (profile.relation == 'self'
                                                ? '编辑本人档案'
                                                : '编辑家庭成员'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(sheetContext).pop(),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _buildInviteBanner(context),
                              const SizedBox(height: 16),
                              _buildSheetSectionTitle(context, '成员关系 *'),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: relationPresets
                                    .map(
                                      (preset) => _buildRelationPresetChip(
                                        context: context,
                                        preset: preset,
                                        selected:
                                            preset.label ==
                                            selectedPreset.label,
                                        onTap: () {
                                          setSheetState(() {
                                            selectedPreset = preset;
                                          });
                                        },
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 16),
                              _buildSheetSectionTitle(context, '姓名 *'),
                              const SizedBox(height: 10),
                              TextFormField(
                                initialValue: name,
                                decoration: InputDecoration(
                                  hintText:
                                      !hasSelfProfile && profile == null ||
                                          profile?.relation == 'self'
                                      ? '请输入本人姓名'
                                      : '请输入家庭成员姓名',
                                ),
                                onChanged: (value) {
                                  name = value;
                                },
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? '请填写姓名'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildSheetSectionTitle(context, '性别 *'),
                              const SizedBox(height: 10),
                              Row(
                                children: _genderOptions
                                    .map(
                                      (item) => Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right: item == _genderOptions.first
                                                ? 12
                                                : 0,
                                          ),
                                          child: _buildGenderSelector(
                                            context: context,
                                            label: item,
                                            selected: gender == item,
                                            onTap: () {
                                              setSheetState(() {
                                                gender = item;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 16),
                              _buildSheetSectionTitle(context, '出生日期 *'),
                              const SizedBox(height: 10),
                              _buildBirthDateField(
                                context: context,
                                birthDate: birthDate,
                                age: age,
                                onTap: () async {
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    locale: const Locale('zh', 'CN'),
                                    initialDate: birthDate,
                                    firstDate: DateTime(1940),
                                    lastDate: DateTime.now(),
                                  );
                                  if (pickedDate == null) {
                                    return;
                                  }
                                  setSheetState(() {
                                    birthDate = pickedDate;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildSheetSectionTitle(context, '既往病史'),
                              const SizedBox(height: 10),
                              TextFormField(
                                initialValue: medicalHistory,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: '如高血压、糖尿病、手术史等',
                                ),
                                onChanged: (value) {
                                  medicalHistory = value;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildSheetSectionTitle(context, '过敏信息'),
                              const SizedBox(height: 10),
                              TextFormField(
                                initialValue: allergies,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  hintText: '如药物、食物或环境过敏',
                                ),
                                onChanged: (value) {
                                  allergies = value;
                                },
                              ),
                              const SizedBox(height: 18),
                              Text(
                                '请保证信息的真实性，将基于您的档案信息提供个性化医疗服务。',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  if (profile != null)
                                    TextButton(
                                      onPressed: () {
                                        if (isSubmitting) {
                                          _showInfoMessage('正在提交，请稍候');
                                          return;
                                        }
                                        _deleteProfile(
                                          profile: profile,
                                          token: token,
                                          sheetContext: sheetContext,
                                          setSubmitting: (value) {
                                            if (!sheetContext.mounted) {
                                              return;
                                            }
                                            setSheetState(() {
                                              isSubmitting = value;
                                            });
                                          },
                                        );
                                      },
                                      child: Text(
                                        isSubmitting ? '处理中...' : '删除',
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 64),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        if (isSubmitting) {
                                          _showInfoMessage(
                                            profile == null
                                                ? '正在保存档案，请稍候'
                                                : '正在保存修改，请稍候',
                                          );
                                          return;
                                        }
                                        if (!(formKey.currentState
                                                ?.validate() ??
                                            false)) {
                                          return;
                                        }

                                        setSheetState(() {
                                          isSubmitting = true;
                                        });
                                        final payload = HealthProfilePayload(
                                          name: name.trim(),
                                          relation: selectedPreset.backendValue,
                                          gender: gender,
                                          age: age,
                                          medicalHistory: _nullableText(
                                            medicalHistory,
                                          ),
                                          allergies: _nullableText(allergies),
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
                                          if (!mounted ||
                                              !sheetContext.mounted) {
                                            return;
                                          }
                                          Navigator.of(sheetContext).pop(
                                            _ProfileEditorResult.saved(
                                              profile: savedProfile,
                                              isCreate: profile == null,
                                            ),
                                          );
                                        } catch (error) {
                                          if (!mounted) {
                                            return;
                                          }
                                          _showErrorMessage(
                                            ApiService.extractErrorMessage(
                                              error,
                                              fallback: profile == null
                                                  ? '创建档案失败'
                                                  : '更新档案失败',
                                            ),
                                          );
                                          if (sheetContext.mounted) {
                                            setSheetState(() {
                                              isSubmitting = false;
                                            });
                                          }
                                        }
                                      },
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(
                                          double.infinity,
                                          56,
                                        ),
                                        backgroundColor: AppTheme.primaryColor,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSubmitting) ...[
                                            const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                          Text(
                                            isSubmitting
                                                ? (profile == null
                                                      ? '保存中...'
                                                      : '保存修改中...')
                                                : (profile == null
                                                      ? '保存'
                                                      : '保存修改'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    await _loadArchiveData();
    if (!mounted) {
      return;
    }

    if (result.savedProfile case final savedProfile?) {
      setState(() {
        _selectedProfileId = savedProfile.id;
      });
      _showSuccessMessage(
        result.isCreate
            ? '已添加${_displayName(savedProfile)}的档案'
            : '已更新${_displayName(savedProfile)}的档案',
      );
      return;
    }

    if (result.deletedProfile case final deletedProfile?) {
      if (_selectedProfileId == deletedProfile.id) {
        setState(() {
          _selectedProfileId = _resolveSelectedProfileId(_profiles);
        });
      }
      _showSuccessMessage('已删除${_displayName(deletedProfile)}的档案');
    }
  }

  Future<void> _deleteProfile({
    required HealthProfile profile,
    required String token,
    required BuildContext sheetContext,
    required ValueChanged<bool> setSubmitting,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除该档案？'),
        content: Text('删除后将无法恢复，${_displayName(profile)} 的健康记录入口也会一起移除。'),
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

    setSubmitting(true);
    try {
      await _apiService.deleteProfile(token: token, profileId: profile.id);
      if (!mounted || !sheetContext.mounted) {
        return;
      }
      Navigator.of(sheetContext).pop(_ProfileEditorResult.deleted(profile));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '删除档案失败'),
      );
      setSubmitting(false);
    }
  }

  Future<void> _confirmDeleteRecord(SavedConsultationRecord record) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除问诊记录？'),
        content: const Text('删除后将无法恢复，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await _deleteConsultationRecord(record);
  }

  Future<void> _deleteConsultationRecord(SavedConsultationRecord record) async {
    final token = _observedToken;
    if (token == null || token.isEmpty) {
      await _redirectToLoginForArchive(message: '登录后才能管理健康档案，是否前往登录？');
      return;
    }

    try {
      await _apiService.deleteConsultationRecord(
        token: token,
        recordId: record.id,
      );
      if (!mounted) {
        return;
      }

      final remainingRecords = _records
          .where((item) => item.id != record.id)
          .toList(growable: false);
      setState(() {
        _records = remainingRecords;
      });

      try {
        await _storageService.writeConsultationRecords(remainingRecords);
      } catch (_) {}

      try {
        final profiles = _sortProfiles(await _apiService.fetchProfiles(token));
        if (!mounted) {
          return;
        }

        setState(() {
          _profiles = profiles;
          _selectedProfileId = _resolveSelectedProfileId(profiles);
        });
        try {
          await _storageService.writeProfiles(profiles);
        } catch (_) {}
      } catch (refreshError) {
        if (!mounted) {
          return;
        }
        if (_isUnauthorizedError(refreshError)) {
          await _redirectToLoginForArchive(message: '当前登录状态已失效，请重新登录后查看健康档案。');
          return;
        }
      }

      if (!mounted) {
        return;
      }
      _showSuccessMessage('已删除问诊记录');
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorizedError(error)) {
        await _redirectToLoginForArchive(message: '当前登录状态已失效，请重新登录后查看健康档案。');
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '删除问诊记录失败'),
      );
    }
  }

  void _showRecordDetails(SavedConsultationRecord record) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_recordProfileName(record)),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRecordDetailBlock(
                  context: dialogContext,
                  title: '记录时间',
                  content: _formatDateTime(record.createdAt),
                ),
                const SizedBox(height: 12),
                _buildRecordDetailBlock(
                  context: dialogContext,
                  title: '问诊摘要',
                  content: record.summary,
                ),
                const SizedBox(height: 12),
                _buildRecordDetailBlock(
                  context: dialogContext,
                  title: '病情分析',
                  content: record.analysis,
                ),
                const SizedBox(height: 12),
                _buildRecordDetailBlock(
                  context: dialogContext,
                  title: '推荐科室',
                  content: record.recommendedDepartment,
                ),
                const SizedBox(height: 12),
                _buildRecordDetailBlock(
                  context: dialogContext,
                  title: '就医建议',
                  content: record.hospitalSuggestion,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF3F0FB),
      appBar: AppBar(
        title: const Text('健康档案'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => _refreshIndicatorKey.currentState?.show(),
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新档案',
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProfileEditor(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 10,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 34),
      ),
      bottomNavigationBar: _buildBottomBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _loadArchiveData,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 108),
                    children: [
                      _buildHeroSection(context),
                      Transform.translate(
                        offset: const Offset(0, -18),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7FC),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x12000000),
                                  blurRadius: 26,
                                  offset: Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                18,
                                14,
                                18,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child:
                                    _selectedBottomSection ==
                                        _archiveSectionLabel
                                    ? _buildArchiveSection(context)
                                    : _buildHealthDataSection(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProfile = _selectedProfile;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 38),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFDAD5F9), Color(0xFFECE8FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedProfile == null
                ? '管理你和家人的健康资料'
                : '当前查看 ${_heroDisplayName(selectedProfile)} 的档案',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryDarkColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (_profiles.isEmpty)
            _buildEmptyProfilesCard(context)
          else
            SizedBox(
              height: 84,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _profiles.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) =>
                          _buildMemberChip(context, _profiles[index]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildNameVisibilityBubble(context),
                  const SizedBox(width: 10),
                  _buildAddMemberBubble(context),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArchiveSection(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProfile = _selectedProfile;

    return Column(
      key: const ValueKey<String>('archive'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '健康档案',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            // FilledButton.tonalIcon(
            //   onPressed: () => _showSuccessMessage('我的药箱功能正在完善中，后续会接入处方与用药管理。'),
            //   icon: const Icon(Icons.medication_outlined, size: 18),
            //   label: const Text('我的药箱'),
            // ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _archiveCategoryLabels.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildArchiveTabChip(
                      context: context,
                      keyValue: entry.key,
                      label: entry.value,
                      count: _categoryCount(entry.key),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 18),
        if (_filteredArchiveRecords.isEmpty)
          _buildArchiveEmptyState(context, selectedProfile)
        else
          ..._filteredArchiveRecords.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRecordCard(context, record),
            ),
          ),
      ],
    );
  }

  Widget _buildHealthDataSection(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _selectedProfile;

    return Column(
      key: const ValueKey<String>('health'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '健康数据',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '从档案基础信息、既往病史和过敏信息中，快速了解当前成员的健康状态。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (profile == null)
          _buildEmptyRecordsCard(context, null)
        else ...[
          _buildSelectedProfileCard(context, profile),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildHealthMetricCard(
                  context: context,
                  icon: Icons.favorite_border_rounded,
                  title: '健康标签',
                  value: _relationLabel(profile),
                  subtitle: '家庭角色',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHealthMetricCard(
                  context: context,
                  icon: Icons.calendar_month_outlined,
                  title: '年龄',
                  value: '${profile.age} 岁',
                  subtitle: '档案年龄',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHealthMetricCard(
                  context: context,
                  icon: Icons.folder_copy_outlined,
                  title: '健康记录',
                  value: '${_displayedRecords.length} 条',
                  subtitle: '已归档',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHealthMetricCard(
                  context: context,
                  icon: Icons.shield_outlined,
                  title: '过敏风险',
                  value: _hasText(profile.allergies) ? '已记录' : '未填写',
                  subtitle: '安全提示',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSoftPanel(
            context: context,
            title: '既往病史',
            icon: Icons.medical_information_outlined,
            content: _cleanText(profile.medicalHistory, fallback: '暂未填写'),
          ),
          const SizedBox(height: 12),
          _buildSoftPanel(
            context: context,
            title: '过敏信息',
            icon: Icons.warning_amber_rounded,
            content: _cleanText(profile.allergies, fallback: '暂未填写'),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedProfileCard(
    BuildContext context,
    HealthProfile profile,
  ) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6E63FF), Color(0xFF8A80FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _chipAvatarName(profile),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(profile),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_relationLabel(profile)} · ${profile.gender} · ${profile.age} 岁',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showProfileEditor(profile: profile),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildWhiteInfoChip(
                  icon: Icons.folder_outlined,
                  label: '健康记录 ${_displayedRecords.length}',
                ),
                if (_hasText(profile.medicalHistory))
                  _buildWhiteInfoChip(
                    icon: Icons.monitor_heart_outlined,
                    label: '已填写病史',
                  ),
                if (_hasText(profile.allergies))
                  _buildWhiteInfoChip(
                    icon: Icons.warning_amber_outlined,
                    label: '已填写过敏信息',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetricCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoftPanel({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String content,
  }) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1ECFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveTabChip({
    required BuildContext context,
    required String keyValue,
    required String label,
    required int count,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedArchiveCategory == keyValue;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedArchiveCategory = keyValue;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0ECFF) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE8E6F4),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.primaryDarkColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFFF2F2FA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveEmptyState(
    BuildContext context,
    HealthProfile? selectedProfile,
  ) {
    final theme = Theme.of(context);
    final title = switch (_selectedArchiveCategory) {
      'prescription' => '还没有门诊处方',
      'report' => '还没有体检报告',
      _ => selectedProfile == null ? '还没有健康记录' : '当前成员还没有健康记录',
    };
    final description = switch (_selectedArchiveCategory) {
      'prescription' => '后续接入处方能力后，这里会按成员沉淀处方记录。',
      'report' => '后续可上传和整理体检报告，支持家庭成员分别管理。',
      _ =>
        selectedProfile == null
            ? '在 AI 导诊保存问诊总结后，这里会自动沉淀为问诊记录。'
            : '继续以 ${_heroDisplayName(selectedProfile)} 的身份发起问诊并保存总结，这里会自动归档。',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEAE6FF), Color(0xFFF9F7FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.medical_information_outlined,
                  size: 54,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFFADB2C6),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFB9BDD0),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '档案内容仅供您本人使用，我们将严格保护您的隐私安全',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    SavedConsultationRecord record,
  ) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _showRecordDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1ECFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cleanText(record.summary, fallback: 'AI 导诊问诊记录'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_recordProfileName(record)} · ${_formatDateTime(record.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<_RecordCardAction>(
                        tooltip: '更多操作',
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Color(0xFFB5B3C6),
                        ),
                        onSelected: (action) {
                          switch (action) {
                            case _RecordCardAction.delete:
                              unawaited(_confirmDeleteRecord(record));
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<_RecordCardAction>(
                            value: _RecordCardAction.delete,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '删除',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFB5B3C6),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRecordMetaChip(
                    context,
                    icon: Icons.local_hospital_outlined,
                    label: _cleanText(
                      record.recommendedDepartment,
                      fallback: '待定科室',
                    ),
                  ),
                  _buildRecordMetaChip(
                    context,
                    icon: Icons.person_outline_rounded,
                    label: _relationLabelByValue(record.relation),
                  ),
                ],
              ),
              if (_hasText(record.analysis)) ...[
                const SizedBox(height: 12),
                Text(
                  _cleanText(record.analysis, fallback: ''),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
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
    );
  }

  Widget _buildRecordMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildMemberChip(BuildContext context, HealthProfile profile) {
    final theme = Theme.of(context);
    final isSelected = profile.id == _selectedProfileId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProfileId = profile.id;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF5B57F7), Color(0xFF7A71FF)],
                    )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x255B57F7),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _chipAvatarName(profile),
                        style: const TextStyle(
                          color: AppTheme.primaryDarkColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _chipDisplayName(profile),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.primaryDarkColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _relationLabel(profile),
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6A6780),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMemberBubble(BuildContext context) {
    return GestureDetector(
      onTap: () => _showProfileEditor(),
      child: Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: AppTheme.primaryDarkColor),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      padding: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SizedBox(
              height: 82,
              child: Row(
                children: [
                  Expanded(
                    child: _buildBottomBarItem(
                      context: context,
                      icon: Icons.favorite_border_rounded,
                      label: '健康数据',
                      selected: _selectedBottomSection == _healthSectionLabel,
                      onTap: () {
                        setState(() {
                          _selectedBottomSection = _healthSectionLabel;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 68),
                  Expanded(
                    child: _buildBottomBarItem(
                      context: context,
                      icon: Icons.folder_copy_outlined,
                      label: '健康档案',
                      selected: _selectedBottomSection == _archiveSectionLabel,
                      onTap: () {
                        setState(() {
                          _selectedBottomSection = _archiveSectionLabel;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = selected
        ? AppTheme.primaryColor
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteBanner(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF625BFF), Color(0xFF7B72FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.group_add_outlined, color: Colors.white),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '邀请家人共享健康档案共同管理',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => _showSuccessMessage('邀请功能开发中，后续会支持邀请家人协同管理。'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 40),
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('去邀请'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationPresetChip({
    required BuildContext context,
    required _RelationPreset preset,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 86),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECE8FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFFE6E1F5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              preset.icon,
              size: 16,
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.primaryDarkColor,
            ),
            const SizedBox(width: 6),
            Text(
              preset.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? AppTheme.primaryColor
                    : AppTheme.primaryDarkColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelector({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFFE6E1F5),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryColor
                      : const Color(0xFFC9C3DD),
                  width: 1.4,
                ),
              ),
              child: selected
                  ? const Center(
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthDateField({
    required BuildContext context,
    required DateTime birthDate,
    required int age,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE6E1F5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatBirthDate(birthDate),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1ECFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$age 岁',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildEmptyProfilesCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.badge_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '还没有健康档案',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '先创建本人或家人的档案，后续问诊记录会自动按成员归档。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecordsCard(
    BuildContext context,
    HealthProfile? selectedProfile,
  ) {
    final theme = Theme.of(context);
    final title = selectedProfile == null ? '还没有健康数据' : '当前成员还没有健康数据';
    final description = selectedProfile == null
        ? '先创建成员档案或在 AI 导诊中积累问诊记录，这里会逐步沉淀健康信息。'
        : '补充 ${_displayName(selectedProfile)} 的病史、过敏信息，或继续问诊后再回来查看。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1ECFF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              color: AppTheme.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordDetailBlock({
    required BuildContext context,
    required String title,
    required String? content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(_cleanText(content, fallback: '暂无内容')),
      ],
    );
  }

  _RelationPreset _initialRelationPreset(
    HealthProfile? profile, {
    required bool hasSelfProfile,
  }) {
    if (profile == null) {
      return _relationPresets.firstWhere(
        (preset) => hasSelfProfile
            ? preset.backendValue != 'self'
            : preset.backendValue == 'self',
      );
    }

    for (final preset in _relationPresets) {
      if (preset.backendValue == profile.relation) {
        return preset;
      }
    }
    return _relationPresets.last;
  }

  String _relationLabel(HealthProfile profile) {
    if (profile.relation == 'spouse' && profile.gender == '男') {
      return '老公';
    }
    if (profile.relation == 'spouse' && profile.gender == '女') {
      return '老婆';
    }
    if (profile.relation == 'child' && profile.gender == '男') {
      return '儿子';
    }
    if (profile.relation == 'child' && profile.gender == '女') {
      return '女儿';
    }
    return _relationOptions[profile.relation] ?? profile.relation;
  }

  String _relationLabelByValue(String relation) {
    return _relationOptions[relation] ?? relation;
  }

  String _displayName(HealthProfile profile) {
    if (_isNameVisible) {
      final name = profile.name.trim();
      return name.isEmpty ? '成员' : name;
    }
    return maskName(profile.name, fallback: '成员');
  }

  /// 顶部成员胶囊里只显示脱敏姓名（如"张**"），眼睛切换后才显示全名。
  String _chipDisplayName(HealthProfile profile) {
    return _displayName(profile);
  }

  /// 成员胶囊左侧圆圈里只显示姓氏（脱敏状态保持不变）。
  String _chipAvatarName(HealthProfile profile) {
    final normalized = profile.name.trim();
    if (normalized.isEmpty) {
      return '成';
    }
    return String.fromCharCode(normalized.runes.first);
  }

  /// 顶部“当前查看 xx 的档案”里只显示脱敏姓名（如"张**"），眼睛切换后显示全名。
  String _heroDisplayName(HealthProfile profile) {
    return _displayName(profile);
  }

  Widget _buildNameVisibilityBubble(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isNameVisible = !_isNameVisible;
        });
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          _isNameVisible
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: AppTheme.primaryDarkColor,
        ),
      ),
    );
  }

  String _recordProfileName(SavedConsultationRecord record) {
    if (_isNameVisible) {
      final name = record.profileName.trim();
      return name.isEmpty ? '成员' : name;
    }
    return maskName(record.profileName, fallback: '成员');
  }

  String _normalizeGender(String? gender) {
    if (gender == '男' || gender == '女') {
      return gender!;
    }
    return '男';
  }

  DateTime _estimateBirthDateFromAge(int age) {
    final now = DateTime.now();
    return DateTime(now.year - age, now.month, now.day);
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hasBirthdayThisYear =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasBirthdayThisYear) {
      age -= 1;
    }
    return age.clamp(0, 120);
  }

  String _formatBirthDate(DateTime birthDate) {
    final year = birthDate.year.toString().padLeft(4, '0');
    final month = birthDate.month.toString().padLeft(2, '0');
    final day = birthDate.day.toString().padLeft(2, '0');
    return '$year年$month月$day日';
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

  String? _nullableText(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  void _showInfoMessage(String message) {
    AppMessage.showInfo(context, message);
  }

  void _showSuccessMessage(String message) {
    AppMessage.showSuccess(context, message);
  }

  void _showErrorMessage(String message) {
    AppMessage.showError(context, message);
  }

  bool _hasUsableSession(AuthProvider authProvider) {
    final token = authProvider.token?.trim();
    return token != null &&
        token.isNotEmpty &&
        authProvider.currentUser != null;
  }

  bool _isUnauthorizedError(Object error) {
    if (error is DioException) {
      return error.response?.statusCode == 401;
    }
    final message = error.toString().toLowerCase();
    return message.contains('401') || message.contains('unauthorized');
  }

  Future<void> _redirectToLoginForArchive({required String message}) async {
    if (!mounted || _isRedirectingToLogin) {
      return;
    }
    _isRedirectingToLogin = true;
    setState(() {
      _profiles = <HealthProfile>[];
      _records = <SavedConsultationRecord>[];
      _selectedProfileId = null;
      _isLoading = false;
    });
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('请先登录'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
    _isRedirectingToLogin = false;
    if (!mounted || shouldLogin != true) {
      return;
    }
    context.go('/login');
  }
}

class _RelationPreset {
  const _RelationPreset({
    required this.backendValue,
    required this.label,
    required this.summaryLabel,
    required this.icon,
  });

  final String backendValue;
  final String label;
  final String summaryLabel;
  final IconData icon;
}

class _ProfileEditorResult {
  const _ProfileEditorResult.saved({
    required this.profile,
    required this.isCreate,
  }) : deletedProfile = null;

  const _ProfileEditorResult.deleted(this.deletedProfile)
    : profile = null,
      isCreate = false;

  final HealthProfile? profile;
  final HealthProfile? deletedProfile;
  final bool isCreate;

  HealthProfile? get savedProfile => profile;
}
