import 'package:flutter/material.dart';
import 'dart:io' as io;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';
import '../services/agreement_service.dart';
import '../services/api_service.dart';
import '../services/app_storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/privacy_formatter.dart';
import '../widgets/account_avatar.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_message.dart';

const _supportEmail = 'shibinbin@sstkjsxgfyxgs.wecom.work';
const _harmonyMediaChannel = MethodChannel('hospital/media_permission');
const _appVersionLabel = 'V1.0';
const _accountDeactivationDescription = '注销账号将失去您已在三十天时刻智护所有的健康档案和咨询记录等信息';

class AccountCenterScreen extends StatelessWidget {
  const AccountCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = context.watch<AuthProvider>().currentUser;
    if (currentUser == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text('我的'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEDE8FF), Color(0xFFF8F6FC)],
          ),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _ProfileHeroCard(
                  user: currentUser,
                  onTap: () => context.push('/account/edit'),
                ),
                const SizedBox(height: 18),
                _MenuGroupCard(
                  children: [
                    _AccountMenuTile(
                      icon: Icons.badge_outlined,
                      title: '我的资料',
                      subtitle: '编辑昵称与头像，完善基础资料',
                      onTap: () => context.push('/account/edit'),
                    ),
                    _AccountMenuTile(
                      icon: Icons.favorite_border_rounded,
                      title: '健康管理',
                      subtitle: '查看并维护我的健康档案',
                      onTap: () => context.push('/health-archive'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _MenuGroupCard(
                  children: [
                    _AccountMenuTile(
                      icon: Icons.settings_outlined,
                      title: '设置',
                      subtitle: '通知、提醒与隐私开关',
                      onTap: () => context.push('/account/settings'),
                    ),
                    _AccountMenuTile(
                      icon: Icons.info_outline_rounded,
                      title: '关于',
                      subtitle: '了解应用版本与服务说明',
                      onTap: () => context.push('/account/about'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '值得托付的健康管家',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDarkColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '你可以在这里维护个人资料、查看健康档案、管理隐私设置。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditAccountProfileScreen extends StatefulWidget {
  const EditAccountProfileScreen({super.key});

  @override
  State<EditAccountProfileScreen> createState() =>
      _EditAccountProfileScreenState();
}

class _EditAccountProfileScreenState extends State<EditAccountProfileScreen> {
  late final TextEditingController _nameController;
  String? _selectedAvatarKey;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      return;
    }
    if (_nameController.text.isEmpty) {
      _nameController.text = currentUser.displayName;
      _selectedAvatarKey =
          currentUser.avatarKey ?? accountAvatarPresets.first.key;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return;
    }
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      AppMessage.showWarning(context, '请输入昵称');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await authProvider.updateCurrentUserProfile(
        displayName: displayName,
        avatarKey: _selectedAvatarKey,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      AppMessage.showWarning(
        context,
        ApiService.extractErrorMessage(error, fallback: '保存资料失败，请稍后重试'),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });
    AppMessage.showSuccess(context, '个人资料已更新');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = context.watch<AuthProvider>().currentUser;
    if (currentUser == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final selectedAvatarKey =
        _selectedAvatarKey ?? accountAvatarPresets.first.key;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FD),
      appBar: AppBar(title: const Text('我的资料'), centerTitle: true),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF0EAFF), Color(0xFFF8F5FF)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    AccountAvatar(
                      name: _nameController.text.trim().isEmpty
                          ? currentUser.displayName
                          : _nameController.text.trim(),
                      avatarKey: selectedAvatarKey,
                      radius: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      maskPhoneNumber(currentUser.phone, fallback: '未绑定手机号'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _EditorCard(
                title: '昵称',
                child: TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    hintText: '请输入你的昵称',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 18),
              _EditorCard(
                title: '头像风格',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: accountAvatarPresets
                      .map((preset) {
                        final selected = preset.key == selectedAvatarKey;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAvatarKey = preset.key;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 88,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppTheme.primaryColor.withValues(
                                      alpha: 0.10,
                                    )
                                  : theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: selected
                                    ? AppTheme.primaryColor
                                    : theme.colorScheme.outlineVariant,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                AccountAvatar(
                                  name: _nameController.text.trim().isEmpty
                                      ? currentUser.displayName
                                      : _nameController.text.trim(),
                                  avatarKey: preset.key,
                                  radius: 22,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  preset.label,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: selected
                                        ? AppTheme.primaryDarkColor
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: AppTheme.primaryDarkColor,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('保存资料'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final AppStorageService _storageService = AppStorageService.instance;

  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _healthReminderEnabled = true;
  bool _privacyModeEnabled = false;
  bool _isDeactivatingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final results = await Future.wait<bool>([
      _storageService.readNotificationsEnabled(),
      _storageService.readHealthReminderEnabled(),
      _storageService.readPrivacyModeEnabled(),
    ]);
    // HarmonyOS does not expose notification authorization through
    // permission_handler.  A MissingPluginException/unsupported status must
    // not be treated as a denied permission, otherwise an already-authorized
    // user is incorrectly sent to system settings.
    bool isGranted = results[0];
    if (io.Platform.operatingSystem == 'ohos') {
      try {
        isGranted = await _harmonyMediaChannel.invokeMethod<bool>('notificationEnabled') ?? results[0];
      } catch (_) {
        isGranted = results[0];
      }
    }
    try {
      if (io.Platform.operatingSystem != 'ohos') {
        final status = await Permission.notification.status;
        isGranted = status.isGranted;
      }
    } catch (_) {
      isGranted = results[0];
    }

    if (isGranted != results[0]) {
      await _storageService.writeNotificationsEnabled(isGranted);
      results[0] = isGranted;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _notificationsEnabled = results[0];
      _healthReminderEnabled = results[1];
      _privacyModeEnabled = results[2];
      _isLoading = false;
    });
  }

  Future<void> _updateSwitch({
    required bool value,
    required Future<void> Function(bool value) writer,
    required void Function(bool value) updateState,
  }) async {
    setState(() {
      updateState(value);
    });
    await writer(value);
  }

  Future<void> _toggleNotificationPermission(bool value) async {
    if (value) {
      if (io.Platform.operatingSystem == 'ohos') {
        try {
          final granted = await _harmonyMediaChannel.invokeMethod<bool>('requestNotification') ?? false;
          if (granted) {
            await _updateSwitch(
              value: true,
              writer: _storageService.writeNotificationsEnabled,
              updateState: (nextValue) => _notificationsEnabled = nextValue,
            );
          } else if (mounted) {
            AppMessage.showWarning(context, '请前往系统设置开启消息通知');
          }
        } catch (_) {
          if (mounted) AppMessage.showWarning(context, '请前往系统设置开启消息通知');
        }
        return;
      }
      PermissionStatus status = PermissionStatus.denied;
      var permissionCheckSupported = true;
      try {
        status = await Permission.notification.request();
      } catch (_) {
        // permission_handler has no HarmonyOS notification implementation.
        // Notification access is managed by the system and should not be
        // reported as denied merely because this optional API is unavailable.
        permissionCheckSupported = false;
      }
      if (!permissionCheckSupported || status.isGranted) {
        await _updateSwitch(
          value: true,
          writer: _storageService.writeNotificationsEnabled,
          updateState: (nextValue) {
            _notificationsEnabled = nextValue;
          },
        );
      } else {
        if (mounted) {
          AppMessage.showWarning(context, '如需开启消息通知，请前往系统设置授权');
          await openAppSettings();
        }
        setState(() {});
      }
    } else {
      await _updateSwitch(
        value: false,
        writer: _storageService.writeNotificationsEnabled,
        updateState: (nextValue) {
          _notificationsEnabled = nextValue;
        },
      );
      if (mounted) {
        AppMessage.showInfo(context, '已在应用内关闭通知。如需彻底关闭，可前往系统设置');
      }
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  Future<void> _handleDeactivateAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (dialogContext) => const _DeactivateAccountConfirmationPage(),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeactivatingAccount = true;
    });

    try {
      await context.read<AuthProvider>().deactivateAccount();
      if (!mounted) {
        return;
      }
      context.go('/login');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDeactivatingAccount = false;
      });
      AppMessage.showError(
        context,
        ApiService.extractErrorMessage(error, fallback: '账号注销失败，请稍后重试'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FD),
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _MenuGroupCard(
                      children: [
                        _SettingSwitchTile(
                          icon: Icons.notifications_none_rounded,
                          title: '消息通知',
                          subtitle: '接收系统与服务动态提醒',
                          value: _notificationsEnabled,
                          onChanged: _toggleNotificationPermission,
                        ),
                        _SettingSwitchTile(
                          icon: Icons.monitor_heart_outlined,
                          title: '健康提醒',
                          subtitle: '接收档案和健康管理提醒',
                          value: _healthReminderEnabled,
                          onChanged: (value) => _updateSwitch(
                            value: value,
                            writer: _storageService.writeHealthReminderEnabled,
                            updateState: (nextValue) {
                              _healthReminderEnabled = nextValue;
                            },
                          ),
                        ),
                        _SettingSwitchTile(
                          icon: Icons.lock_outline_rounded,
                          title: '隐私模式',
                          subtitle: '尽量隐藏敏感信息展示',
                          value: _privacyModeEnabled,
                          onChanged: (value) => _updateSwitch(
                            value: value,
                            writer: _storageService.writePrivacyModeEnabled,
                            updateState: (nextValue) {
                              _privacyModeEnabled = nextValue;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _MenuGroupCard(
                      children: [
                        _SettingActionTile(
                          icon: Icons.shield_outlined,
                          title: '协议与隐私',
                          subtitle: '查看用户协议与隐私政策',
                          onTap: () => context.push('/account/policies'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _MenuGroupCard(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          leading: const Icon(
                            Icons.receipt_long_outlined,
                            color: AppTheme.primaryDarkColor,
                          ),
                          title: Text(
                            '晋ICP备2026008725号-2A',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '备案信息',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '安全建议',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '建议在个人设备上开启隐私模式，避免在公共环境中展示'
                            '手机号、健康档案与问诊记录。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _MenuGroupCard(
                      children: [
                        _SettingActionTile(
                          icon: Icons.person_remove_outlined,
                          title: '账号注销',
                          subtitle: _accountDeactivationDescription,
                          isDestructive: true,
                          isLoading: _isDeactivatingAccount,
                          onTap: _isDeactivatingAccount
                              ? null
                              : _handleDeactivateAccount,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _isDeactivatingAccount ? null : _handleLogout,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(
                          color: theme.colorScheme.errorContainer,
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('退出登录'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class AgreementsPrivacyScreen extends StatefulWidget {
  const AgreementsPrivacyScreen({super.key});

  @override
  State<AgreementsPrivacyScreen> createState() =>
      _AgreementsPrivacyScreenState();
}

class _AgreementsPrivacyScreenState extends State<AgreementsPrivacyScreen> {
  String _selectedType = 'user_agreement';
  String? _userAgreementContent;
  String? _privacyPolicyContent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAgreements();
  }

  Future<void> _fetchAgreements() async {
    setState(() => _isLoading = true);
    try {
      final agreementService = AgreementService(context.read<ApiService>());
      final userAgreement = await agreementService.getAgreement(
        'user_agreement',
      );
      final privacyPolicy = await agreementService.getAgreement(
        'privacy_policy',
      );

      if (mounted) {
        setState(() {
          _userAgreementContent = userAgreement?.isNotEmpty == true
              ? userAgreement
              : null;
          _privacyPolicyContent = privacyPolicy?.isNotEmpty == true
              ? privacyPolicy
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userAgreementContent = null;
          _privacyPolicyContent = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _selectedType == 'user_agreement' ? '用户协议' : '隐私政策';
    final content = _selectedType == 'user_agreement'
        ? _userAgreementContent
        : _privacyPolicyContent;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FD),
      appBar: AppBar(title: const Text('协议与隐私'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<String>(
                            value: 'user_agreement',
                            label: Text('用户协议'),
                          ),
                          ButtonSegment<String>(
                            value: 'privacy_policy',
                            label: Text('隐私政策'),
                          ),
                        ],
                        selected: <String>{_selectedType},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _selectedType = selection.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (content != null)
                            Text(
                              content,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.75,
                              ),
                            )
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.cloud_off_rounded,
                                      size: 48,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '未获取到协议内容',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: _fetchAgreements,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('重试'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FD),
      appBar: AppBar(title: const Text('关于'), centerTitle: true),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEDE7FF), Color(0xFFF9F5FF)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    const AppLogo(size: 72, borderRadius: 22, shadows: []),
                    const SizedBox(height: 14),
                    Text(
                      '三十天时刻智护',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryDarkColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '版本号 $_appVersionLabel',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _MenuGroupCard(
                children: const [
                  _StaticInfoTile(title: '产品定位', value: '值得信赖的个人健康管理助手'),
                  _StaticInfoTile(title: '服务能力', value: 'AI 问诊、档案沉淀、家庭健康管理'),
                  _StaticInfoTile(title: '联系邮箱', value: _supportEmail),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.user, required this.onTap});

  final CurrentUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF3EEFF), Color(0xFFFFFFFF)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE4DBFF)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                AccountAvatar(
                  name: user.displayName,
                  avatarKey: user.avatarKey,
                  radius: 30,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        maskName(user.displayName, fallback: '用户'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDarkColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '值得托付的健康管家',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        maskPhoneNumber(user.phone, fallback: '未绑定手机号'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuGroupCard extends StatelessWidget {
  const _MenuGroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(children: children),
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Icon(icon, color: AppTheme.primaryDarkColor),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  const _SettingSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      secondary: Icon(icon, color: AppTheme.primaryDarkColor),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SettingActionTile extends StatelessWidget {
  const _SettingActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = isDestructive
        ? theme.colorScheme.error
        : AppTheme.primaryDarkColor;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      enabled: onTap != null && !isLoading,
      leading: Icon(icon, color: effectiveColor),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDestructive ? theme.colorScheme.error : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: isLoading ? null : onTap,
    );
  }
}

class _DeactivateAccountConfirmationPage extends StatelessWidget {
  const _DeactivateAccountConfirmationPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FE),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              tooltip: '返回',
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                              ),
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '注销账号',
                              maxLines: 1,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF191923),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 34, 28, 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 48, 24, 42),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const _DeactivateAccountIllustration(),
                          const SizedBox(height: 34),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '账号注销将清空全部信息',
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1D1D28),
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 58),
                          _DeactivateAccountNotice(
                            index: '1.',
                            text: '注销后，您的账号信息、身份信息、会员权益、健康档案、咨询记录等信息将被清空且无法恢复。',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 8, 40, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF383849),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('确认注销'),
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
}

class _DeactivateAccountIllustration extends StatelessWidget {
  const _DeactivateAccountIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EEFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6D63FF).withAlpha(24),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_off_rounded,
              size: 58,
              color: Color(0xFF6A61E8),
            ),
          ),
          Positioned(
            right: 20,
            top: 8,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1E1E2B), width: 4),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFE34A4A),
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeactivateAccountNotice extends StatelessWidget {
  const _DeactivateAccountNotice({required this.index, required this.text});

  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(
      color: const Color(0xFF2A2A36),
      height: 1.72,
      fontWeight: FontWeight.w500,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(index, style: style),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

class _StaticInfoTile extends StatelessWidget {
  const _StaticInfoTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
