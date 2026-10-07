import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart' as aitk;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:genui/genui.dart' as genui;
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../router/app_route_observer.dart';
import '../providers/auth_provider.dart';
import '../providers/consultation_chat_provider.dart';
import '../providers/hot_questions_provider.dart';
import '../services/api_service.dart';
import '../services/app_storage_service.dart';
import '../utils/privacy_formatter.dart';
import '../widgets/account_avatar.dart';
import '../widgets/app_logo.dart';
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

const _genderOptions = <String>['男', '女', '未填写'];
const _hotQuestionPrompts = <String>[
  '人每天要喝八杯水？',
  '泡脚改善气血不足是否有科学依据？',
  '如何调理脾虚？',
];
const _chatContentBottomSpacing = 58.0;
const _chatMessageSpacing = 8.0;
const _harmonyMediaChannel = MethodChannel('hospital/media_permission');
const _chatSpeakerChangeSpacing = 18.0;
const _chatScrollToBottomAutoFollowThreshold = 96.0;
const _chatScrollToBottomVisibleThreshold = 120.0;
const _chatScrollToBottomButtonBottomOffset = 62.0;

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.profileId,
    this.initialSessionId,
    this.initialQuestion,
  });

  final int? profileId;
  final int? initialSessionId;
  final String? initialQuestion;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _CardPayload {
  final String type;
  final Map<String, dynamic> data;

  const _CardPayload({required this.type, required this.data});

  static _CardPayload? parse(String text) {
    String? rawJson;
    final cardMatch = RegExp(r'\[CARD\]([\s\S]*?)\[/CARD\]').firstMatch(text);
    if (cardMatch != null) {
      rawJson = cardMatch.group(1);
    } else {
      final jsonMatch = RegExp(
        r'```json\s*(\{[\s\S]*?"type"\s*:\s*"(?:question_options|medical_result)"[\s\S]*?\})\s*```',
        caseSensitive: false,
      ).firstMatch(text);
      if (jsonMatch != null) {
        rawJson = jsonMatch.group(1);
      } else {
        final plainMatch = RegExp(
          r'(\{[\s\S]*?"type"\s*:\s*"(?:question_options|medical_result)"[\s\S]*?\})\s*$',
          caseSensitive: false,
        ).firstMatch(text);
        if (plainMatch != null) {
          rawJson = plainMatch.group(1);
        }
      }
    }

    if (rawJson != null) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, dynamic>) {
          final type = decoded['type'] as String?;
          final data = decoded['data'];
          if (type != null && data is Map<String, dynamic>) {
            return _CardPayload(type: type, data: data);
          }
        }
      } catch (_) {}
    }
    return null;
  }
}

class _ChatScreenState extends State<ChatScreen> with RouteAware {
  static const _resultSurfaceId = 'consultation_result_surface';

  final ApiService _apiService = ApiService();
  final AppStorageService _storageService = AppStorageService.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final genui.SurfaceController _surfaceController =
      genui.SurfaceController(catalogs: [genui.BasicCatalogItems.asCatalog()]);

  late ConsultationChatProvider _chatProvider;
  StreamSubscription<genui.ChatMessage>? _surfaceSubmitSubscription;

  String? _observedToken;
  String _mode = 'normal';
  bool _isThinking = false;
  bool _isInitializing = true;
  bool _isLoadingSessions = false;
  bool _isLoadingRecords = false;
  bool _isLoadingProfiles = false;
  bool _isRefreshingConsultationData = false;
  bool _isLoadingSessionDetail = false;
  bool _isPersistingSession = false;
  bool _isSavingConsultation = false;
  bool _isUploadingAttachment = false;
  bool _isPolishing = false;
  bool _isHydratingProviderHistory = false;
  bool _hasResolvedInitialSession = false;
  bool _isHealthSnapshotExpanded = true;
  bool _showScrollToBottomButton = false;
  bool _shouldAutoScrollOnIncomingContent = true;
  bool _useNoConsultationProfile = false;
  int? _activeSessionId;
  int? _selectedProfileId;
  String? _savedConsultationCardSignature;
  int? _savedConsultationProfileId;
  String _persistedHistorySignature = '';
  Timer? _persistDebounceTimer;
  DateTime _lastStreamingSetStateTime = DateTime(0);
  final Map<String, _CardPayload?> _cardPayloadTextCache =
      <String, _CardPayload?>{};
  final Map<String, String> _stripCardTextCache = <String, String>{};

