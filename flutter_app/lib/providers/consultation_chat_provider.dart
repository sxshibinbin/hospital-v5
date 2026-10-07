import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart' as aitk;
import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class ConsultationChatProvider extends ChangeNotifier
    implements aitk.LlmProvider {
  ConsultationChatProvider({
    required String baseUrl,
    required String mode,
    required bool thinkingEnabled,
    this.token,
    this.onConsultationCard,
    Iterable<aitk.ChatMessage>? history,
    http.Client? httpClient,
  }) : _baseUrl = baseUrl,
       _mode = mode,
       _thinkingEnabled = thinkingEnabled,
       _httpClient = httpClient ?? http.Client() {
    _history.addAll(history ?? const []);
  }

  final String _baseUrl;
  final http.Client _httpClient;
  final void Function(ConsultationCardData cardData)? onConsultationCard;

  final List<aitk.ChatMessage> _history = <aitk.ChatMessage>[];

  String _mode;
  bool _thinkingEnabled;
  String? token;
  List<String> _contextFileIds = <String>[];
  final Map<aitk.ChatMessage, Map<String, dynamic>> _aiLabelMetaByMessage =
      <aitk.ChatMessage, Map<String, dynamic>>{};

  @override
  Iterable<aitk.ChatMessage> get history => UnmodifiableListView(_history);

  List<String> get contextFileIds => List.unmodifiable(_contextFileIds);

  @override
  set history(Iterable<aitk.ChatMessage> history) {
    _history
      ..clear()
      ..addAll(history);
    _contextFileIds = <String>[];
    notifyListeners();
  }

  void updateConfiguration({
    required String mode,
    required bool thinkingEnabled,
    required String? token,
  }) {
    _mode = mode;
    _thinkingEnabled = thinkingEnabled;
    this.token = token;
  }

  void updateContextFileIds(Iterable<String> fileIds) {
    _contextFileIds = fileIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  void clearContextFileIds() {
    _contextFileIds = <String>[];
  }

  Map<String, dynamic>? aiLabelMetaForMessage(aitk.ChatMessage message) {
    final meta = _aiLabelMetaByMessage[message];
    return meta == null ? null : Map<String, dynamic>.from(meta);
  }

  void setAiLabelMetaForHistoryIndex(
    int index,
    Map<String, dynamic> meta,
  ) {
    if (index < 0 || index >= _history.length) {
      return;
    }
    _aiLabelMetaByMessage[_history[index]] = Map<String, dynamic>.from(meta);
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<aitk.Attachment> attachments = const [],
  }) {
    return _requestStream(
      contextFileIds: const <String>[],
      consultationProfileId: null,
      prompt: prompt,
      attachments: attachments,
      history: const <aitk.ChatMessage>[],
      onRawChunk: (_) {},
      onReasoningChunk: (_) {},
      onDone: () {},
      onAiLabelMeta: (_) {},
    );
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<aitk.Attachment> attachments = const [],
  }) async* {
    yield* sendMessageStreamWithCallbacks(prompt, attachments: attachments);
  }

  Stream<String> sendMessageStreamWithCallbacks(
    String prompt, {
    Iterable<aitk.Attachment> attachments = const [],
    List<String>? contextFileIds,
    int? consultationProfileId,
    void Function(String chunk)? onReasoningChunk,
  }) async* {
    final userMessage = aitk.ChatMessage.user(prompt, attachments);
    final llmMessage = aitk.ChatMessage.llm();
    _history.addAll([userMessage, llmMessage]);
    notifyListeners();

    yield* _requestStream(
      contextFileIds: contextFileIds ?? _contextFileIds,
      consultationProfileId: consultationProfileId,
      prompt: prompt,
      attachments: attachments,
      history: _history.take(_history.length - 2),
      onRawChunk: llmMessage.append,
      onReasoningChunk: onReasoningChunk ?? (_) {},
      onDone: notifyListeners,
      onAiLabelMeta: (meta) => _aiLabelMetaByMessage[llmMessage] = meta,
    );
  }

  Stream<String> _requestStream({
    required List<String> contextFileIds,
    required int? consultationProfileId,
    required String prompt,
    required Iterable<aitk.Attachment> attachments,
    required Iterable<aitk.ChatMessage> history,
    required void Function(String rawChunk) onRawChunk,
    required void Function(String reasoningChunk) onReasoningChunk,
    required VoidCallback onDone,
    required void Function(Map<String, dynamic> meta) onAiLabelMeta,
  }) async* {
    final parser = _CardStreamParser(onConsultationCard: onConsultationCard);
    final contentStabilizer = _StreamingTextStabilizer();
    final reasoningStabilizer = _StreamingTextStabilizer();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/chat'),
    );

    final promptWithLinks = _appendLinkAttachments(prompt, attachments);
    request.fields['mode'] = _mode;
    request.fields['message'] = promptWithLinks;
    request.fields['history'] = jsonEncode(
      history.map(_serializeHistoryMessage).toList(),
    );
    request.fields['thinking'] = _thinkingEnabled.toString();
    request.fields['terminal'] = 'app';
    request.fields['context_file_ids'] = jsonEncode(contextFileIds);
    if (consultationProfileId != null) {
      request.fields['consultation_profile_id'] = consultationProfileId
          .toString();
    }

    final fileAttachments = attachments.whereType<aitk.FileAttachment>();
    for (final attachment in fileAttachments) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          attachment.bytes,
          filename: attachment.name,
        ),
      );
    }

    if (token != null && token!.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${token!.trim()}';
    }
    request.headers['Accept'] = 'text/event-stream';

    final response = await _httpClient.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw Exception(_extractErrorMessage(errorBody));
    }

    await for (final event in _readSseEvents(response.stream)) {
      switch (event.type) {
        case _BackendEventType.content:
          final stableChunk = contentStabilizer.add(event.content ?? '');
          if (stableChunk.isEmpty) {
            continue;
          }
          onRawChunk(stableChunk);
          final visibleChunk = parser.consume(stableChunk);
          if (visibleChunk.isNotEmpty) {
            yield visibleChunk;
          }
        case _BackendEventType.context:
          _contextFileIds = event.fileIds;
        case _BackendEventType.aiLabel:
          if (event.meta != null) {
            onAiLabelMeta(event.meta!);
          }
        case _BackendEventType.reasoning:
          final stableChunk = reasoningStabilizer.add(event.content ?? '');
          if (stableChunk.isNotEmpty) {
            onReasoningChunk(stableChunk);
          }
          continue;
        case _BackendEventType.safety:
        case _BackendEventType.notice:
          continue;
      }
    }

    final remainingContent = contentStabilizer.flush();
    if (remainingContent.isNotEmpty) {
      onRawChunk(remainingContent);
      final visibleChunk = parser.consume(remainingContent);
      if (visibleChunk.isNotEmpty) {
        yield visibleChunk;
      }
    }

    final remainingReasoning = reasoningStabilizer.flush();
    if (remainingReasoning.isNotEmpty) {
      onReasoningChunk(remainingReasoning);
    }

    onDone();
  }

  Map<String, String> _serializeHistoryMessage(aitk.ChatMessage message) => {
    'role': message.origin.isUser ? 'user' : 'assistant',
    'content': message.text ?? '',
  };

  String _appendLinkAttachments(
    String prompt,
    Iterable<aitk.Attachment> attachments,
  ) {
    final links = attachments.whereType<aitk.LinkAttachment>().toList();
    if (links.isEmpty) {
      return prompt;
    }

    final buffer = StringBuffer(prompt.trim());
    if (buffer.isNotEmpty) {
      buffer.writeln();
      buffer.writeln();
    }
    buffer.writeln('【附加链接】');
    for (final link in links) {
      buffer.writeln('- ${link.name}: ${link.url}');
    }
    return buffer.toString().trim();
  }

  Stream<_BackendEvent> _readSseEvents(Stream<List<int>> stream) async* {
    await for (final line
        in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data:')) {
        continue;
      }

      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') {
        continue;
      }

      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }

      if (decoded['error'] case String errorMessage
          when errorMessage.isNotEmpty) {
        throw Exception(errorMessage);
      }

      final type = decoded['type'] as String?;
      if (type == 'context') {
        final fileIds = (decoded['fileIds'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();
        yield _BackendEvent.context(fileIds);
        continue;
      }

      if (type == 'ai_label') {
        final meta = decoded['meta'];
        if (meta is Map) {
          yield _BackendEvent.aiLabel(
            Map<String, dynamic>.from(meta),
          );
        }
        continue;
      }

      if (type == 'safety' || type == 'notice') {
        final text = type == 'notice'
            ? decoded['text'] as String?
            : '安全提示：此问题涉及受限医疗内容，请咨询医生获取专业建议。';
        if (text != null && text.isNotEmpty) {
          yield _BackendEvent.content(text);
        }
        continue;
      }

      final content = decoded['content'] as String?;
      if (type == 'reasoning') {
        yield _BackendEvent.reasoning(content);
        continue;
      }

      if (content != null && content.isNotEmpty) {
        yield _BackendEvent.content(content);
      }
    }
  }

  String _extractErrorMessage(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {}

    if (rawBody.trim().isNotEmpty) {
      return rawBody.trim();
    }

    return '请求失败，请稍后重试';
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}

