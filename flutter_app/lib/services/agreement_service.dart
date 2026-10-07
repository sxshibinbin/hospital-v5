import 'dart:developer' as developer;

import 'package:flutter_app/services/api_service.dart';

class AgreementService {
  final ApiService _apiService;

  AgreementService(this._apiService);

  Future<String?> getAgreement(String type) async {
    try {
      developer.log('Fetching agreement: $type', name: 'hospital.agreement');
      final response = await _apiService.dio.get(
        '/api/public/agreements/$type',
      );
      developer.log(
        'Agreement response status: ${response.statusCode}',
        name: 'hospital.agreement',
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final rawContent = data is Map
            ? data['content']?.toString()
            : data?.toString();
        return normalizeAgreementContent(rawContent);
      }
      return null;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to get agreement $type',
        name: 'hospital.agreement',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}

String? normalizeAgreementContent(String? rawContent) {
  if (rawContent == null) {
    return null;
  }

  var content = rawContent.trim();
  if (content.isEmpty) {
    return null;
  }

  content = content
      .replaceAll(r'\r\n', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  content = _decodeHtmlEntities(content);

  final hasHtmlTags = RegExp(r'</?[a-zA-Z][^>]*>').hasMatch(content);
  if (hasHtmlTags) {
    content = content
        .replaceAll(
          RegExp(
            r'<script[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'<style[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '- ')
        .replaceAll(RegExp(r'</h[1-6]\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<h[1-6][^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
  }

  content = content
      .replaceAllMapped(
        RegExp(r'^\s{0,3}#{1,6}\s+(.+)$', multiLine: true),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'\*\*(.*?)\*\*'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(RegExp(r'__(.*?)__'), (match) => match.group(1) ?? '')
      .replaceAllMapped(RegExp(r'^\s*[-*]\s+', multiLine: true), (_) => '• ')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  return content.isEmpty ? null : content;
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&ensp;', ' ')
      .replaceAll('&emsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
}