  final Map<int, String> _assistantReasoningByMessageIndex = <int, String>{};
  final Map<int, List<_ChatMessageAttachment>>
  _messageAttachmentsByMessageIndex = <int, List<_ChatMessageAttachment>>{};
  final Map<int, List<String>> _messageContextFileIdsByMessageIndex =
      <int, List<String>>{};
  final Set<int> _streamingReasoningMessageIndexes = <int>{};
  final Set<int> _streamingAssistantMessageIndexes = <int>{};
  ModalRoute<dynamic>? _subscribedRoute;
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _chatInputController = TextEditingController();
  // 显式管理输入框焦点：呼出侧栏时先解除焦点，避免键盘意外弹出
  final FocusNode _chatInputFocusNode = FocusNode(debugLabel: 'chatInput');
  List<ChatSessionSummary> _chatSessions = <ChatSessionSummary>[];
  List<SavedConsultationRecord> _consultationRecords =
      <SavedConsultationRecord>[];
  List<HealthProfile> _profiles = <HealthProfile>[];
  ConsultationCardData? _currentCardData;
  List<_SelectedChatAttachment> _selectedAttachments =
      <_SelectedChatAttachment>[];
  Set<String> _selectedQuestionOptions = <String>{};
  final TextEditingController _customOptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chatProvider = _createChatProvider();
    _chatProvider.addListener(_onProviderHistoryChanged);
    _chatScrollController.addListener(_handleChatScroll);
    _persistedHistorySignature = _buildHistorySignature(_chatProvider.history);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollChatToBottom(animated: false));
      _updateScrollToBottomButtonVisibility();
    });
    _surfaceSubmitSubscription = _surfaceController.onSubmit.listen(
      _handleSurfaceSubmission,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && _subscribedRoute != route) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
      _subscribedRoute = route;
    }

    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) {
      return;
    }

    final nextToken = authProvider.token;
    if (_observedToken == nextToken && !_isInitializing) {
      unawaited(_refreshProfilesAndConsultationRecords());
      return;
    }

    _observedToken = nextToken;
    _chatProvider.updateConfiguration(
      mode: _mode,
      thinkingEnabled: _isThinking,
      token: nextToken,
    );
    unawaited(_refreshPageData());
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _persistDebounceTimer?.cancel();
    _throttleTimer?.cancel();
    _chatScrollController.removeListener(_handleChatScroll);
    _chatScrollController.dispose();
    _chatInputController.dispose();
    _chatInputFocusNode.dispose();
    _customOptionController.dispose();
    _surfaceSubmitSubscription?.cancel();
    _chatProvider.removeListener(_onProviderHistoryChanged);
    _chatProvider.dispose();
    _surfaceController.dispose();
    super.dispose();
  }

  @override
  void didPush() {
    unawaited(_refreshProfilesAndConsultationRecords());
  }

  @override
  void didPopNext() {
    unawaited(_refreshProfilesAndConsultationRecords());
  }

  ConsultationChatProvider _createChatProvider({
    Iterable<aitk.ChatMessage> history = const <aitk.ChatMessage>[],
  }) {
    return ConsultationChatProvider(
      baseUrl: _apiService.baseUrl,
      mode: _mode,
      thinkingEnabled: _isThinking,
      token: _observedToken,
      history: history,
      onConsultationCard: _handleConsultationCard,
    );
  }

  Future<void> _refreshPageData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isInitializing = true;
    });

    final authProvider = context.read<AuthProvider>();
    if (_observedToken == null || _observedToken!.isEmpty) {
      setState(() {
        _chatSessions = <ChatSessionSummary>[];
        _consultationRecords = <SavedConsultationRecord>[];
        _profiles = <HealthProfile>[];
        _useNoConsultationProfile = false;
        _selectedProfileId = null;
        _hasResolvedInitialSession = false;
        _isInitializing = false;
      });
      return;
    }

    await _hydrateCachedPageData();
    if (!mounted) {
      return;
    }

    await authProvider.refreshCurrentUser();
    if (!mounted) {
      return;
    }

    if (!_hasUsableSession(authProvider)) {
      _chatProvider.updateConfiguration(
        mode: _mode,
        thinkingEnabled: _isThinking,
        token: null,
      );
      setState(() {
        _chatSessions = <ChatSessionSummary>[];
        _consultationRecords = <SavedConsultationRecord>[];
        _profiles = <HealthProfile>[];
        _useNoConsultationProfile = false;
        _selectedProfileId = null;
        _hasResolvedInitialSession = false;
        _isInitializing = false;
      });
      return;
    }

    await Future.wait<void>([
      _loadProfiles(),
      _loadChatSessions(),
      _loadConsultationRecords(),
    ]);

    if (!mounted) {
      return;
    }

    if (!_hasResolvedInitialSession && widget.initialSessionId != null) {
      _hasResolvedInitialSession = true;
      final matchedSession = _chatSessions.where(
        (session) => session.id == widget.initialSessionId,
      );
      if (matchedSession.isNotEmpty) {
        await _handleSelectChatSession(matchedSession.first);
      }
      if (!mounted) {
        return;
      }
    }

    setState(() {
      _isInitializing = false;
    });
  }

  Future<void> _hydrateCachedPageData() async {
    final cachedProfiles = _sortProfiles(await _storageService.readProfiles());
    final cachedSessions = await _storageService.readChatSessions();
    final cachedRecords = await _storageService.readConsultationRecords();
    cachedSessions.sort(
      (left, right) => right.updatedAt.compareTo(left.updatedAt),
    );
    cachedRecords.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );

    if (!mounted ||
        (cachedProfiles.isEmpty &&
            cachedSessions.isEmpty &&
            cachedRecords.isEmpty)) {
      return;
    }

    setState(() {
      _profiles = cachedProfiles;
      _chatSessions = cachedSessions;
      _consultationRecords = cachedRecords;
      _selectedProfileId = _resolveSelectedProfileId(cachedProfiles);
      _isInitializing = false;
    });
  }

  Future<void> _hydrateCachedProfilesAndRecords() async {
    final cachedProfiles = _sortProfiles(await _storageService.readProfiles());
    final cachedRecords = await _storageService.readConsultationRecords();
    cachedRecords.sort(
      (left, right) => right.createdAt.compareTo(left.createdAt),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _profiles = cachedProfiles;
      _consultationRecords = cachedRecords;
      _selectedProfileId = _resolveSelectedProfileId(cachedProfiles);
    });
  }

  Future<void> _refreshProfilesAndConsultationRecords({
    bool hydrateCacheFirst = true,
  }) async {
    if (_observedToken == null ||
        _observedToken!.isEmpty ||
        _isRefreshingConsultationData) {
      return;
    }

    _isRefreshingConsultationData = true;
    try {
      if (hydrateCacheFirst) {
        await _hydrateCachedProfilesAndRecords();
      }
      if (!mounted) {
        return;
      }
      await Future.wait<void>([_loadProfiles(), _loadConsultationRecords()]);
    } finally {
      _isRefreshingConsultationData = false;
    }
  }

  Future<void> _loadProfiles() async {
    if (_observedToken == null || _observedToken!.isEmpty) {
      return;
    }

    if (_profiles.isEmpty) {
      setState(() {
        _isLoadingProfiles = true;
      });
    }

    try {
      final profiles = await _apiService.fetchProfiles(_observedToken!);
      if (!mounted) {
        return;
      }

      final sortedProfiles = _sortProfiles(profiles);
      await _storageService.writeProfiles(sortedProfiles);

      // Update selected profile ID to be valid in the new list, or fall back to default
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
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '获取健康档案失败'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfiles = false;
        });
      }
    }
  }

  Future<void> _loadChatSessions() async {
    if (_observedToken == null || _observedToken!.isEmpty) {
      return;
    }

    if (_chatSessions.isEmpty) {
      setState(() {
        _isLoadingSessions = true;
      });
    }

    try {
      final sessions = await _apiService.fetchChatSessions(_observedToken!);
      if (!mounted) {
        return;
      }
      sessions.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      await _storageService.writeChatSessions(sessions);
      setState(() {
        _chatSessions = sessions;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '获取对话历史失败'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSessions = false;
        });
      }
    }
  }

  Future<void> _loadConsultationRecords() async {
    if (_observedToken == null || _observedToken!.isEmpty) {
      return;
    }

    if (_consultationRecords.isEmpty) {
      setState(() {
        _isLoadingRecords = true;
      });
    }

    try {
      final records = await _apiService.fetchConsultationRecords(
        _observedToken!,
      );
      if (!mounted) {
        return;
      }
      records.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      await _storageService.writeConsultationRecords(records);
      setState(() {
        _consultationRecords = records;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '获取个人问诊记录失败'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecords = false;
        });
      }
    }
  }

  int? _resolveSelectedProfileId(List<HealthProfile> profiles) {
    if (_useNoConsultationProfile) {
      return null;
    }
    if (profiles.isEmpty) {
      return null;
    }

    final incomingProfileId = widget.profileId;
    if (incomingProfileId != null &&
        profiles.any((profile) => profile.id == incomingProfileId)) {
      return incomingProfileId;
    }

    if (_selectedProfileId != null &&
        profiles.any((profile) => profile.id == _selectedProfileId)) {
      return _selectedProfileId;
    }

    return profiles
        .firstWhere(
          (profile) => profile.relation == 'self',
          orElse: () => profiles.first,
        )
        .id;
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

  Future<void> _handleSelectChatSession(ChatSessionSummary session) async {
    if (_observedToken == null || _observedToken!.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingSessionDetail = true;
    });

    try {
      final detail = await _apiService.fetchChatSessionDetail(
        _observedToken!,
        session.id,
      );
      final history = _historyFromSessionMessages(detail.messages);
      final reasoningByMessageIndex =
          _reasoningByMessageIndexFromSessionMessages(detail.messages);
      final attachmentsByMessageIndex =
          _attachmentsByMessageIndexFromSessionMessages(detail.messages);
      final contextFileIdsByMessageIndex =
          _contextFileIdsByMessageIndexFromSessionMessages(detail.messages);
      final aiLabelMetaByMessageIndex =
          _aiLabelMetaByMessageIndexFromSessionMessages(detail.messages);
      final initialContextFileIds = _latestContextFileIdsFromSessionMessages(
        detail.messages,
      );
      final restoredCard = _extractLatestCardFromHistory(history);

      if (!mounted) {
        return;
      }

      setState(() {
        _mode = detail.mode;
        _activeSessionId = detail.id;
        _currentCardData = restoredCard;
        _savedConsultationCardSignature = null;
        _savedConsultationProfileId = null;
      });

      await _replaceChatProvider(
        history: history,
        reasoningByMessageIndex: reasoningByMessageIndex,
        attachmentsByMessageIndex: attachmentsByMessageIndex,
        contextFileIdsByMessageIndex: contextFileIdsByMessageIndex,
        aiLabelMetaByMessageIndex: aiLabelMetaByMessageIndex,
        initialContextFileIds: initialContextFileIds,
      );
      _updateConsultationSurface(restoredCard);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '打开对话历史失败'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSessionDetail = false;
        });
      }
    }
  }

  Future<void> _startNewConversation() async {
    setState(() {
      _activeSessionId = null;
      _currentCardData = null;
      _savedConsultationCardSignature = null;
      _savedConsultationProfileId = null;
    });
    _updateConsultationSurface(null);
    await _replaceChatProvider();
  }

  Future<void> _switchConsultationProfile({
    required bool useNoConsultationProfile,
    int? profileId,
  }) async {
    final nextProfileId = useNoConsultationProfile ? null : profileId;
    if (_useNoConsultationProfile == useNoConsultationProfile &&
        _selectedProfileId == nextProfileId) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _useNoConsultationProfile = useNoConsultationProfile;
      _selectedProfileId = nextProfileId;
    });
    await _startNewConversation();
  }

  Future<void> _openHealthMonitoring() async {
    await context.push('/health-monitoring');
  }

  Future<void> _openScan() async {
    final authProvider = context.read<AuthProvider>();
    if (!_hasUsableSession(authProvider)) {
      unawaited(_showLoginRequiredDialog(message: '登录后才能使用扫一扫，请先登录 App。'));
      return;
    }
    await context.push('/scan');
  }

  Future<void> _openHealthArchive() async {
    if (!_hasUsableSession(context.read<AuthProvider>())) {
      unawaited(_showLoginRequiredDialog(message: '登录后才能查看和管理健康档案，是否前往登录？'));
      return;
    }
    await context.push('/health-archive');
    if (!mounted) {
      return;
    }

    await _refreshProfilesAndConsultationRecords();
  }

  Future<void> _openAccountCenter() async {
    await context.push('/account');
    if (!mounted) {
      return;
    }

    final cachedProfiles = _sortProfiles(await _storageService.readProfiles());
    if (!mounted) {
      return;
    }

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
    });
    await _loadProfiles();
  }

  Future<void> _replaceChatProvider({
    Iterable<aitk.ChatMessage> history = const <aitk.ChatMessage>[],
    Map<int, String> reasoningByMessageIndex = const <int, String>{},
    Map<int, List<_ChatMessageAttachment>> attachmentsByMessageIndex =
        const <int, List<_ChatMessageAttachment>>{},
    Map<int, List<String>> contextFileIdsByMessageIndex =
        const <int, List<String>>{},
    Map<int, Map<String, dynamic>> aiLabelMetaByMessageIndex =
        const <int, Map<String, dynamic>>{},
    List<String> initialContextFileIds = const <String>[],
  }) async {
    _isHydratingProviderHistory = true;
    _chatProvider.removeListener(_onProviderHistoryChanged);
    _chatProvider.dispose();
    _chatProvider = _createChatProvider(history: history);
    for (final entry in aiLabelMetaByMessageIndex.entries) {
      _chatProvider.setAiLabelMetaForHistoryIndex(entry.key, entry.value);
    }
    _chatProvider.updateContextFileIds(initialContextFileIds);
    _chatProvider.addListener(_onProviderHistoryChanged);
    _assistantReasoningByMessageIndex
      ..clear()
      ..addAll(reasoningByMessageIndex);
    _messageAttachmentsByMessageIndex
      ..clear()
      ..addAll(attachmentsByMessageIndex);
    _cardPayloadTextCache.clear();
    _stripCardTextCache.clear();
    _messageContextFileIdsByMessageIndex
      ..clear()
      ..addAll(contextFileIdsByMessageIndex);
    _streamingReasoningMessageIndexes.clear();
    _streamingAssistantMessageIndexes.clear();
    _selectedAttachments = <_SelectedChatAttachment>[];
    _isUploadingAttachment = false;
    _persistedHistorySignature = _buildHistorySignature(history);
    _isHydratingProviderHistory = false;
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_scrollChatToBottom(animated: false));
      });
    }
  }

  void _handleConsultationCard(ConsultationCardData cardData) {
    setState(() {
      _currentCardData = cardData;
      _savedConsultationCardSignature = null;
      _savedConsultationProfileId = null;
    });
    _updateConsultationSurface(cardData);
  }

  void _updateConsultationSurface(ConsultationCardData? cardData) {
    if (cardData == null || !cardData.hasContent) {
      _surfaceController.handleMessage(
        const genui.DeleteSurface(surfaceId: _resultSurfaceId),
      );
      return;
    }

    _surfaceController.handleMessage(
      const genui.CreateSurface(
        surfaceId: _resultSurfaceId,
        catalogId: genui.basicCatalogId,
      ),
    );
    _surfaceController.handleMessage(
      genui.UpdateComponents(
        surfaceId: _resultSurfaceId,
        components: _buildConsultationSurfaceComponents(
          cardData,
          isSaved: _isCardAlreadySaved(cardData, profileId: _selectedProfileId),
        ),
      ),
    );
  }

  List<genui.Component> _buildConsultationSurfaceComponents(
    ConsultationCardData cardData, {
    required bool isSaved,
  }) {
    final summary = _cleanMedicalText(cardData.summary);
    final analysis = _cleanMedicalText(cardData.analysis);
    final department = _cleanMedicalText(cardData.recommendedDepartment);
    final suggestion = _cleanMedicalText(cardData.hospitalSuggestion);

    return <genui.Component>[
      const genui.Component(
        id: 'root',
        type: 'Column',
        properties: {
          'children': ['resultCard', 'actionsRow'],
        },
      ),
      const genui.Component(
        id: 'resultCard',
        type: 'Card',
        properties: {'child': 'resultContent'},
      ),
      const genui.Component(
        id: 'resultContent',
        type: 'Column',
        properties: {
          'children': [
            'resultTitle',
            'summaryLabel',
            'summaryText',
            'analysisLabel',
            'analysisText',
            'departmentLabel',
            'departmentText',
            'suggestionLabel',
            'suggestionText',
          ],
        },
      ),
      const genui.Component(
        id: 'resultTitle',
        type: 'Text',
        properties: {'text': '本次 AI 问诊总结', 'variant': 'h4'},
      ),
      const genui.Component(
        id: 'summaryLabel',
        type: 'Text',
        properties: {'text': '患者概览', 'variant': 'h5'},
      ),
      genui.Component(
        id: 'summaryText',
        type: 'Text',
        properties: {'text': summary},
      ),
      const genui.Component(
        id: 'analysisLabel',
        type: 'Text',
        properties: {'text': '病情分析', 'variant': 'h5'},
      ),
      genui.Component(
        id: 'analysisText',
        type: 'Text',
        properties: {'text': analysis},
      ),
      const genui.Component(
        id: 'departmentLabel',
        type: 'Text',
        properties: {'text': '推荐科室', 'variant': 'h5'},
      ),
      genui.Component(
        id: 'departmentText',
        type: 'Text',
        properties: {'text': department},
      ),
      const genui.Component(
        id: 'suggestionLabel',
        type: 'Text',
        properties: {'text': '就医建议', 'variant': 'h5'},
      ),
      genui.Component(
        id: 'suggestionText',
        type: 'Text',
        properties: {'text': suggestion},
      ),
      const genui.Component(
        id: 'actionsRow',
        type: 'Row',
        properties: {
          'children': ['saveButton', 'finishButton'],
        },
      ),
      genui.Component(
        id: 'saveButton',
        type: 'Button',
        properties: {
          'child': 'saveButtonText',
          'variant': 'primary',
          'action': {
            'event': {
              'name': isSaved
                  ? 'saved_consultation_record'
                  : 'save_consultation_record',
            },
          },
        },
      ),
      genui.Component(
        id: 'saveButtonText',
        type: 'Text',
        properties: {'text': isSaved ? '已保存到个人记录' : '保存到个人记录'},
      ),
      const genui.Component(
        id: 'finishButton',
        type: 'Button',
        properties: {
          'child': 'finishButtonText',
          'variant': 'borderless',
          'action': {
            'event': {'name': 'finish_consultation'},
          },
        },
      ),
      const genui.Component(
        id: 'finishButtonText',
        type: 'Text',
        properties: {'text': '结束问诊'},
      ),
    ];
  }

  Future<void> _handleSurfaceSubmission(genui.ChatMessage message) async {
    for (final part in message.parts.uiInteractionParts) {
      final rawInteraction = part.interaction;
      final decoded = jsonDecode(rawInteraction);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }
      final action = decoded['action'];
      if (action is! Map<String, dynamic>) {
        continue;
      }
      final name = action['name'] as String?;
      if (name == 'save_consultation_record') {
        if (_currentCardData != null &&
            _isCardAlreadySaved(
              _currentCardData!,
              profileId: _selectedProfileId,
            )) {
          _showInfoMessage('当前问诊卡片已保存到个人记录');
          continue;
        }
        await _saveConsultationRecord();
      } else if (name == 'saved_consultation_record') {
        _showInfoMessage('当前问诊卡片已保存到个人记录');
      } else if (name == 'finish_consultation') {
        if (!mounted) {
          return;
        }
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _saveConsultationRecord() async {
    if (_currentCardData == null || !_currentCardData!.hasContent) {
      _showWarningMessage('当前没有可保存的问诊总结');
      return;
    }

    if (_observedToken == null || _observedToken!.isEmpty) {
      _showWarningMessage('请先登录后再保存个人问诊记录');
      return;
    }

    if (_mode == 'medical' && _selectedProfileId == null) {
      _showWarningMessage('请先选择当前咨询人，再保存问诊记录');
      return;
    }

    if (_isSavingConsultation) {
      return;
    }

    if (_isCardAlreadySaved(_currentCardData!, profileId: _selectedProfileId)) {
      _showInfoMessage('当前问诊卡片已保存到个人记录');
      return;
    }

    setState(() {
      _isSavingConsultation = true;
    });

    try {
      await _apiService.saveConsultationRecord(
        token: _observedToken!,
        cardData: _currentCardData!,
        chatHistory: _buildConsultationHistory(_chatProvider.history),
        profileId: _selectedProfileId,
      );
      await _loadConsultationRecords();
      if (!mounted) {
        return;
      }
      setState(() {
        _savedConsultationCardSignature = _consultationCardSignature(
          _currentCardData!,
        );
        _savedConsultationProfileId = _selectedProfileId;
      });
      _updateConsultationSurface(_currentCardData);
      final profile = _selectedProfile;
      final profileName = profile == null ? null : _profileDisplayName(profile);
      _showSuccessMessage(
        profileName != null ? '已保存到$profileName的个人问诊记录' : '已保存到个人问诊记录',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '保存问诊记录失败'),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingConsultation = false;
        });
      }
    }
  }

  List<ConsultationChatTurn> _buildConsultationHistory(
    Iterable<aitk.ChatMessage> history,
  ) {
    return history
        .map(
          (message) => ConsultationChatTurn(
            role: message.origin.isUser ? 'user' : 'assistant',
            content: _stripCardPayload(message.text ?? '').trim(),
          ),
        )
        .where((item) => item.content.isNotEmpty)
        .toList();
  }

  Future<void> _onProviderHistoryChanged() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shouldAutoScrollOnIncomingContent) {
        unawaited(_scrollChatToBottom());
      } else {
        _updateScrollToBottomButtonVisibility();
      }
    });
    if (!mounted ||
        _isHydratingProviderHistory ||
        _observedToken == null ||
        _observedToken!.isEmpty) {
      return;
    }

    _persistDebounceTimer?.cancel();
    _persistDebounceTimer = Timer(const Duration(seconds: 2), () {
      _doPersistSession();
    });
  }

  Future<void> _doPersistSession() async {
    if (!mounted ||
        _isPersistingSession ||
        _observedToken == null ||
        _observedToken!.isEmpty) {
      return;
    }

    final history = _chatProvider.history.toList();
    if (history.isEmpty) {
      return;
    }

    final nextSignature = _buildHistorySignature(history);
    if (nextSignature == _persistedHistorySignature) {
      return;
    }

    _isPersistingSession = true;
    try {
      final savedSession = await _apiService.saveChatSession(
        token: _observedToken!,
        mode: _mode,
        sessionId: _activeSessionId,
        messages: _sessionMessagesFromHistory(history),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeSessionId = savedSession.id;
        _chatSessions = _mergeSavedSession(_chatSessions, savedSession);
      });
      await _storageService.writeChatSessions(_chatSessions);
      _persistedHistorySignature = nextSignature;
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '保存对话历史失败'),
      );
    } finally {
      _isPersistingSession = false;
    }
  }

  Future<void> _scrollChatToBottom({bool animated = true}) async {
    if (!mounted || !_chatScrollController.hasClients) {
      return;
    }
    if (_chatProvider.history.isEmpty &&
        _streamingReasoningMessageIndexes.isEmpty &&
        _streamingAssistantMessageIndexes.isEmpty) {
      return;
    }
    final position = _chatScrollController.position;
    final targetOffset = position.maxScrollExtent;
    final distance = targetOffset - position.pixels;
    if (distance.abs() < 1) {
      return;
    }
    if (!animated || distance > 240) {
      _chatScrollController.jumpTo(targetOffset);
      return;
    }
    final duration = Duration(milliseconds: distance < 80 ? 120 : 180);
    try {
      await _chatScrollController.animateTo(
        targetOffset,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    } catch (_) {}
  }

  void _handleChatScroll() {
    final isNearBottom = _isChatNearBottom(
      threshold: _chatScrollToBottomAutoFollowThreshold,
    );
    _shouldAutoScrollOnIncomingContent = isNearBottom;
    _updateScrollToBottomButtonVisibility();
  }

  bool _isChatNearBottom({required double threshold}) {
    if (!_chatScrollController.hasClients) {
      return true;
    }
    final position = _chatScrollController.position;
    if (!position.hasContentDimensions) {
      return true;
    }
    return position.extentAfter <= threshold;
  }

  void _updateScrollToBottomButtonVisibility() {
    if (!mounted || !_chatScrollController.hasClients) {
      if (_showScrollToBottomButton) {
        setState(() {
          _showScrollToBottomButton = false;
        });
      }
      return;
    }
    final position = _chatScrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    final shouldShow =
        position.extentAfter > _chatScrollToBottomVisibleThreshold;
    if (shouldShow == _showScrollToBottomButton) {
      return;
    }
    setState(() {
      _showScrollToBottomButton = shouldShow;
    });
  }

  List<ChatSessionMessagePayload> _sessionMessagesFromHistory(
    Iterable<aitk.ChatMessage> history,
  ) {
    final messages = <ChatSessionMessagePayload>[];
    for (final entry in history.indexed) {
      final text = entry.$2.text;
      if (text == null || text.trim().isEmpty) {
        continue;
      }
      final attachments = _messageAttachmentsByMessageIndex[entry.$1];
      final contextFileIds = _messageContextFileIdsByMessageIndex[entry.$1];
      messages.add(
        ChatSessionMessagePayload(
          id: 'message_${entry.$1}',
          role: entry.$2.origin.isUser ? 'user' : 'ai',
          content: text,
          reasoning: _assistantReasoningByMessageIndex[entry.$1],
          contextFileIds: contextFileIds == null || contextFileIds.isEmpty
              ? null
              : contextFileIds,
          attachments: attachments == null || attachments.isEmpty
              ? null
              : attachments.map((item) => item.toPayload()).toList(),
          aiLabelMeta: entry.$2.origin.isLlm
              ? _chatProvider.aiLabelMetaForMessage(entry.$2)
              : null,
        ),
      );
    }
    return messages;
  }

  List<ChatSessionSummary> _mergeSavedSession(
    List<ChatSessionSummary> currentSessions,
    ChatSessionSummary savedSession,
  ) {
    final merged = [
      savedSession,
      ...currentSessions.where((item) => item.id != savedSession.id),
    ];
    merged.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return merged;
  }

  List<aitk.ChatMessage> _historyFromSessionMessages(
    List<ChatSessionMessagePayload> messages,
  ) {
    final history = <aitk.ChatMessage>[];

    for (final message in messages) {
      final content = message.content;
      if (content.trim().isEmpty && message.role == 'user') {
        continue;
      }

      if (message.role == 'user') {
        history.add(aitk.ChatMessage.user(content, const <aitk.Attachment>[]));
      } else {
        history.add(
          aitk.ChatMessage(
            origin: aitk.MessageOrigin.llm,
            text: content.isEmpty ? null : content,
            attachments: const <aitk.Attachment>[],
          ),
        );
      }
    }

    return history;
  }

  Map<int, String> _reasoningByMessageIndexFromSessionMessages(
    List<ChatSessionMessagePayload> messages,
  ) {
    final reasoningByMessageIndex = <int, String>{};
    var historyIndex = 0;
    for (final message in messages) {
      final content = message.content;
      if (content.trim().isEmpty && message.role == 'user') {
        continue;
      }
      final reasoning = _normalizeReasoning(message.reasoning);
      if (message.role != 'user' && reasoning.isNotEmpty) {
        reasoningByMessageIndex[historyIndex] = reasoning;
      }
      historyIndex += 1;
    }
    return reasoningByMessageIndex;
  }

  Map<int, List<_ChatMessageAttachment>>
  _attachmentsByMessageIndexFromSessionMessages(
    List<ChatSessionMessagePayload> messages,
  ) {
    final attachmentsByMessageIndex = <int, List<_ChatMessageAttachment>>{};
    var historyIndex = 0;
    for (final message in messages) {
      final content = message.content;
      if (content.trim().isEmpty && message.role == 'user') {
        continue;
      }
      if (message.role == 'user' &&
          message.attachments != null &&
          message.attachments!.isNotEmpty) {
        attachmentsByMessageIndex[historyIndex] = message.attachments!
            .map(_ChatMessageAttachment.fromPayload)
            .toList(growable: false);
      }
      historyIndex += 1;
    }
    return attachmentsByMessageIndex;
  }

  Map<int, List<String>> _contextFileIdsByMessageIndexFromSessionMessages(
    List<ChatSessionMessagePayload> messages,
  ) {
    final contextFileIdsByMessageIndex = <int, List<String>>{};
    var historyIndex = 0;
    for (final message in messages) {
      final content = message.content;
      if (content.trim().isEmpty && message.role == 'user') {
        continue;
      }
      final contextFileIds = message.contextFileIds
          ?.map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (message.role == 'user' &&
          contextFileIds != null &&
          contextFileIds.isNotEmpty) {
        contextFileIdsByMessageIndex[historyIndex] = contextFileIds;
      }
      historyIndex += 1;
    }
    return contextFileIdsByMessageIndex;
  }

  Map<int, Map<String, dynamic>>
  _aiLabelMetaByMessageIndexFromSessionMessages(
    List<ChatSessionMessagePayload> messages,
  ) {
    final result = <int, Map<String, dynamic>>{};
    var historyIndex = 0;
    for (final message in messages) {
      if (message.content.trim().isEmpty && message.role == 'user') {
        continue;
      }
      if (message.role != 'user' && message.aiLabelMeta != null) {
        result[historyIndex] = message.aiLabelMeta!;
      }
      historyIndex += 1;
    }
    return result;
  }

  List<String> _latestContextFileIdsFromSessionMessages(
    List<ChatSessionMessagePayload> messages,
  ) {
    List<String> latest = const <String>[];
    for (final message in messages) {
      if (message.role != 'user') {
        continue;
      }
      final contextFileIds = message.contextFileIds
          ?.map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (contextFileIds != null && contextFileIds.isNotEmpty) {
        latest = contextFileIds;
      }
    }
    return latest;
  }

  String _buildHistorySignature(Iterable<aitk.ChatMessage> history) {
    final payload = history.indexed
        .map(
          (entry) => {
            'origin': entry.$2.origin.name,
            'text': entry.$2.text,
            'reasoning': _assistantReasoningByMessageIndex[entry.$1],
            'attachments': _messageAttachmentsByMessageIndex[entry.$1]
                ?.map((item) => item.toJson())
                .toList(),
            'contextFileIds': _messageContextFileIdsByMessageIndex[entry.$1],
            'aiLabelMeta': entry.$2.origin.isLlm
                ? _chatProvider.aiLabelMetaForMessage(entry.$2)
                : null,
          },
        )
        .toList();
    return jsonEncode({'mode': _mode, 'history': payload});
  }

  ConsultationCardData? _extractLatestCardFromHistory(
    Iterable<aitk.ChatMessage> history,
  ) {
    ConsultationCardData? latest;
    for (final message in history) {
      if (!message.origin.isLlm) {
        continue;
      }
      final text = message.text ?? '';
      final payload = _memoizedParseCardPayload(text);
      if (payload != null && payload.type == 'medical_result') {
        try {
          final parsed = ConsultationCardData.fromJson(payload.data);
          if (parsed.hasContent) {
            latest = parsed;
          }
        } catch (_) {}
      }
    }
    return latest?.hasContent == true ? latest : null;
  }

  int? _findLastAssistantCardMessageIndex(List<aitk.ChatMessage> history) {
    int? lastIndex;
    for (final entry in history.indexed) {
      if (!entry.$2.origin.isLlm) {
        continue;
      }
      final text = entry.$2.text ?? '';
      final payload = _memoizedParseCardPayload(text);
      if (payload != null && payload.type == 'medical_result') {
        lastIndex = entry.$1;
      }
    }
    return lastIndex;
  }

  Widget _buildResponse(
    BuildContext context,
    String response, {
    String question = '',
    String? messageId,
    String? reasoning,
    bool isThinking = false,
    bool isStreaming = false,
    bool showConsultationCard = false,
  }) {
    final cardPayload = _memoizedParseCardPayload(response);
    final hasMedicalCard = cardPayload?.type == 'medical_result';
    final hasQuestionOptions = cardPayload?.type == 'question_options';
    final options = hasQuestionOptions && cardPayload?.data['options'] is List
        ? (cardPayload!.data['options'] as List)
              .map((e) => e.toString())
              .toList()
        : <String>[];

    final visibleResponse = _stripHtmlTags(
      _memoizedStripCardPayload(response),
    ).trim();
    final normalizedReasoning = _stripHtmlTags(_normalizeReasoning(reasoning));
    final hasReasoning = normalizedReasoning.isNotEmpty;

    if (visibleResponse.isEmpty &&
        !hasMedicalCard &&
        !hasQuestionOptions &&
        !hasReasoning &&
        !isThinking) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final responseBubbleMaxWidth = screenWidth >= 1080
        ? 920.0
        : screenWidth * 0.95;
    final responseBubbleRightMargin = screenWidth >= 1080 ? 24.0 : 12.0;
    final codeBackground = theme.colorScheme.surfaceContainerHighest;
    final copyContent = visibleResponse.isNotEmpty
        ? visibleResponse
        : normalizedReasoning;
    final markdownStyleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(color: Colors.black),
      listBullet: theme.textTheme.bodyMedium?.copyWith(color: Colors.black),
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: codeBackground,
        color: Colors.black,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: responseBubbleMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(right: responseBubbleRightMargin),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasReasoning || isThinking) ...[
                    _ReasoningPanel(
                      reasoning: normalizedReasoning,
                      isThinking: isThinking,
                      markdownStyleSheet: markdownStyleSheet,
                    ),
                    if (visibleResponse.isNotEmpty ||
                        hasMedicalCard ||
                        hasQuestionOptions)
                      const SizedBox(height: 12),
                  ],
                  if (visibleResponse.isNotEmpty)
                    MarkdownBody(
                      data: visibleResponse,
                      selectable: true,
                      styleSheet: markdownStyleSheet,
                    ),
                  if (hasQuestionOptions && options.isNotEmpty) ...[
                    if (visibleResponse.isNotEmpty) const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: options.map((option) {
                        final isSelected = _selectedQuestionOptions.contains(
                          option,
                        );
                        return FilterChip(
                          label: Text(option),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedQuestionOptions.add(option);
                              } else {
                                _selectedQuestionOptions.remove(option);
                              }
                            });
                          },
                          selectedColor: theme.colorScheme.primaryContainer,
                          checkmarkColor: theme.colorScheme.primary,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customOptionController,
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: '输入其他补充说明…',
                        hintStyle: TextStyle(color: Colors.black38),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed:
                            (_selectedQuestionOptions.isNotEmpty ||
                                _customOptionController.text.trim().isNotEmpty)
                            ? () {
                                final selectedTexts = _selectedQuestionOptions
                                    .toList();
                                final customText = _customOptionController.text
                                    .trim();
                                final parts = <String>[
                                  if (selectedTexts.isNotEmpty)
                                    selectedTexts.join('；'),
                                  if (customText.isNotEmpty) customText,
                                ];
                                final message = parts.join('；');
                                if (message.isNotEmpty) {
                                  _handleSend(message);
                                }
                              }
                            : null,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('发送'),
                      ),
                    ),
                  ],
                  if (showConsultationCard &&
                      (hasMedicalCard ||
                          _currentCardData?.hasContent == true) &&
                      _currentCardData?.hasContent == true) ...[
                    if (visibleResponse.isNotEmpty ||
                        (hasQuestionOptions && options.isNotEmpty))
                      const SizedBox(height: 16),
                    _buildConsultationSurfaceCard(context),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Row(
                children: [
                  if (copyContent.isNotEmpty)
                    _buildAssistantCopyButton(context, copyContent),
                  if (copyContent.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildAssistantFeedbackButton(
                      context,
                      question: question,
                      response: copyContent,
                      messageId: messageId,
                    ),
                  ],
                  const Spacer(),
                  _buildAiWatermarkTail(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSession(ChatSessionSummary session) async {
    if (_observedToken == null || _observedToken!.isEmpty) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条对话历史？'),
        content: const Text('删除后将无法恢复，但不会影响已经保存的个人问诊记录。'),
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

    try {
      await _apiService.deleteChatSession(_observedToken!, session.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _chatSessions = _chatSessions
            .where((item) => item.id != session.id)
            .toList();
      });
      if (_activeSessionId == session.id) {
        await _startNewConversation();
      }
      _showSuccessMessage('已删除这条对话历史');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessage(
        ApiService.extractErrorMessage(error, fallback: '删除对话历史失败'),
      );
    }
  }

  Future<void> _showProfilesDialog() async {
    final nameController = TextEditingController();
    final medicalHistoryController = TextEditingController();
    final allergiesController = TextEditingController();

    final authProvider = context.read<AuthProvider>();
    nameController.text = authProvider.currentUser?.displayName ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isInitialLoad = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isInitialLoad) {
              isInitialLoad = false;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  _isLoadingProfiles = true;
                });
                await _loadProfiles();
                if (dialogContext.mounted) {
                  setDialogState(() {
                    _isLoadingProfiles = false;
                  });
                }
              });
            }

            return AlertDialog(
              title: const Text('健康档案'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Text(
                              '你可以为自己或家人建立健康档案，AI 导诊保存的问诊结果会自动归档到当前选中的咨询人名下。',
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              setDialogState(() {
                                _isLoadingProfiles = true;
                              });
                              await _loadProfiles();
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  _isLoadingProfiles = false;
                                });
                              }
                            },
                            icon: _isLoadingProfiles
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                            tooltip: '刷新档案',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '现有档案',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _useNoConsultationProfile
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            unawaited(
                              _switchConsultationProfile(
                                useNoConsultationProfile: true,
                              ),
                            );
                          },
                          title: const Text('无咨询人'),
                          subtitle: const Text('本次只做普通咨询，不绑定健康档案上下文'),
                          trailing: Icon(
                            _useNoConsultationProfile
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            color: _useNoConsultationProfile
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_profiles.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('你还没有创建健康档案，可以先为本人补充基础信息。'),
                        )
                      else
                        ..._profiles.map(
                          (profile) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: _selectedProfileId == profile.id
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: ListTile(
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  unawaited(
                                    _switchConsultationProfile(
                                      useNoConsultationProfile: false,
                                      profileId: profile.id,
                                    ),
                                  );
                                },
                                title: Text(_profileDisplayName(profile)),
                                subtitle: Text(
                                  '${_relationLabel(profile.relation)} · ${profile.gender} · ${profile.age} 岁',
                                ),
                                trailing: Icon(
                                  _selectedProfileId == profile.id
                                      ? Icons.check_circle_rounded
                                      : Icons.chevron_right_rounded,
                                  color: _selectedProfileId == profile.id
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _openHealthArchive();
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('管理与新增档案'),
                        ),
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
            );
          },
        );
      },
    );

    nameController.dispose();
    medicalHistoryController.dispose();
    allergiesController.dispose();
  }

  HealthProfile? get _selectedProfile {
    if (_selectedProfileId == null) {
      return null;
    }
    for (final profile in _profiles) {
      if (profile.id == _selectedProfileId) {
        return profile;
      }
    }
    return null;
  }

  List<SavedConsultationRecord> get _displayedRecords {
    if (_mode == 'medical') {
      if (_selectedProfileId == null) {
        return const <SavedConsultationRecord>[];
      }
      return _consultationRecords
          .where((record) => record.profileId == _selectedProfileId)
          .toList();
    }
    return _consultationRecords;
  }

  List<SavedConsultationRecord> get _healthSnapshotRecords {
    if (_selectedProfileId == null) {
      return _consultationRecords;
    }
    return _consultationRecords
        .where((record) => record.profileId == _selectedProfileId)
        .toList();
  }

  String get _consultationProfileChipLabel {
    final profile = _selectedProfile;
    if (profile != null) {
      return '就诊人·${_profileDisplayName(profile)}';
    }
    return '就诊人·无咨询人';
  }

  SavedConsultationRecord? get _latestHealthSnapshotRecord {
    if (_healthSnapshotRecords.isEmpty) {
      return null;
    }
    return _healthSnapshotRecords.reduce(
      (latest, current) =>
          current.createdAt.isAfter(latest.createdAt) ? current : latest,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;

        final scaffold = Scaffold(
          key: _scaffoldKey,
          onDrawerChanged: (isOpened) {
            if (isOpened) {
              unawaited(_refreshProfilesAndConsultationRecords());
            }
          },
          drawer: isWide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: _buildSidebar(context, currentUser, true),
                  ),
                ),
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            leading: IconButton(
              onPressed: () {
                if (isWide) {
                  Navigator.of(context).maybePop();
                  return;
                }
                // 呼出左侧栏前彻底解除输入框焦点，避免键盘弹出遮挡抽屉；
                // 先 unfocus 显式节点，再清掉可能残留的全局焦点
                _chatInputFocusNode.unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
                unawaited(_refreshProfilesAndConsultationRecords());
                _scaffoldKey.currentState?.openDrawer();
                // 兜底：抽屉打开后若焦点被框架恢复到输入框，再次解除
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_chatInputFocusNode.hasFocus) {
                    _chatInputFocusNode.unfocus();
                  }
                });
              },
              icon: Icon(
                isWide ? Icons.arrow_back_ios_new : Icons.menu_open_rounded,
                size: 20,
                color: Colors.black,
              ),
            ),
            title: Row(
              children: [
                const AppLogo(size: 32),
                const SizedBox(width: 8),
                const Text(
                  '三十天时刻智护',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  // decoration: BoxDecoration(
                  //   color: Colors.white,
                  //   borderRadius: BorderRadius.circular(16),
                  // ),
                  // child: const Text(
                  //   '智能体',
                  //   style: TextStyle(
                  //     color: Colors.black,
                  //     fontSize: 12,
                  //     fontWeight: FontWeight.w500,
                  //   ),
                  // ),
                ),
              ),
              // IconButton(
              //   icon: const Icon(Icons.mic_none, color: Colors.black),
              //   onPressed: () {},
              // ),
              Tooltip(
                message: '新建会话',
                child: IconButton(
                  icon: const Icon(
                    Icons.add_comment_outlined,
                    color: Colors.black,
                  ),
                  onPressed: () => _startNewConversation(),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isInitializing
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      if (isWide)
                        SizedBox(
                          width: 620,
                          child: _buildSidebar(context, currentUser, false),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            if (_isLoadingSessionDetail)
                              const LinearProgressIndicator(minHeight: 2),
                            _buildAiWatermarkBanner(context),
                            Expanded(
                              child: Stack(
                                children: [
                                  _buildChatHistoryView(context),
                                  Positioned(
                                    right: 20,
                                    bottom:
                                        _chatScrollToBottomButtonBottomOffset,
                                    child: _buildScrollToBottomButton(context),
                                  ),
                                  Positioned(
                                    bottom: 6,
                                    left: 0,
                                    right: 0,
                                    child: _buildFloatingChips(context),
                                  ),
                                ],
                              ),
                            ),
                            _buildCustomChatInput(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2F4FF), Color(0xFFE6E9FA)],
            ),
          ),
          child: scaffold,
        );
      },
    );
  }

  Widget _buildChatHistoryView(BuildContext context) {
    final history = _chatProvider.history.toList();
    final latestCardMessageIndex = _findLastAssistantCardMessageIndex(history);
    final scrollBehavior = ScrollConfiguration.of(
      context,
    ).copyWith(scrollbars: false, overscroll: false);
    return ListenableBuilder(
      key: ValueKey('$_mode|$_activeSessionId|${_selectedProfileId ?? 'none'}'),
      listenable: _chatProvider,
      builder: (context, child) => GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: _chatContentBottomSpacing,
          ),
          child: ScrollConfiguration(
            behavior: scrollBehavior,
            child: ListView.builder(
              controller: _chatScrollController,
              physics: const ClampingScrollPhysics(),
              itemCount: history.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: [
                        _buildWelcomeBanner(context),
                        const SizedBox(height: 18),
                        _buildProfileBanner(context),
                        const SizedBox(height: 16),
                        _buildHotQuestionSection(context),
                      ],
                    ),
                  );
                }
                final message = history[index - 1];
                final text = message.text?.trim();
                final reasoning = _assistantReasoningByMessageIndex[index - 1];
                final hasReasoning = _normalizeReasoning(reasoning).isNotEmpty;
                final isThinking = _streamingReasoningMessageIndexes.contains(
                  index - 1,
                );
                final isStreamingResponse = _streamingAssistantMessageIndexes
                    .contains(index - 1);
                if ((text == null || text.isEmpty) &&
                    (!hasReasoning && !isThinking)) {
                  return const SizedBox.shrink();
                }
                final previousMessage = index > 1 ? history[index - 2] : null;
                final topSpacing = previousMessage == null
                    ? 10.0
                    : previousMessage.origin == message.origin
                    ? _chatMessageSpacing
                    : _chatSpeakerChangeSpacing;
                return Padding(
                  key: ValueKey('msg_$index'),
                  padding: EdgeInsets.only(top: topSpacing),
                  child: message.origin.isUser
                      ? _buildUserMessageBubble(
                          context,
                          text!,
                          attachments:
                              _messageAttachmentsByMessageIndex[index - 1] ??
                              const <_ChatMessageAttachment>[],
                        )
                      : _buildResponse(
                          context,
                          text ?? '',
                          question: index >= 2 ? (history[index - 2].text ?? '') : '',
                          messageId: 'message_${index - 1}',
                          reasoning: reasoning,
                          isThinking: isThinking,
                          isStreaming: isStreamingResponse,
                          showConsultationCard:
                              latestCardMessageIndex == index - 1,
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollToBottomButton(BuildContext context) {
    return IgnorePointer(
      ignoring: !_showScrollToBottomButton,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        offset: _showScrollToBottomButton ? Offset.zero : const Offset(0, 0.35),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _showScrollToBottomButton ? 1 : 0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => unawaited(_scrollChatToBottom()),
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE2E4F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF4F46E5),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '查看更多',
                      style: TextStyle(
                        color: Color(0xFF312E81),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiWatermarkBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(top: 4, left: 12, right: 12, bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFCD34D).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: const Color(0xFFB45309),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              kAiWatermark,
              style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiWatermarkTail(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Text(
        kAiWatermark,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProfile = _selectedProfile;
    final profileName = selectedProfile == null
        ? '你'
        : _profileDisplayName(selectedProfile);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF1E1B4B),
                      fontWeight: FontWeight.w700,
                    ),
                    children: const [
                      TextSpan(text: '你好！ '),
                      TextSpan(text: '✨'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '愿$profileName拥有轻盈好心情',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1E1B4B),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 150,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFE8DEFF),
                            const Color(0xFFE8DEFF).withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      child: Text(
                        'HEALTH',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.28),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 20,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.waving_hand_rounded,
                          size: 18,
                          color: Color(0xFF7C6BFF),
                        ),
                      ),
                    ),
                    Container(
                      width: 88,
                      height: 108,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(44),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF7C6BFF,
                            ).withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 12,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFE2C7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.face_3_rounded,
                                color: Color(0xFF5B4636),
                                size: 28,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 54,
                            child: Container(
                              width: 58,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEAF4FF),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 58,
                            child: Icon(
                              Icons.medical_services_outlined,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          Positioned(
                            top: 26,
                            child: Container(
                              width: 34,
                              height: 12,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF5B4636),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
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
          ),
        ],
      ),
    );
  }

  Widget _buildHotQuestionSection(BuildContext context) {
    return Consumer<HotQuestionsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.questions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final questions = provider.questions;

        // Fallback to static prompts if API fails or is empty
        final displayQuestions = questions.isNotEmpty
            ? questions.map((q) => q.question).toList()
            : _hotQuestionPrompts;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              for (final entry in displayQuestions.indexed) ...[
                _buildHotQuestionTile(
                  context,
                  title: entry.$2,
                  isAvatar: entry.$1 == 0,
                  onTap: () {
                    _handleSend(entry.$2);
                    if (questions.isNotEmpty && entry.$1 < questions.length) {
                      provider.recordClick(questions[entry.$1].id);
                    }
                  },
                ),
                if (entry.$1 != displayQuestions.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHotQuestionTile(
    BuildContext context, {
    required String title,
    required bool isAvatar,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              isAvatar
                  ? Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD8C2), Color(0xFFB9C7FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                  : Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF6E61FF), Color(0xFF8D7FFF)],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '#',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0B4C7)),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeReasoning(String? reasoning) {
    if (reasoning == null || reasoning.isEmpty) {
      return '';
    }
    return reasoning
        .replaceAll(RegExp(r'</?think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _consultationCardSignature(ConsultationCardData cardData) {
    return jsonEncode(cardData.toJson());
  }

  bool _isCardAlreadySaved(
    ConsultationCardData cardData, {
    required int? profileId,
  }) {
    return _savedConsultationCardSignature ==
            _consultationCardSignature(cardData) &&
        _savedConsultationProfileId == profileId;
  }

  Future<bool> _ensureAttachmentPermission() async {
    if (kIsWeb) {
      return true;
    }
    if (io.Platform.operatingSystem == 'ohos') {
      return true;
    }

    final permissions = <Permission>[
      if (defaultTargetPlatform == TargetPlatform.android) Permission.photos,
      if (defaultTargetPlatform == TargetPlatform.android) Permission.storage,
      if (defaultTargetPlatform == TargetPlatform.iOS) Permission.photos,
    ];

    if (permissions.isEmpty) {
      return true;
    }

    final statuses = await Future.wait(permissions.map((item) => item.status));
    final hasPermission = statuses.any((status) {
      return status.isGranted || status.isLimited;
    });
    if (hasPermission) {
      return true;
    }

    final requestResults = await permissions.request();
    final isGranted = requestResults.values.any((status) {
      return status.isGranted || status.isLimited;
    });
    if (isGranted) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('需要授权'),
        content: const Text('上传文件需要读取设备文件的权限，请前往系统设置开启后重试。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );

    if (shouldOpenSettings == true) {
      await openAppSettings();
    }

    return false;
  }

  /// Forwards diagnostics to the native hilog (tag MediaPlugin) so upload
  /// issues on HarmonyOS can be traced without a connected debugger.
  Future<void> _nativeLog(String message) async {
    try {
      await _harmonyMediaChannel.invokeMethod(
        'log',
        <String, dynamic>{'message': message},
      );
    } catch (_) {
      // Logging must never break the upload flow.
    }
  }

  Future<void> _pickAndUploadAttachment() async {
    if (_isUploadingAttachment) {
      await _nativeLog('pickFiles skipped: busy');
      return;
    }

    final hasPermission = await _ensureAttachmentPermission();
    if (!hasPermission) {
      return;
    }

    FocusScope.of(context).unfocus();
    FilePickerResult? result;
    if (io.Platform.operatingSystem == 'ohos') {
      final List<dynamic>? nativeFiles;
      try {
        nativeFiles = await _harmonyMediaChannel.invokeMethod<List<dynamic>>('pickFiles');
      } catch (error) {
        await _nativeLog('pickFiles error: $error');
        if (mounted) {
          _showErrorMessage('选择文件失败：$error');
        }
        return;
      }
      final replyPaths = nativeFiles
          ?.map((item) => Map<dynamic, dynamic>.from(item as Map)['path'])
          .join(',');
      await _nativeLog('pickFiles replied count=${nativeFiles?.length ?? 0} paths=$replyPaths');
      if (nativeFiles == null || nativeFiles.isEmpty) {
        return;
      }
      result = FilePickerResult(nativeFiles.map((item) {
        final file = Map<dynamic, dynamic>.from(item as Map);
        // HarmonyOS returns a sandbox copy path; large byte arrays sent
        // through the platform channel are silently dropped by the engine.
        final path = file['path']?.toString();
        Uint8List? fileBytes;
        if (path != null && path.isNotEmpty) {
          try {
            fileBytes = io.File(path).readAsBytesSync();
          } catch (_) {
            fileBytes = null;
          }
        }
        return PlatformFile(
          name: file['name']?.toString() ?? 'attachment',
          size: fileBytes?.length ?? 0,
          bytes: fileBytes,
        );
      }).toList(growable: false));
    } else {
      result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const <String>['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );
    }

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final invalidFileNames = <String>[];
    final pendingAttachments = <_SelectedChatAttachment>[];
    final uploadRequests = <ChatAttachmentUploadRequest>[];
    for (final entry in result.files.indexed) {
      final pickedFile = entry.$2;
      final fileBytes = pickedFile.bytes;
      final fileName = _normalizeAttachmentName(
        pickedFile.name.trim(),
        fileBytes,
      );
      final fallbackName = fileName.isEmpty ? '未命名文件' : fileName;
      if (fileName.isEmpty || fileBytes == null || fileBytes.isEmpty) {
        invalidFileNames.add(fallbackName);
        continue;
      }
      if (!_isSupportedAttachmentName(fileName)) {
        invalidFileNames.add(fileName);
        continue;
      }

      final localId = _buildLocalAttachmentId(
        fileName,
        entry.$1,
        fileBytes.length,
      );
      pendingAttachments.add(
        _SelectedChatAttachment(
          localId: localId,
          name: fileName,
          status: _SelectedChatAttachmentStatus.uploading,
          progress: 0,
          size: fileBytes.length,
          bytes: fileBytes,
        ),
      );
      uploadRequests.add(
        ChatAttachmentUploadRequest(fileName: fileName, bytes: fileBytes),
      );
    }

    if (invalidFileNames.isNotEmpty) {
      _showWarningMessage(
        '以下文件无法上传：${invalidFileNames.join('、')}。仅支持 PDF、PNG、JPG、JPEG 或 WEBP 文件',
      );
    }
    if (pendingAttachments.isEmpty) {
      return;
    }

    final pendingAttachmentIds = pendingAttachments
        .map((item) => item.localId)
        .toSet();
    await _nativeLog(
      'upload begin files=${uploadRequests.length} '
      'bytes=${uploadRequests.fold<int>(0, (sum, item) => sum + item.bytes.length)}',
    );

    setState(() {
      _isUploadingAttachment = true;
      _selectedAttachments = [..._selectedAttachments, ...pendingAttachments];
    });

    try {
      final uploadedAttachments = await _apiService.uploadChatAttachments(
        files: uploadRequests,
        token: _observedToken,
        onSendProgress: (sent, total) {
          if (!mounted) {
            return;
          }
          final progress = total > 0 ? sent / total : null;
          final status = total > 0 && sent >= total
              ? _SelectedChatAttachmentStatus.processing
              : _SelectedChatAttachmentStatus.uploading;
          setState(() {
            _selectedAttachments = _selectedAttachments
                .map(
                  (attachment) =>
                      pendingAttachmentIds.contains(attachment.localId)
                      ? attachment.copyWith(progress: progress, status: status)
                      : attachment,
                )
                .toList(growable: false);
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isUploadingAttachment = false;
        final uploadedByLocalId = <String, ChatAttachmentUploadResult>{
          for (final entry in uploadedAttachments.indexed)
            pendingAttachments[entry.$1].localId: entry.$2,
        };
        _selectedAttachments = _selectedAttachments
            .map((attachment) {
              final uploadedAttachment = uploadedByLocalId[attachment.localId];
              if (uploadedAttachment == null) {
                return attachment;
              }
              return attachment.copyWith(
                status: _SelectedChatAttachmentStatus.ready,
                progress: 1,
                fileId: uploadedAttachment.fileId,
                contentType: uploadedAttachment.contentType,
                size: uploadedAttachment.size,
              );
            })
            .toList(growable: false);
      });
      _showSuccessMessage(
        uploadedAttachments.length == 1
            ? '文档上传成功，输入问题后即可发送给模型'
            : '文档上传成功，可继续追加资料后提问',
      );
      await _nativeLog('upload ok count=${uploadedAttachments.length}');
    } catch (error) {
      await _nativeLog('upload error: $error');
      if (!mounted) {
        return;
      }
      final errorMessage = ApiService.extractErrorMessage(
        error,
        fallback: '文档上传失败，请稍后重试',
      );
      setState(() {
        _isUploadingAttachment = false;
        _selectedAttachments = _selectedAttachments
            .map(
              (attachment) => pendingAttachmentIds.contains(attachment.localId)
                  ? attachment.copyWith(
                      status: _SelectedChatAttachmentStatus.failed,
                      progress: null,
                      errorMessage: errorMessage,
                    )
                  : attachment,
            )
            .toList(growable: false);
      });
      _showErrorMessage(errorMessage);
    }
  }

  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) {
      return true;
    }

    PermissionStatus status;
    try {
      status = await Permission.camera.status;
    } catch (_) {
      // The permission_handler plugin has no HarmonyOS implementation. The
      // native module declares CAMERA and the camera picker performs the real
      // authorization check when it is opened.
      return true;
    }
    if (status.isGranted || status.isLimited) {
      return true;
    }

    PermissionStatus result;
    try {
      result = await Permission.camera.request();
    } catch (_) {
      return true;
    }
    if (result.isGranted || result.isLimited) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('需要授权'),
        content: const Text('拍照上传报告需要相机权限，请前往系统设置开启后重试。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );

    if (shouldOpenSettings == true) {
      await openAppSettings();
    }

    return false;
  }

  Future<void> _captureAndUploadPhoto() async {
    if (_isUploadingAttachment) {
      return;
    }

    final hasPermission = await _ensureCameraPermission();
    if (!hasPermission) {
      return;
    }

    FocusScope.of(context).unfocus();
    XFile? image;
    try {
      if (io.Platform.operatingSystem == 'ohos') {
        final nativeFile = await _harmonyMediaChannel.invokeMethod<Map<dynamic, dynamic>>('capturePhoto');
        if (nativeFile == null) {
          return;
        }
        final path = nativeFile['path']?.toString();
        if (path == null || path.isEmpty) {
          throw StateError('鸿蒙相机未返回照片文件');
        }
        await _nativeLog('photo replied path=$path');
        final imageBytes = io.File(path).readAsBytesSync();
        await _nativeLog('photo bytes=${imageBytes.length}');
        image = XFile.fromData(imageBytes, name: nativeFile['name']?.toString() ?? 'photo.jpg');
      } else {
        image = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
      }
    } catch (error) {
      await _nativeLog('photo capture error: $error');
      if (mounted) {
        _showErrorMessage('鸿蒙拍摄失败：$error');
      }
      return;
    }

    if (!mounted || image == null) {
      return;
    }

    final fileName = image.name.isNotEmpty
        ? image.name
        : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    if (!_isSupportedAttachmentName(fileName)) {
      _showWarningMessage('仅支持拍摄 PNG、JPG、JPEG 或 WEBP 格式的照片');
      return;
    }

    final fileBytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }

    final localId = _buildLocalAttachmentId(fileName, 0, fileBytes.length);
    final pendingAttachment = _SelectedChatAttachment(
      localId: localId,
      name: fileName,
      status: _SelectedChatAttachmentStatus.uploading,
      progress: 0,
      size: fileBytes.length,
      bytes: fileBytes,
    );
    final uploadRequest = ChatAttachmentUploadRequest(
      fileName: fileName,
      bytes: fileBytes,
    );
    await _nativeLog('photo upload begin bytes=${fileBytes.length}');

    setState(() {
      _isUploadingAttachment = true;
      _selectedAttachments = [..._selectedAttachments, pendingAttachment];
    });

    try {
      final uploadedAttachments = await _apiService.uploadChatAttachments(
        files: [uploadRequest],
        token: _observedToken,
        onSendProgress: (sent, total) {
          if (!mounted) {
            return;
          }
          final progress = total > 0 ? sent / total : null;
          final status = total > 0 && sent >= total
              ? _SelectedChatAttachmentStatus.processing
              : _SelectedChatAttachmentStatus.uploading;
          setState(() {
            _selectedAttachments = _selectedAttachments
                .map(
                  (attachment) => attachment.localId == localId
                      ? attachment.copyWith(progress: progress, status: status)
                      : attachment,
                )
                .toList(growable: false);
          });
        },
      );
      if (!mounted) {
        return;
      }
      if (uploadedAttachments.isEmpty) {
        return;
      }
      final uploaded = uploadedAttachments.first;
      setState(() {
        _isUploadingAttachment = false;
        _selectedAttachments = _selectedAttachments
            .map(
              (attachment) => attachment.localId == localId
                  ? attachment.copyWith(
                      status: _SelectedChatAttachmentStatus.ready,
                      progress: 1,
                      fileId: uploaded.fileId,
                      contentType: uploaded.contentType,
                      size: uploaded.size,
                    )
                  : attachment,
            )
            .toList(growable: false);
      });
      _showSuccessMessage('照片上传成功，输入问题后即可发送给模型');
      await _nativeLog('photo upload ok');
    } catch (error) {
      await _nativeLog('photo upload error: $error');
      if (!mounted) {
        return;
      }
      final errorMessage = ApiService.extractErrorMessage(
        error,
        fallback: '照片上传失败，请稍后重试',
      );
      setState(() {
        _isUploadingAttachment = false;
        _selectedAttachments = _selectedAttachments
            .map(
              (attachment) => attachment.localId == localId
                  ? attachment.copyWith(
                      status: _SelectedChatAttachmentStatus.failed,
                      progress: null,
                      errorMessage: errorMessage,
                    )
                  : attachment,
            )
            .toList(growable: false);
      });
      _showErrorMessage(errorMessage);
    }
  }

  bool _isSupportedAttachmentName(String fileName) {
    final normalized = fileName.toLowerCase();
    return normalized.endsWith('.pdf') ||
        normalized.endsWith('.png') ||
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.webp');
  }

  String _normalizeAttachmentName(String fileName, Uint8List? bytes) {
    if (_isSupportedAttachmentName(fileName) || bytes == null || bytes.isEmpty) {
      return fileName;
    }

    String? extension;
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      extension = '.jpg';
    } else if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      extension = '.png';
    } else if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      extension = '.pdf';
    } else if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      extension = '.webp';
    }

    if (extension == null) {
      return fileName;
    }
    return '${fileName.isEmpty ? 'attachment' : fileName}$extension';
  }

  String _buildLocalAttachmentId(String name, int index, int size) {
    return '$name-$size-$index-${DateTime.now().microsecondsSinceEpoch}';
  }

  bool get _hasBlockingSelectedAttachments =>
      _selectedAttachments.any((attachment) => !attachment.isReady);

  String get _selectedAttachmentBlockingMessage {
    return _selectedAttachments.any(
          (attachment) =>
              attachment.status == _SelectedChatAttachmentStatus.failed,
        )
        ? '附件上传失败，请重新上传或移除后再发送'
        : '文档解析完成后才能发送问题';
  }

  List<String> _dedupeFileIds(Iterable<String> fileIds) {
    final seen = <String>{};
    final deduped = <String>[];
    for (final fileId in fileIds) {
      final normalized = fileId.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      deduped.add(normalized);
    }
    return deduped;
  }

  void _removeSelectedAttachment(String localId) {
    setState(() {
      _selectedAttachments = _selectedAttachments
          .where((attachment) => attachment.localId != localId)
          .toList(growable: false);
    });
  }

  Timer? _throttleTimer;

  void _throttledStreamingSetState() {
    if (!mounted) return;
    final elapsed = DateTime.now().difference(_lastStreamingSetStateTime);
    const throttleInterval = Duration(milliseconds: 65);
    if (elapsed >= throttleInterval) {
      _lastStreamingSetStateTime = DateTime.now();
      _throttleTimer?.cancel();
      _throttleTimer = null;
      setState(() {});
    } else if (_throttleTimer == null) {
      _throttleTimer = Timer(throttleInterval - elapsed, () {
        _throttleTimer = null;
        if (mounted) {
          _lastStreamingSetStateTime = DateTime.now();
          setState(() {});
        }
      });
    }
  }

  void _attemptSend(String text) {
    if (text.trim().isEmpty) {
      return;
    }
    if (_isUploadingAttachment) {
      _showWarningMessage('文档上传完成后才能发送问题');
      return;
    }
    if (_hasBlockingSelectedAttachments) {
      _showWarningMessage(_selectedAttachmentBlockingMessage);
      return;
    }
    _handleSend(text);
  }

  bool _isImageAttachmentName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  String? _imageMimeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return null;
  }

  void _handleSend(String text) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }
    if (!_hasUsableSession(context.read<AuthProvider>())) {
      unawaited(_showLoginRequiredDialog(message: '登录后才能进行咨询对话，是否前往登录？'));
      return;
    }
    final userMessageIndex = _chatProvider.history.length;
    final assistantMessageIndex = userMessageIndex + 1;
    final sentAttachments = _selectedAttachments
        .where((attachment) => attachment.isReady)
        .map(_ChatMessageAttachment.fromSelected)
        .toList(growable: false);
    // 图片附件必须内联重传字节：后端只把非图片 fileId 交给文档提取模型，
    // 图片内容靠 fileId 模型收不到，需要走 multipart files 交给视觉模型
    final inlineImageAttachments = <aitk.FileAttachment>[
      for (final attachment in _selectedAttachments)
        if (attachment.isReady &&
            attachment.bytes != null &&
            attachment.bytes!.isNotEmpty &&
            ((attachment.contentType?.startsWith('image/') ?? false) ||
                _isImageAttachmentName(attachment.name)))
          aitk.FileAttachment(
            name: attachment.name,
            mimeType: (attachment.contentType?.startsWith('image/') ?? false)
                ? attachment.contentType!
                : (_imageMimeTypeForName(attachment.name) ?? 'image/jpeg'),
            bytes: attachment.bytes!,
          ),
    ];
    final requestContextFileIds = _dedupeFileIds([
      ..._chatProvider.contextFileIds,
      ...sentAttachments.map((attachment) => attachment.fileId),
    ]);
    setState(() {
      _shouldAutoScrollOnIncomingContent = true;
      if (sentAttachments.isNotEmpty) {
        _messageAttachmentsByMessageIndex[userMessageIndex] = sentAttachments;
      }
      if (requestContextFileIds.isNotEmpty) {
        _messageContextFileIdsByMessageIndex[userMessageIndex] =
            requestContextFileIds;
      } else {
        _messageContextFileIdsByMessageIndex.remove(userMessageIndex);
      }
      _selectedAttachments = <_SelectedChatAttachment>[];
      _selectedQuestionOptions = <String>{};
      _customOptionController.clear();
      _streamingAssistantMessageIndexes.add(assistantMessageIndex);
      if (_isThinking) {
        _assistantReasoningByMessageIndex[assistantMessageIndex] = '';
        _streamingReasoningMessageIndexes.add(assistantMessageIndex);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollChatToBottom(animated: false));
    });
    _chatInputController.clear();
    final stream = _chatProvider.sendMessageStreamWithCallbacks(
      normalizedText,
      attachments: inlineImageAttachments,
      contextFileIds: requestContextFileIds,
      consultationProfileId: _useNoConsultationProfile
          ? -1
          : _selectedProfileId,
      onReasoningChunk: (chunk) {
        if (!mounted || chunk.isEmpty) {
          return;
        }
        final currentReasoning =
            _assistantReasoningByMessageIndex[assistantMessageIndex] ?? '';
        _assistantReasoningByMessageIndex[assistantMessageIndex] =
            currentReasoning + chunk;
        _throttledStreamingSetState();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_shouldAutoScrollOnIncomingContent) {
            unawaited(_scrollChatToBottom());
          } else {
            _updateScrollToBottomButtonVisibility();
          }
        });
      },
    );
    stream.listen(
      (chunk) {
        _throttledStreamingSetState();
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _streamingAssistantMessageIndexes.remove(assistantMessageIndex);
            _streamingReasoningMessageIndexes.remove(assistantMessageIndex);
            if (_normalizeReasoning(
              _assistantReasoningByMessageIndex[assistantMessageIndex],
            ).isEmpty) {
              _assistantReasoningByMessageIndex.remove(assistantMessageIndex);
            }
          });
        }
        if (mounted) setState(() {});
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _streamingAssistantMessageIndexes.remove(assistantMessageIndex);
            _streamingReasoningMessageIndexes.remove(assistantMessageIndex);
          });
          if (_isUnauthorizedError(e)) {
            unawaited(
              _showLoginRequiredDialog(message: '当前登录状态已失效，请重新登录后继续咨询。'),
            );
          } else {
            _showErrorMessage('发送失败: $e');
          }
        }
      },
    );
  }

  Widget _buildCustomChatInput(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E4F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _chatInputController,
              builder: (context, value, child) {
                if (value.text.trim().isNotEmpty) {
                  return const SizedBox.shrink();
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInputIconButton(
                      icon: Icons.attach_file_rounded,
                      onTap: _isUploadingAttachment
                          ? null
                          : _pickAndUploadAttachment,
                    ),
                    const SizedBox(width: 8),
                    _buildInputIconButton(
                      icon: Icons.camera_alt_rounded,
                      onTap: _isUploadingAttachment
                          ? null
                          : _captureAndUploadPhoto,
                    ),
                    const SizedBox(width: 12),
                  ],
                );
              },
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedAttachments.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildSelectedAttachmentChips(context),
                    ),
                  ],
                  TextField(
                    controller: _chatInputController,
                    focusNode: _chatInputFocusNode,
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: '发消息...',
                      hintStyle: TextStyle(color: Colors.black38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                    ),
                    onSubmitted: _attemptSend,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _chatInputController,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                final hasBlockingAttachment = _hasBlockingSelectedAttachments;
                final canSend =
                    hasText &&
                    !_isUploadingAttachment &&
                    !hasBlockingAttachment;
                final canPolish = hasText && !_isPolishing;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildInputIconButton(
                          icon: Icons.auto_awesome_rounded,
                          backgroundColor: canPolish
                              ? const Color(0xFFEEF2FF)
                              : Colors.grey.shade100,
                          iconColor: canPolish
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF9CA3AF),
                          onTap: canPolish ? _polishMessage : null,
                        ),
                        if (_isPolishing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                      ],
                    ),
                    if (hasText) const SizedBox(width: 8),
                    if (hasText)
                      _buildInputIconButton(
                        icon: Icons.send_rounded,
                        backgroundColor: canSend
                            ? theme.primaryColor
                            : Colors.grey.shade100,
                        iconColor: canSend ? Colors.white : Colors.black87,
                        onTap: () {
                          if (canSend) {
                            _attemptSend(value.text);
                          } else if (hasText && _isUploadingAttachment) {
                            _showWarningMessage('文档上传完成后才能发送问题');
                          } else if (hasText && hasBlockingAttachment) {
                            _showWarningMessage(
                              _selectedAttachmentBlockingMessage,
                            );
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Material(
      color: backgroundColor ?? const Color(0xFFF3F4F6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: iconColor ?? const Color(0xFF374151)),
        ),
      ),
    );
  }

  Widget _buildAssistantCopyButton(BuildContext context, String content) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_copyAssistantMessage(content)),
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE2E4F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.content_copy_rounded,
                size: 16,
                color: Color(0xFF4F46E5),
              ),
              const SizedBox(width: 6),
              Text(
                '复制',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF312E81),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantFeedbackButton(
    BuildContext context, {
    required String question,
    required String response,
    String? messageId,
  }) {
    return IconButton(
      tooltip: '反馈',
      icon: const Icon(Icons.feedback_outlined, size: 18),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      onPressed: () => unawaited(_showFeedbackDialog(
        question: question,
        response: response,
        messageId: messageId,
      )),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _showFeedbackDialog({
    required String question,
    required String response,
    String? messageId,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('反馈 AI 回复'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 8,
          maxLength: 5000,
          decoration: const InputDecoration(
            hintText: '请描述您对这条 AI 回复的意见或建议',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty || !mounted) return;
    final token = _observedToken;
    if (token == null || token.isEmpty) return;
    try {
      await _apiService.submitAiFeedback(
        token: token,
        content: result,
        question: _stripHtmlTags(question).trim().isEmpty ? '未识别问题' : _stripHtmlTags(question).trim(),
        aiResponse: response,
        sessionId: _activeSessionId,
        messageId: messageId,
      );
      if (mounted) _showSuccessMessage('感谢您的反馈');
    } catch (error) {
      if (mounted) _showErrorMessage(ApiService.extractErrorMessage(error, fallback: '反馈提交失败'));
    }
  }

  Widget _buildUserMessageBubble(
    BuildContext context,
    String text, {
    List<_ChatMessageAttachment> attachments = const <_ChatMessageAttachment>[],
  }) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          margin: const EdgeInsets.only(left: 48),
          decoration: const BoxDecoration(
            color: Color(0xFFE2E4F0),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final attachment in attachments) ...[
                _buildUserMessageAttachmentPreview(context, attachment),
                const SizedBox(height: 10),
              ],
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessageAttachmentPreview(
    BuildContext context,
    _ChatMessageAttachment attachment,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _attachmentIconForName(attachment.name),
            size: 18,
            color: const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attachment.size > 0
                      ? '已关联附件 · ${_formatAttachmentSize(attachment.size)}'
                      : '已关联附件',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAttachmentChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final attachment in _selectedAttachments) ...[
            _buildSelectedAttachmentChip(context, attachment),
            if (attachment != _selectedAttachments.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedAttachmentChip(
    BuildContext context,
    _SelectedChatAttachment attachment,
  ) {
    final theme = Theme.of(context);
    final accentColor = switch (attachment.status) {
      _SelectedChatAttachmentStatus.ready => const Color(0xFF0F9D58),
      _SelectedChatAttachmentStatus.failed => const Color(0xFFD93025),
      _ => const Color(0xFF5B6CFF),
    };
    final label = attachment.compactStatusLabel;
    final tooltipMessage = [
      attachment.name,
      if (attachment.errorMessage != null &&
          attachment.errorMessage!.trim().isNotEmpty)
        attachment.errorMessage!,
      if (attachment.errorMessage == null && label.isNotEmpty) label,
    ].join('\n');

    return Tooltip(
      message: tooltipMessage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 220),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accentColor.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _attachmentIconForName(attachment.name),
              color: accentColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                attachment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            InkWell(
              onTap: _isUploadingAttachment
                  ? null
                  : () => _removeSelectedAttachment(attachment.localId),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: _isUploadingAttachment
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _attachmentIconForName(String fileName) {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }
    return Icons.image_rounded;
  }

  String _formatAttachmentSize(int size) {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '$size B';
  }

  Widget _buildFloatingChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip(
            context: context,
            icon: Icons.medical_services_outlined,
            label: 'AI导诊',
            isSelected: _mode == 'medical',
            onTap: () {
              setState(() {
                final nextMode = _mode == 'medical' ? 'normal' : 'medical';
                _mode = nextMode;
                if (_mode == 'medical') {
                  _isThinking = true;
                } else {
                  _currentCardData = null;
                }
              });
              _chatProvider.updateConfiguration(
                mode: _mode,
                thinkingEnabled: _isThinking,
                token: _observedToken,
              );
            },
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            icon: Icons.science_outlined,
            label: '深度思考',
            isSelected: _isThinking,
            onTap: () {
              setState(() {
                _isThinking = !_isThinking;
              });
              _chatProvider.updateConfiguration(
                mode: _mode,
                thinkingEnabled: _isThinking,
                token: _observedToken,
              );
            },
          ),
          const SizedBox(width: 8),
          _buildChip(
            context: context,
            icon: Icons.face_retouching_natural,
            label: _consultationProfileChipLabel,
            isSelected: _selectedProfile != null || _useNoConsultationProfile,
            onTap: _showProfilesDialog,
          ),
          // const SizedBox(width: 8),
          // _buildChip(
          //   context: context,
          //   icon: Icons.menu_book_outlined,
          //   label: '就医助手',
          //   isSelected: false,
          //   onTap: () {},
          // ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? theme.colorScheme.primary
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileBanner(BuildContext context) {
    final theme = Theme.of(context);
    final latestRecord = _latestHealthSnapshotRecord;
    final recordCount = _healthSnapshotRecords.length;
    final selectedProfile = _selectedProfile;
    final updatedLabel = latestRecord == null
        ? '暂无更新'
        : '更新于${_formatMonthDayTime(latestRecord.createdAt)}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F5FF).withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6BFF),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '我的健康',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1F2937),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    updatedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() {
                        _isHealthSnapshotExpanded = !_isHealthSnapshotExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _isHealthSnapshotExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isHealthSnapshotExpanded) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$recordCount份',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '报告单',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 52,
                    color: const Color(0xFFE5E7EB),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _showLatestRecordDetails,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFE8E2FF),
                          foregroundColor: const Color(0xFF5C47D6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                        ),
                        label: const Text('查看详情'),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 52,
                    color: const Color(0xFFE5E7EB),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _showProfilesDialog,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedProfile == null
                                      ? '健康档案'
                                      : _profileDisplayName(selectedProfile),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF111827),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        unawaited(_loadProfiles());
                                        unawaited(_loadConsultationRecords());
                                        unawaited(_openHealthArchive());
                                      },
                                      child: Text(
                                        '更多数据',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF6D5EF8),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 12,
                                      color: Color(0xFF6D5EF8),
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
                ],
              ),
              if (_isLoadingProfiles || _isLoadingRecords) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationSurfaceCard(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('问诊结果卡片', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (_isSavingConsultation)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          genui.Surface(
            surfaceContext: _surfaceController.contextFor(_resultSurfaceId),
          ),
          const SizedBox(height: 8),
          Text(
            kAiWatermark,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    CurrentUser? currentUser,
    bool isDrawer,
  ) {
    final theme = Theme.of(context);
    final groupedSessions = _groupedSessions(_chatSessions);

    return Container(
      color: isDrawer
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const AppLogo(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('咨询中心', style: theme.textTheme.titleMedium),
                      Text(
                        '你的 AI 健康助手',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                FilledButton.icon(
                  onPressed: _openScan,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('扫一扫'),
                ),
                const SizedBox(height: 5),
                FilledButton.icon(
                  onPressed: _openHealthMonitoring,
                  icon: const Icon(Icons.monitor_heart_outlined),
                  label: const Text('健康监测'),
                ),
                const SizedBox(height: 5),
                Visibility(
                  visible: false,
                  child: FilledButton.icon(
                  onPressed: _openScan,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('扫一扫'),
                ),
                ),
                const SizedBox(height: 5),
                FilledButton.icon(
                  onPressed: _openHealthArchive,
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: const Text('健康档案'),
                ),
                const SizedBox(height: 5),
                FilledButton.icon(
                  onPressed: _startNewConversation,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('开启新对话'),
                ),
                const SizedBox(height: 5),
                Text('对话历史', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                if (_observedToken == null)
                  _buildEmptyCard(context, '登录后会自动记录每一次咨询，方便你随时回看。')
                else if (_isLoadingSessions)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (groupedSessions.isEmpty)
                  _buildEmptyCard(context, '还没有历史对话。发送第一条消息后，系统会自动创建一条新的对话记录。')
                else
                  ...groupedSessions.entries.map(
                    (entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            entry.key,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...entry.value.map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildSessionTile(context, session),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Text('个人问诊记录', style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                if (_observedToken == null)
                  _buildEmptyCard(context, '登录后可保存问诊结果，系统会在后续问答中自动参考你的历史病例信息。')
                else if (_isLoadingRecords)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_displayedRecords.isEmpty)
                  _buildEmptyCard(
                    context,
                    _mode == 'medical' && _selectedProfile == null
                        ? '当前未选择就诊人。请选择就诊人后再进行 AI 导诊，并保存对应的问诊卡片。'
                        : _selectedProfile == null
                        ? '暂无保存的问诊结果。完成一次 AI 问诊后，可将卡片沉淀为个人病例。'
                        : '暂无${_profileDisplayName(_selectedProfile!)}的问诊记录。完成一次 AI 问诊后，可将卡片沉淀为对应咨询人的病例。',
                  )
                else
                  ..._displayedRecords.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildRecordTile(context, record),
                    ),
                  ),
              ],
            ),
          ),
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openAccountCenter,
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        AccountAvatar(
                          name: currentUser.displayName,
                          avatarKey: currentUser.avatarKey,
                          radius: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                maskName(
                                  currentUser.displayName,
                                  fallback: '用户',
                                ),
                              ),
                              Text(
                                maskPhoneNumber(
                                  currentUser.phone,
                                  fallback: '未绑定手机号',
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(BuildContext context, ChatSessionSummary session) {
    final theme = Theme.of(context);
    final isActive = _activeSessionId == session.id;

    return Builder(
      builder: (tileContext) {
        return Material(
          color: isActive
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _handleSelectChatSession(session),
            onLongPress: () {
              final RenderBox renderBox =
                  tileContext.findRenderObject() as RenderBox;
              final Size size = renderBox.size;
              final Offset offset = renderBox.localToGlobal(Offset.zero);

              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                  offset.dx,
                  offset.dy + size.height,
                  offset.dx + size.width,
                  offset.dy + size.height,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                items: [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '删除对话记录',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ).then((value) {
                if (value == 'delete') {
                  _deleteSession(session);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: isActive
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session.lastMessage?.trim().isNotEmpty == true
                              ? _stripHtmlTags(
                                  _memoizedStripCardPayload(
                                    session.lastMessage!,
                                  ),
                                ).trim()
                              : '点击查看完整对话记录',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${session.mode == 'medical' ? 'AI 导诊' : '健康问答'} · ${_formatDateTime(session.updatedAt)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
      },
    );
  }

  Widget _buildRecordTile(
    BuildContext context,
    SavedConsultationRecord record,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (record.summary?.trim().isNotEmpty == true
                      ? record.summary!.trim()
                      : record.analysis?.trim().isNotEmpty == true
                      ? record.analysis!.trim()
                      : '已保存的问诊记录'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_recordProfileName(record)} · ${_relationLabel(record.relation)}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${record.recommendedDepartment ?? '待定科室'} · ${_formatDateTime(record.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (record.hospitalSuggestion?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              record.hospitalSuggestion!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Map<String, List<ChatSessionSummary>> _groupedSessions(
    List<ChatSessionSummary> sessions,
  ) {
    final grouped = <String, List<ChatSessionSummary>>{};
    for (final session in sessions) {
      grouped
          .putIfAbsent(
            _groupLabel(session.updatedAt),
            () => <ChatSessionSummary>[],
          )
          .add(session);
    }
    return grouped;
  }

  String _groupLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 后端返回的已经是北京时间字符串（如 2026-04-20 21:04），不带时区，
    // Flutter parse 后会被认为是带了本地时区的本地时间。
    // 这里为了防止 .toLocal() 再次被偏移，我们直接将其视为当前正确的绝对时间使用。
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(target).inDays;
    if (diff <= 0) {
      return '今天';
    }
    if (diff == 1) {
      return '昨天';
    }
    return '更早';
  }

  Future<void> _showLatestRecordDetails() async {
    final record = _latestHealthSnapshotRecord;
    if (record == null) {
      _showInfoMessage('还没有可查看的报告单');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          title: Text(
            _recordProfileName(record),
            style: theme.textTheme.titleLarge,
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_relationLabel(record.relation)} · ${_formatMonthDayTime(record.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRecordDetailBlock(
                    context: dialogContext,
                    title: '摘要',
                    content: record.summary,
                  ),
                  const SizedBox(height: 12),
                  _buildRecordDetailBlock(
                    context: dialogContext,
                    title: '分析',
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
        );
      },
    );
  }

  Widget _buildRecordDetailBlock({
    required BuildContext context,
    required String title,
    required String? content,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _cleanMedicalText(content),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }

  String _formatMonthDayTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  String _profileDisplayName(HealthProfile profile) {
    return maskName(profile.name, fallback: '成员');
  }

  String _recordProfileName(SavedConsultationRecord record) {
    return maskName(record.profileName, fallback: '成员');
  }

  String _relationLabel(String relation) =>
      _relationOptions[relation] ?? relation;

  String? _nullableText(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _cleanMedicalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return '暂无信息';
    }
    return _stripHtmlTags(normalized);
  }

  _CardPayload? _memoizedParseCardPayload(String text) {
    if (_cardPayloadTextCache.length > 200) {
      _cardPayloadTextCache.clear();
    }
    return _cardPayloadTextCache.putIfAbsent(
      text,
      () => _CardPayload.parse(text),
    );
  }

  String _memoizedStripCardPayload(String text) {
    if (_stripCardTextCache.length > 200) {
      _stripCardTextCache.clear();
    }
    return _stripCardTextCache.putIfAbsent(text, () => _stripCardPayload(text));
  }

  String _stripHtmlTags(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  String _stripCardPayload(String text) {
    var stripped = text
        .replaceAll(RegExp(r'\[CARD\][\s\S]*?\[/CARD\]'), '')
        .trim();
    stripped = stripped
        .replaceAll(
          RegExp(
            r'```json\s*(\{[\s\S]*?"type"\s*:\s*"(?:question_options|medical_result)"[\s\S]*?\})\s*```',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    stripped = stripped
        .replaceAll(
          RegExp(
            r'(\{[\s\S]*?"type"\s*:\s*"(?:question_options|medical_result)"[\s\S]*?\})\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return stripped;
  }

  Future<void> _copyAssistantMessage(String content) async {
    final normalized = _stripHtmlTags(content).trim();
    if (normalized.isEmpty) {
      _showInfoMessage('当前回复暂无可复制内容');
      return;
    }

    const copySuffix = '——以上内容由AI生成，仅供参考';
    final copyText = normalized.endsWith(copySuffix)
        ? normalized
        : '$normalized\n\n$copySuffix';
    await Clipboard.setData(ClipboardData(text: copyText));
    if (!mounted) {
      return;
    }
    _showSuccessMessage('已复制回复内容');
  }

  void _showInfoMessage(String message) {
    AppMessage.showInfo(context, message);
  }

  void _showSuccessMessage(String message) {
    AppMessage.showSuccess(context, message);
  }

  Future<void> _polishMessage() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _isPolishing) return;

    setState(() => _isPolishing = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      final apiService = ApiService();
      final result = await apiService.polishChatMessage(
        text: text,
        token: token,
      );

      if (!mounted) return;

      final polishedText = result['polished'] as String?;
      if (polishedText != null && polishedText.isNotEmpty) {
        _chatInputController.text = polishedText;
        _chatInputController.selection = TextSelection.collapsed(
          offset: polishedText.length,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = ApiService.extractErrorMessage(e);
      _showErrorMessage(errorMsg);
    } finally {
      if (mounted) {
        setState(() => _isPolishing = false);
      }
    }
  }

  void _showWarningMessage(String message) {
    AppMessage.showWarning(context, message);
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
    final message = error.toString().toLowerCase();
    return message.contains('401') || message.contains('unauthorized');
  }

  Future<void> _showLoginRequiredDialog({required String message}) async {
    if (!mounted) {
      return;
    }
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('请先登录'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('暂不登录'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
    if (!mounted || shouldLogin != true) {
      return;
    }
    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    context.go('/login');
  }
}

enum _SelectedChatAttachmentStatus { uploading, processing, ready, failed }

class _SelectedChatAttachment {
  const _SelectedChatAttachment({
    required this.localId,
    required this.name,
    required this.status,
    this.fileId,
    this.progress,
    this.errorMessage,
    this.contentType,
    this.size = 0,
    this.bytes,
  });

  final String localId;
  final String name;
  final _SelectedChatAttachmentStatus status;
  final String? fileId;
  final double? progress;
  final String? errorMessage;
  final String? contentType;
  final int size;
  // 保留原始文件字节：图片附件发送时需内联重传给模型（后端不会把图片
  // fileId 交给文档提取模型，只靠 fileId 模型收不到图片内容）
  final Uint8List? bytes;

  bool get isReady => status == _SelectedChatAttachmentStatus.ready;

  String get statusLabel => switch (status) {
    _SelectedChatAttachmentStatus.uploading =>
      progress == null ? '正在上传' : '正在上传 ${(progress! * 100).round()}%',
    _SelectedChatAttachmentStatus.processing => '文件解析中',
    _SelectedChatAttachmentStatus.ready => '已上传，可开始提问',
    _SelectedChatAttachmentStatus.failed => '上传失败',
  };

  String get compactStatusLabel => switch (status) {
    _SelectedChatAttachmentStatus.uploading =>
      progress == null ? '上传中' : '${(progress! * 100).round()}%',
    _SelectedChatAttachmentStatus.processing => '解析中',
    _SelectedChatAttachmentStatus.ready => '就绪',
    _SelectedChatAttachmentStatus.failed => '失败',
  };

  _SelectedChatAttachment copyWith({
    String? localId,
    String? name,
    _SelectedChatAttachmentStatus? status,
    String? fileId,
    double? progress,
    bool clearProgress = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? contentType,
    int? size,
    Uint8List? bytes,
  }) {
    return _SelectedChatAttachment(
      localId: localId ?? this.localId,
      name: name ?? this.name,
      status: status ?? this.status,
      fileId: fileId ?? this.fileId,
      progress: clearProgress ? null : (progress ?? this.progress),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      contentType: contentType ?? this.contentType,
      size: size ?? this.size,
      bytes: bytes ?? this.bytes,
    );
  }
}

class _ChatMessageAttachment {
  const _ChatMessageAttachment({
    required this.fileId,
    required this.name,
    this.contentType,
    this.size = 0,
  });

  factory _ChatMessageAttachment.fromPayload(
    ChatSessionAttachmentPayload payload,
  ) {
    return _ChatMessageAttachment(
      fileId: payload.fileId,
      name: payload.name,
      contentType: payload.contentType,
      size: payload.size,
    );
  }

  factory _ChatMessageAttachment.fromSelected(
    _SelectedChatAttachment attachment,
  ) {
    return _ChatMessageAttachment(
      fileId: attachment.fileId ?? '',
      name: attachment.name,
      contentType: attachment.contentType,
      size: attachment.size,
    );
  }

  final String fileId;
  final String name;
  final String? contentType;
  final int size;

  ChatSessionAttachmentPayload toPayload() {
    return ChatSessionAttachmentPayload(
      fileId: fileId,
      name: name,
      contentType: contentType,
      size: size,
    );
  }

  Map<String, dynamic> toJson() => toPayload().toJson();
}

class _ReasoningPanel extends StatefulWidget {
  const _ReasoningPanel({
    required this.reasoning,
    required this.isThinking,
    required this.markdownStyleSheet,
  });

  final String reasoning;
  final bool isThinking;
  final MarkdownStyleSheet markdownStyleSheet;

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReasoning = widget.reasoning.isNotEmpty;

    if (!hasReasoning && !widget.isThinking) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_alt_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isThinking ? 'AI 正在思考' : '思考过程',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.isThinking)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: hasReasoning
                        ? MarkdownBody(
                            data: widget.reasoning,
                            selectable: true,
                            styleSheet: widget.markdownStyleSheet.copyWith(
                              p: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                              listBullet: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Text(
                            '正在生成思考内容...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      kAiWatermark,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.75,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