class _CardStreamParser {
  _CardStreamParser({this.onConsultationCard});

  static const _openTag = '[CARD]';
  static const _closeTag = '[/CARD]';

  final void Function(ConsultationCardData cardData)? onConsultationCard;

  String _pending = '';
  String _cardBuffer = '';
  bool _inCard = false;

  String consume(String chunk) {
    _pending += chunk;
    final visible = StringBuffer();

    while (_pending.isNotEmpty) {
      if (!_inCard) {
        final openIndex = _pending.indexOf(_openTag);
        if (openIndex < 0) {
          visible.write(_pending);
          _pending = '';
          break;
        }

        visible.write(_pending.substring(0, openIndex));
        _pending = _pending.substring(openIndex + _openTag.length);
        _inCard = true;
        _cardBuffer = '';
        continue;
      }

      final closeIndex = _pending.indexOf(_closeTag);
      if (closeIndex < 0) {
        _cardBuffer += _pending;
        _pending = '';
        break;
      }

      _cardBuffer += _pending.substring(0, closeIndex);
      _pending = _pending.substring(closeIndex + _closeTag.length);
      _inCard = false;
      _emitCard(_cardBuffer);
      _cardBuffer = '';
    }

    return visible.toString();
  }

  void _emitCard(String rawCard) {
    try {
      final decoded = jsonDecode(rawCard);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final data = decoded['data'];
      if (decoded['type'] != 'medical_result' ||
          data is! Map<String, dynamic>) {
        return;
      }
      final cardData = ConsultationCardData.fromJson(data);
      if (cardData.hasContent) {
        onConsultationCard?.call(cardData);
      }
    } catch (_) {}
  }
}

class _StreamingTextStabilizer {
  String _pending = '';

  String add(String chunk) {
    if (chunk.isEmpty) {
      return '';
    }

    final merged = _pending + chunk;
    final stableRuneCount = _stableRuneCount(merged);
    final runes = merged.runes.toList(growable: false);

    if (stableRuneCount <= 0) {
      _pending = merged;
      return '';
    }

    final stableText = String.fromCharCodes(runes.take(stableRuneCount));
    _pending = String.fromCharCodes(runes.skip(stableRuneCount));
    return stableText;
  }

  String flush() {
    final remaining = _pending;
    _pending = '';
    return remaining;
  }

  int _stableRuneCount(String value) {
    final runes = value.runes.toList(growable: false);
    var stableCount = runes.length;

    while (stableCount > 0) {
      final lastRune = runes[stableCount - 1];
      if (_isRegionalIndicator(lastRune)) {
        stableCount -= 1;
        continue;
      }
      if (_isDeferredTrailingRune(lastRune)) {
        stableCount -= 1;
        if (lastRune == 0x200D && stableCount > 0) {
          stableCount -= 1;
        }
        continue;
      }
      break;
    }

    return stableCount;
  }

  bool _isDeferredTrailingRune(int rune) {
    return rune == 0x200D ||
        _isVariationSelector(rune) ||
        _isCombiningMark(rune) ||
        _isSkinToneModifier(rune);
  }

  bool _isVariationSelector(int rune) {
    return (rune >= 0xFE00 && rune <= 0xFE0F) ||
        (rune >= 0xE0100 && rune <= 0xE01EF);
  }

  bool _isCombiningMark(int rune) {
    return (rune >= 0x0300 && rune <= 0x036F) ||
        (rune >= 0x1AB0 && rune <= 0x1AFF) ||
        (rune >= 0x1DC0 && rune <= 0x1DFF) ||
        (rune >= 0x20D0 && rune <= 0x20FF) ||
        (rune >= 0xFE20 && rune <= 0xFE2F);
  }

  bool _isSkinToneModifier(int rune) {
    return rune >= 0x1F3FB && rune <= 0x1F3FF;
  }

  bool _isRegionalIndicator(int rune) {
    return rune >= 0x1F1E6 && rune <= 0x1F1FF;
  }
}

enum _BackendEventType { content, reasoning, context, aiLabel, safety, notice }

class _BackendEvent {
  const _BackendEvent._({
    required this.type,
    this.content,
    this.fileIds = const <String>[],
    this.meta,
  });

  const _BackendEvent.content(String content)
    : this._(type: _BackendEventType.content, content: content);

  const _BackendEvent.reasoning(String? content)
    : this._(type: _BackendEventType.reasoning, content: content);

  const _BackendEvent.context(List<String> fileIds)
    : this._(type: _BackendEventType.context, fileIds: fileIds);

  const _BackendEvent.aiLabel(Map<String, dynamic> meta)
    : this._(type: _BackendEventType.aiLabel, meta: meta);

  final _BackendEventType type;
  final String? content;
  final List<String> fileIds;
  final Map<String, dynamic>? meta;
}
