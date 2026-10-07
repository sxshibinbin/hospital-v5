import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'iot_api_client.dart';

class MetricDetailScreen extends StatefulWidget {
  final String metricName;
  final Color metricColor;
  final int deviceId;
  final String deviceImei;
  final String? deviceType;

  const MetricDetailScreen({
    super.key,
    required this.metricName,
    required this.metricColor,
    required this.deviceId,
    required this.deviceImei,
    this.deviceType,
  });

  @override
  State<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends State<MetricDetailScreen> {
  static const Color _normalGreen = Color(0xFF22A06B);
  static const Color _lowBlue = Color(0xFF3B82F6);
  static const Color _warningAmber = Color(0xFFF59E0B);
  static const Color _highRed = Color(0xFFE8453A);
  static const Color _lowPurple = Color(0xFF8B5CF6);
  static const Color _bodyMotionTeal = Color(0xFF0EA5A4);
  static const Color _systolicBeige = Color(0xFFD0A24A);
  static const Color _systolicAreaBeige = Color(0xFFFFE8B7);
  static const Color _diastolicAreaBlue = Color(0xFFDCEBFF);
  static const int _maxWeekRangeDays = 7;

  String _selectedRange = 'day';
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedWeekRange;
  int? _selectedPointIndex;
  List<_ChartDataPoint> _chartData = const [];
  bool _isLoading = false;
  String? _loadError;
  int _requestSerial = 0;

  bool get _isBloodPressure => widget.metricName == '血压';
  bool get _isSteps => widget.metricName == '步数';
  bool get _isSmartWatchDevice => widget.deviceType == '智能手表';
  bool get _isSmartBandDevice => widget.deviceType == '智能手环';
  bool get _isSmartWatchTrendMetric =>
      _isSmartWatchDevice &&
      {'心率', '体温', '血压', '步数'}.contains(widget.metricName);
  bool get _isSmartBandTrendMetric =>
      _isSmartBandDevice &&
      {'心率', '体温', '血压', '步数'}.contains(widget.metricName);
  bool get _isSleepRadarDevice => widget.deviceType == '睡眠雷达';
  bool get _isSleepRadarRangeMetric =>
      _isSleepRadarDevice && {'体动', '心率', '呼吸'}.contains(widget.metricName);
  bool get _isSleepRadarStateMetric =>
      {'睡眠状态', '离床状态', '运动状态', '存在状态'}.contains(widget.metricName);
  bool get _usesWeekRangePicker => _selectedRange == 'week';
  bool get _usesMonthPicker => _selectedRange == 'month';
  bool get _usesYearPicker => _selectedRange == 'year';
  bool get _usesBloodPressureRangeChart =>
      _isBloodPressure && _selectedRange != 'day';
  bool get _usesMetricRangeChart =>
      !_isBloodPressure && !_isSteps && _selectedRange != 'day';
  bool get _usesSleepRadarBodyMotionRangeChart =>
      _isSleepRadarDevice && widget.metricName == '体动';
  bool get _usesSleepRadarHeartRateRangeChart =>
      _isSleepRadarDevice && widget.metricName == '心率' && _usesMetricRangeChart;
  bool get _usesSleepRadarRawDayChart =>
      _isSleepRadarRangeMetric && _selectedRange == 'day';
  bool get _usesSmartWatchRawDayChart =>
      _isSmartWatchTrendMetric && _selectedRange == 'day';
  bool get _usesSmartBandRawDayChart =>
      _isSmartBandTrendMetric && _selectedRange == 'day';
  bool get _usesRawDayChart =>
      _usesSleepRadarRawDayChart ||
      _usesSmartWatchRawDayChart ||
      _usesSmartBandRawDayChart;
  bool get _hidesTrendDots =>
      _usesSleepRadarRawDayChart ||
      _isSmartWatchTrendMetric ||
      _isSmartBandTrendMetric;
  bool get _usesSleepRadarRespirationRangeChart =>
      _isSleepRadarDevice && widget.metricName == '呼吸' && _usesMetricRangeChart;
  bool get _usesSleepRadarRangeLineChart =>
      _usesSleepRadarBodyMotionRangeChart ||
      _usesSleepRadarHeartRateRangeChart ||
      _usesSleepRadarRespirationRangeChart;
  bool get _usesMetricRangeStats =>
      _usesMetricRangeChart || _usesSleepRadarRangeLineChart;
  bool get _usesSleepRadarRangeBarChart =>
      _isSleepRadarRangeMetric &&
      !_usesSleepRadarRangeLineChart &&
      _usesMetricRangeChart;

  DateTimeRange get _activeWeekRange {
    if (_selectedWeekRange != null) return _selectedWeekRange!;

    final end = _dateOnly(_selectedDate);
    return DateTimeRange(
      start: end.subtract(const Duration(days: _maxWeekRangeDays - 1)),
      end: end,
    );
  }

  _MetricReference get _metricReference {
    switch (widget.metricName) {
      case '心率':
        return const _MetricReference(
          safeLow: 60,
          safeHigh: 100,
          unit: '次/分',
          lowColor: _lowBlue,
          normalColor: _normalGreen,
          highColor: _highRed,
        );
      case '体温':
        return const _MetricReference(
          safeLow: 36.0,
          safeHigh: 37.3,
          unit: '℃',
          fractionDigits: 1,
          lowColor: _warningAmber,
          normalColor: _normalGreen,
          highColor: _highRed,
        );
      case '血氧饱和度':
        return const _MetricReference(
          criticalLow: 70,
          safeLow: 90,
          unit: '%',
          axisMax: 100,
          criticalLowColor: _highRed,
          lowColor: _warningAmber,
          normalColor: _normalGreen,
          highColor: _normalGreen,
        );
      case '血压':
        return const _MetricReference(
          safeLow: 90,
          safeHigh: 140,
          unit: 'mmHg',
          lowColor: _lowBlue,
          normalColor: _normalGreen,
          highColor: _highRed,
        );
      case '步数':
        return const _MetricReference(unit: '步', normalColor: _normalGreen);
      case '呼吸':
        return const _MetricReference(
          safeLow: 12,
          safeHigh: 20,
          unit: '次/分',
          lowColor: _warningAmber,
          normalColor: _normalGreen,
          highColor: _highRed,
        );
      case '体动':
        return const _MetricReference(unit: '', normalColor: _bodyMotionTeal);
      default:
        return const _MetricReference(unit: '', normalColor: _normalGreen);
    }
  }

  _MetricReference get _systolicReference => const _MetricReference(
    safeLow: 90,
    safeHigh: 140,
    unit: 'mmHg',
    lowColor: _lowPurple,
    normalColor: _normalGreen,
    highColor: _highRed,
  );

  _MetricReference get _diastolicReference => const _MetricReference(
    safeLow: 60,
    safeHigh: 90,
    unit: 'mmHg',
    lowColor: _lowPurple,
    normalColor: _normalGreen,
    highColor: _highRed,
  );

  String get _dateRangeText {
    switch (_selectedRange) {
      case 'day':
        return _formatDate(_selectedDate);
      case 'week':
        final range = _activeWeekRange;
        return '${_formatDate(range.start)} - ${_formatMonthDay(range.end)}';
      case 'month':
        return '${_selectedDate.year}年${_selectedDate.month}月';
      case 'year':
        return '${_selectedDate.year}年';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMetricTrend();
  }

  @override
  Widget build(BuildContext context) {
    final data = _chartData;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDE8FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2F266F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.metricName} 详情',
          style: const TextStyle(
            color: Color(0xFF2F266F),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (!_isSleepRadarStateMetric) _buildRangeSelector(),
          _buildDateSelector(),
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0ECF8), width: 1),
              ),
              child: _buildChartContent(data),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF0ECF8), width: 1),
              ),
              child: _buildDetailContent(data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContent(List<_ChartDataPoint> data) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: Color(0xFF5B57F7),
        ),
      );
    }

    if (_loadError != null) {
      return _buildStateMessage(_loadError!, showRetry: true);
    }

    if (data.isEmpty) {
      return _buildStateMessage('暂无趋势数据');
    }

    if (_isBloodPressure) return _buildBloodPressureChart(data);
    if (_isSleepRadarStateMetric) return _buildSleepRadarStateChart(data);
    return _buildMetricChart(data);
  }

  Widget _buildDetailContent(List<_ChartDataPoint> data) {
    if (_isLoading) {
      return const Center(
        child: Text(
          '数据加载中...',
          style: TextStyle(fontSize: 13, color: Color(0xFF9891B8)),
        ),
      );
    }

    if (_loadError != null) {
      return _buildStateMessage(_loadError!, showRetry: true);
    }

    if (data.isEmpty) {
      return const Center(
        child: Text(
          '暂无详情数据',
          style: TextStyle(fontSize: 13, color: Color(0xFF9891B8)),
        ),
      );
    }

    if (_selectedPointIndex != null && _selectedPointIndex! < data.length) {
      return _buildDataDetail(data[_selectedPointIndex!]);
    }

    return const Center(
      child: Text(
        '点击图表中的数据点查看详情',
        style: TextStyle(fontSize: 13, color: Color(0xFF9891B8)),
      ),
    );
  }

  Widget _buildStateMessage(String message, {bool showRetry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9891B8)),
          ),
          if (showRetry) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: _loadMetricTrend, child: const Text('重试')),
          ],
        ],
      ),
    );
  }

  Future<void> _loadMetricTrend() async {
    final itemType = _itemTypeForMetricName(widget.metricName);
    final deviceImei = widget.deviceImei.trim();
    final requestId = ++_requestSerial;

    if (itemType == null) {
      setState(() {
        _chartData = const [];
        _isLoading = false;
        _loadError = '暂不支持该指标';
        _selectedPointIndex = null;
      });
      return;
    }

    if (deviceImei.isEmpty) {
      setState(() {
        _chartData = const [];
        _isLoading = false;
        _loadError = '缺少设备IMEI';
        _selectedPointIndex = null;
      });
      return;
    }

    final requestRange = _requestDateRange();
    setState(() {
      _isLoading = true;
      _loadError = null;
      _selectedPointIndex = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      var userId = authProvider.currentUser?.id;
      if (userId == null) {
        await authProvider.refreshCurrentUser();
        if (!mounted || requestId != _requestSerial) return;
        userId = authProvider.currentUser?.id;
      }

      if (userId == null) {
        setState(() {
          _chartData = const [];
          _isLoading = false;
          _loadError = '请先登录后再查看趋势数据';
          _selectedPointIndex = null;
        });
        return;
      }

      final payload = await iotPostJson(
        context,
        '/api/iot/device/metric/trend',
        body: {
          'userId': userId,
          'deviceImei': deviceImei,
          'itemType': itemType,
          'queryType': _queryTypeForSelectedRange(),
          'startDate': _formatApiDate(requestRange.start),
          'endDate': _formatApiDate(requestRange.end),
        },
        operation: 'load IoT metric trend',
      );

      if (!mounted || requestId != _requestSerial) return;

      if (payload['success'] != true) {
        throw Exception(_extractErrorMessage(payload));
      }

      final message = _asStringMap(payload['message']);
      final dataNode = _asStringMap(message?['data']);
      if (dataNode == null) {
        throw const FormatException('接口返回缺少趋势数据');
      }

      final points = _parseTrendPoints(dataNode);
      setState(() {
        _chartData = points;
        _isLoading = false;
        _loadError = null;
        _selectedPointIndex = points.isEmpty ? null : points.length - 1;
      });
    } catch (e) {
      if (!mounted || requestId != _requestSerial) return;
      setState(() {
        _chartData = const [];
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _selectedPointIndex = null;
      });
    }
  }

  int? _itemTypeForMetricName(String metricName) {
    switch (metricName) {
      case '心率':
        return 0;
      case '血氧饱和度':
      case '血氧':
        return 1;
      case '血压':
        return 2;
      case '体温':
        return 3;
      case '步数':
        return 4;
      case '体动':
        return 5;
      case '呼吸':
        return 6;
      case '睡眠状态':
        return 7;
      case '离床状态':
        return 8;
      case '运动状态':
        return 9;
      case '存在状态':
        return 10;
      default:
        return null;
    }
  }

  int _queryTypeForSelectedRange() {
    if (_isSleepRadarStateMetric) return 0;
    switch (_selectedRange) {
      case 'week':
        return 1;
      case 'month':
        return 2;
      case 'year':
        return 3;
      default:
        return 0;
    }
  }

  DateTimeRange _requestDateRange() {
    if (_isSleepRadarStateMetric) {
      final selectedDay = _dateOnly(_selectedDate);
      return DateTimeRange(start: selectedDay, end: selectedDay);
    }
    switch (_selectedRange) {
      case 'week':
        return _activeWeekRange;
      case 'month':
        return DateTimeRange(
          start: DateTime(_selectedDate.year, _selectedDate.month),
          end: DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
        );
      case 'year':
        return DateTimeRange(
          start: DateTime(_selectedDate.year),
          end: DateTime(_selectedDate.year, 12, 31),
        );
      default:
        final selectedDay = _dateOnly(_selectedDate);
        return DateTimeRange(start: selectedDay, end: selectedDay);
    }
  }

  String _extractErrorMessage(Map<String, dynamic> payload) {
    final message = payload['message'];
    if (message is String && message.isNotEmpty) return message;
    final messageMap = _asStringMap(message);
    final msg = messageMap?['msg'] ?? payload['msg'];
    if (msg != null && msg.toString().isNotEmpty) return msg.toString();
    return '接口请求失败';
  }

  List<_ChartDataPoint> _parseTrendPoints(Map<String, dynamic> dataNode) {
    final series = dataNode['series'];
    if (series is! List) return const [];

    if (_isBloodPressure) {
      return _parseBloodPressureTrendPoints(series);
    }

    final seriesNode = series.isEmpty ? null : _asStringMap(series.first);
    final pointNodes = _pointNodesOf(seriesNode);
    if (_isSleepRadarStateMetric) {
      return _parseSleepRadarStateTrendPoints(pointNodes);
    }
    final reference = _metricReference;
    if (_isSteps && _selectedRange == 'day') {
      return _parseStepDayTrendPoints(pointNodes, reference);
    }

    final result = <_ChartDataPoint>[];

    for (final pointNode in pointNodes) {
      final value = _primaryPointValue(pointNode);
      if (value == null) continue;

      result.add(
        _ChartDataPoint(
          label: _pointLabel(pointNode),
          value: _roundMetricValue(value, reference),
          minValue: _usesMetricRangeStats
              ? _roundMetricValue(
                  _asDouble(pointNode['minValue']) ?? value,
                  reference,
                )
              : null,
          maxValue: _usesMetricRangeStats
              ? _roundMetricValue(
                  _asDouble(pointNode['maxValue']) ?? value,
                  reference,
                )
              : null,
          time: _pointDisplayTime(pointNode),
        ),
      );
    }

    return result;
  }

  List<_ChartDataPoint> _parseSleepRadarStateTrendPoints(
    List<Map<String, dynamic>> pointNodes,
  ) {
    final result = <_ChartDataPoint>[];

    for (final pointNode in pointNodes) {
      final rawValue = pointNode['lastValue'] ?? pointNode['avgValue'];
      final value = _sleepRadarStateCode(rawValue);
      if (value == null) continue;
      final stateText =
          _sleepRadarStateRawText(rawValue) ?? _sleepRadarStateText(value);

      result.add(
        _ChartDataPoint(
          label: _pointLabel(pointNode),
          value: value.roundToDouble(),
          displayValue: stateText,
          time: _pointDisplayTime(pointNode),
        ),
      );
    }

    return result;
  }

  List<_ChartDataPoint> _parseStepDayTrendPoints(
    List<Map<String, dynamic>> pointNodes,
    _MetricReference reference,
  ) {
    final result = <_ChartDataPoint>[];
    double? lastKnownValue;
    String? lastReportTime;

    for (final pointNode in pointNodes) {
      if (!_shouldIncludeStepDayBucket(pointNode)) continue;

      final value = _primaryPointValue(pointNode);
      if (value != null) {
        lastKnownValue = _roundMetricValue(value, reference);
        lastReportTime = _pointDisplayTime(pointNode);
        result.add(
          _ChartDataPoint(
            label: _pointLabel(pointNode),
            value: lastKnownValue,
            time: lastReportTime,
          ),
        );
        continue;
      }

      if (lastKnownValue == null) continue;
      result.add(
        _ChartDataPoint(
          label: _pointLabel(pointNode),
          value: lastKnownValue,
          time: _pointBucketDisplayTime(pointNode),
          sourceTime: lastReportTime,
          isCarriedForward: true,
        ),
      );
    }

    return result;
  }

  List<_ChartDataPoint> _parseBloodPressureTrendPoints(List series) {
    final systolicSeries = _seriesNodeByKey(series, 'systolic');
    final diastolicSeries = _seriesNodeByKey(series, 'diastolic');
    if (systolicSeries == null || diastolicSeries == null) return const [];

    final diastolicPointsByKey = <String, Map<String, dynamic>>{};
    for (final pointNode in _pointNodesOf(diastolicSeries)) {
      diastolicPointsByKey[_pointMatchKey(pointNode)] = pointNode;
    }

    final result = <_ChartDataPoint>[];
    for (final systolicPoint in _pointNodesOf(systolicSeries)) {
      final diastolicPoint =
          diastolicPointsByKey[_pointMatchKey(systolicPoint)];
      if (diastolicPoint == null) continue;

      final systolic = _primaryPointValue(systolicPoint);
      final diastolic = _primaryPointValue(diastolicPoint);
      if (systolic == null || diastolic == null) continue;

      result.add(
        _ChartDataPoint(
          label: _pointLabel(systolicPoint),
          value: _roundMetricValue(systolic, _systolicReference),
          minValue: _usesBloodPressureRangeChart
              ? _roundMetricValue(
                  _asDouble(systolicPoint['minValue']) ?? systolic,
                  _systolicReference,
                )
              : null,
          maxValue: _usesBloodPressureRangeChart
              ? _roundMetricValue(
                  _asDouble(systolicPoint['maxValue']) ?? systolic,
                  _systolicReference,
                )
              : null,
          secondaryValue: _roundMetricValue(diastolic, _diastolicReference),
          secondaryMinValue: _usesBloodPressureRangeChart
              ? _roundMetricValue(
                  _asDouble(diastolicPoint['minValue']) ?? diastolic,
                  _diastolicReference,
                )
              : null,
          secondaryMaxValue: _usesBloodPressureRangeChart
              ? _roundMetricValue(
                  _asDouble(diastolicPoint['maxValue']) ?? diastolic,
                  _diastolicReference,
                )
              : null,
          time: _pointDisplayTime(systolicPoint),
        ),
      );
    }

    return result;
  }

  Map<String, dynamic>? _seriesNodeByKey(List series, String key) {
    for (final item in series) {
      final node = _asStringMap(item);
      if (node != null && node['key'] == key) return node;
    }
    return null;
  }

  List<Map<String, dynamic>> _pointNodesOf(Map<String, dynamic>? seriesNode) {
    final points = seriesNode?['points'];
    if (points is! List) return const [];
    return points.map(_asStringMap).whereType<Map<String, dynamic>>().toList();
  }

  double? _primaryPointValue(Map<String, dynamic> pointNode) {
    if (_isSteps) {
      return _asDouble(pointNode['totalValue']) ??
          _asDouble(pointNode['lastValue']) ??
          _asDouble(pointNode['avgValue']);
    }
    return _asDouble(pointNode['avgValue']) ??
        _asDouble(pointNode['lastValue']);
  }

  String _pointLabel(Map<String, dynamic> pointNode) {
    final label = pointNode['label']?.toString();
    if (label != null && label.isNotEmpty) return label;
    final bucketStart = pointNode['bucketStart']?.toString();
    if (bucketStart != null && bucketStart.isNotEmpty) {
      return _fallbackLabelFromTime(bucketStart);
    }
    return '';
  }

  String _pointDisplayTime(Map<String, dynamic> pointNode) {
    final reportTime = pointNode['reportTime']?.toString();
    if (reportTime != null && reportTime.isNotEmpty) {
      return _formatResponseTime(reportTime);
    }

    final bucketStart = pointNode['bucketStart']?.toString();
    if (bucketStart != null && bucketStart.isNotEmpty) {
      return _formatResponseTime(bucketStart);
    }

    return _pointLabel(pointNode);
  }

  String _pointBucketDisplayTime(Map<String, dynamic> pointNode) {
    final bucketStart = pointNode['bucketStart']?.toString();
    if (bucketStart != null && bucketStart.isNotEmpty) {
      return _formatResponseTime(bucketStart);
    }

    return _pointLabel(pointNode);
  }

  bool _shouldIncludeStepDayBucket(Map<String, dynamic> pointNode) {
    final bucketStartText = pointNode['bucketStart']?.toString();
    if (bucketStartText == null || bucketStartText.isEmpty) return true;

    final bucketStart = DateTime.tryParse(
      bucketStartText.replaceFirst(' ', 'T'),
    );
    if (bucketStart == null) return true;

    final selectedDay = _dateOnly(_selectedDate);
    final today = _dateOnly(DateTime.now());
    if (selectedDay.isBefore(today)) return true;
    if (selectedDay.isAfter(today)) return false;

    return !bucketStart.isAfter(DateTime.now());
  }

  String _pointMatchKey(Map<String, dynamic> pointNode) {
    final bucketStart = pointNode['bucketStart']?.toString();
    if (bucketStart != null && bucketStart.isNotEmpty) return bucketStart;
    return _pointLabel(pointNode);
  }

  String _fallbackLabelFromTime(String value) {
    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed == null) return value;
    switch (_selectedRange) {
      case 'day':
        return '${parsed.hour.toString().padLeft(2, '0')}:00';
      case 'year':
        return '${parsed.month}月';
      case 'month':
        return '${parsed.day}';
      default:
        return '${parsed.month}/${parsed.day}';
    }
  }

  String _formatResponseTime(String value) {
    final parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed == null) return value;
    switch (_selectedRange) {
      case 'day':
        return '${_formatDate(parsed)} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
      case 'year':
        return '${parsed.year}年${parsed.month}月';
      default:
        return _formatDate(parsed);
    }
  }

  String _formatApiDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: ['day', 'week', 'month', 'year'].map((range) {
          final labels = {'day': '日', 'week': '周', 'month': '月', 'year': '年'};
          final isSelected = _selectedRange == range;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: range == 'year' ? 0 : 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRange = range;
                    _selectedPointIndex = null;
                  });
                  _loadMetricTrend();
                },
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF5B57F7) : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF5B57F7)
                          : const Color(0xFFE7E3F5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF5B57F7,
                              ).withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      labels[range]!,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF6B6490),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateSelector() {
    if (_isSleepRadarStateMetric) {
      return _buildSleepRadarStateDateSelector();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openDatePicker,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: Color(0xFF6B6490),
            ),
            const SizedBox(width: 6),
            Text(
              _dateRangeText,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B6490),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepRadarStateDateSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          _buildSleepRadarStateDateButton(
            label: '前一天',
            dayOffset: -1,
            icon: Icons.chevron_left,
            alignment: Alignment.centerLeft,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openDatePicker,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: Color(0xFF6B6490),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _dateRangeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B6490),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildSleepRadarStateDateButton(
            label: '后一天',
            dayOffset: 1,
            icon: Icons.chevron_right,
            alignment: Alignment.centerRight,
            iconAfterText: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSleepRadarStateDateButton({
    required String label,
    required int dayOffset,
    required IconData icon,
    required Alignment alignment,
    bool iconAfterText = false,
  }) {
    return SizedBox(
      width: 88,
      height: 34,
      child: Align(
        alignment: alignment,
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: const Color(0xFF5B57F7),
            backgroundColor: const Color(0xFFF2EFFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _changeSleepRadarStateDate(dayOffset),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!iconAfterText) ...[
                Icon(icon, size: 16),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (iconAfterText) ...[
                const SizedBox(width: 2),
                Icon(icon, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeSleepRadarStateDate(int dayOffset) async {
    setState(() {
      _selectedDate = _dateOnly(_selectedDate).add(Duration(days: dayOffset));
      _selectedWeekRange = null;
      _selectedPointIndex = null;
    });
    await _loadMetricTrend();
  }

  Future<void> _openDatePicker() async {
    if (_usesWeekRangePicker) {
      await _openWeekRangePicker();
      return;
    }
    if (_usesMonthPicker) {
      await _openMonthPicker();
      return;
    }
    if (_usesYearPicker) {
      await _openYearPicker();
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      helpText: _datePickerTitle(),
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _selectedWeekRange = null;
      _selectedPointIndex = null;
    });
    await _loadMetricTrend();
  }

  Future<void> _openMonthPicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        var selectedYear = _selectedDate.year;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('选择月份'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<int>(
                      value: selectedYear,
                      isExpanded: true,
                      items: List.generate(4, (index) {
                        final year = 2024 + index;
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text('$year年'),
                        );
                      }),
                      onChanged: (year) {
                        if (year == null) return;
                        setDialogState(() => selectedYear = year);
                      },
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            mainAxisExtent: 48,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final isSelected =
                            selectedYear == _selectedDate.year &&
                            month == _selectedDate.month;
                        return OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 0,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: isSelected
                                ? const Color(0xFF5B57F7)
                                : Colors.white,
                            foregroundColor: isSelected
                                ? Colors.white
                                : const Color(0xFF2F266F),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF5B57F7)
                                  : const Color(0xFFE7E3F5),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(
                              dialogContext,
                            ).pop(DateTime(selectedYear, month));
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$month月',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month);
      _selectedWeekRange = null;
      _selectedPointIndex = null;
    });
    await _loadMetricTrend();
  }

  Future<void> _openYearPicker() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('选择年份'),
          content: SizedBox(
            width: 260,
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              childAspectRatio: 2.6,
              children: List.generate(4, (index) {
                final year = 2024 + index;
                final isSelected = year == _selectedDate.year;
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isSelected
                        ? const Color(0xFF5B57F7)
                        : Colors.white,
                    foregroundColor: isSelected
                        ? Colors.white
                        : const Color(0xFF2F266F),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF5B57F7)
                          : const Color(0xFFE7E3F5),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(year),
                  child: Text('$year年'),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked);
      _selectedWeekRange = null;
      _selectedPointIndex = null;
    });
    await _loadMetricTrend();
  }

  Future<void> _openWeekRangePicker() async {
    final firstDate = DateTime(2024, 1, 1);
    final lastDate = DateTime(2027, 12, 31);
    final activeRange = _activeWeekRange;
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        var visibleMonth = DateTime(
          activeRange.end.year,
          activeRange.end.month,
        );
        var selectedStart = _dateOnly(activeRange.start);
        var selectedEnd = _dateOnly(activeRange.end);
        var hasRangeError = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final days = _monthGridDays(visibleMonth);
            final canGoPrevious = visibleMonth.isAfter(
              DateTime(firstDate.year, firstDate.month),
            );
            final canGoNext = visibleMonth.isBefore(
              DateTime(lastDate.year, lastDate.month),
            );

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              actionsPadding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              title: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: canGoPrevious
                        ? () {
                            setDialogState(() {
                              visibleMonth = _addMonths(visibleMonth, -1);
                              hasRangeError = false;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  Expanded(
                    child: Text(
                      '${visibleMonth.year}年${visibleMonth.month}月',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2F266F),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: canGoNext
                        ? () {
                            setDialogState(() {
                              visibleMonth = _addMonths(visibleMonth, 1);
                              hasRangeError = false;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                ],
              ),
              content: SizedBox(
                width: 304,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5FD),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE7E3F5)),
                      ),
                      child: Text(
                        '${_formatMonthDay(selectedStart)} - ${_formatMonthDay(selectedEnd)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B6490),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: const ['日', '一', '二', '三', '四', '五', '六']
                          .map(
                            (label) => Expanded(
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9891B8),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: days.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final isCurrentMonth = day.month == visibleMonth.month;
                        final isDisabled =
                            _isBeforeDate(day, firstDate) ||
                            _isAfterDate(day, lastDate);
                        final isEdge =
                            _isSameDate(day, selectedStart) ||
                            _isSameDate(day, selectedEnd);
                        final isInRange = _isDateInRange(
                          day,
                          selectedStart,
                          selectedEnd,
                        );

                        Color backgroundColor = Colors.transparent;
                        Color textColor = isCurrentMonth
                            ? const Color(0xFF2F266F)
                            : const Color(0xFFC9C2DB);
                        if (isInRange) {
                          backgroundColor = const Color(
                            0xFF5B57F7,
                          ).withValues(alpha: 0.12);
                          textColor = const Color(0xFF5B57F7);
                        }
                        if (isEdge) {
                          backgroundColor = const Color(0xFF5B57F7);
                          textColor = Colors.white;
                        }
                        if (isDisabled) {
                          textColor = const Color(0xFFD8D2E7);
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: isDisabled
                              ? null
                              : () {
                                  final selectedDay = _dateOnly(day);
                                  setDialogState(() {
                                    hasRangeError = false;
                                    if (_isAfterDate(
                                          selectedStart,
                                          selectedEnd,
                                        ) ||
                                        !_isSameDate(
                                              selectedStart,
                                              selectedEnd,
                                            ) &&
                                            !_isDateInRange(
                                              selectedDay,
                                              selectedStart,
                                              selectedEnd,
                                            )) {
                                      selectedStart = selectedDay;
                                      selectedEnd = selectedDay;
                                      return;
                                    }

                                    if (_isBeforeDate(
                                      selectedDay,
                                      selectedStart,
                                    )) {
                                      selectedStart = selectedDay;
                                      selectedEnd = selectedDay;
                                      return;
                                    }

                                    final candidate = DateTimeRange(
                                      start: selectedStart,
                                      end: selectedDay,
                                    );
                                    if (_rangeDayCount(candidate) >
                                        _maxWeekRangeDays) {
                                      hasRangeError = true;
                                      return;
                                    }
                                    selectedEnd = selectedDay;
                                  });
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isEdge
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 18,
                      child: Text(
                        hasRangeError ? '周维度最多选择7天' : '最多选择7天',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasRangeError
                              ? _highRed
                              : const Color(0xFF9891B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5B57F7),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      DateTimeRange(start: selectedStart, end: selectedEnd),
                    );
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked == null || !mounted) return;

    final normalized = DateTimeRange(
      start: _dateOnly(picked.start),
      end: _dateOnly(picked.end),
    );
    if (_rangeDayCount(normalized) > _maxWeekRangeDays) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('周维度最多选择7天')));
      return;
    }

    setState(() {
      _selectedWeekRange = normalized;
      _selectedDate = normalized.end;
      _selectedPointIndex = null;
    });
    await _loadMetricTrend();
  }

  String _datePickerTitle() {
    switch (_selectedRange) {
      case 'week':
        return '选择时间段';
      case 'month':
        return '选择月份';
      case 'year':
        return '选择年份';
      default:
        return '选择日期';
    }
  }

  Widget _buildMetricChart(List<_ChartDataPoint> data) {
    if (_usesSleepRadarRangeLineChart) {
      return _buildMetricRangeChart(data);
    }

    if (_usesSleepRadarRangeBarChart) {
      return _buildSleepRadarRangeBarChart(data);
    }

    if (_usesMetricRangeChart) {
      return _buildMetricRangeChart(data);
    }

    return _buildLineChart(
      data: data,
      valueOf: (point) => point.value,
      reference: _metricReference,
      seriesName: widget.metricName,
      showBottomTitles: true,
    );
  }

  Widget _buildSleepRadarRangeBarChart(List<_ChartDataPoint> data) {
    final reference = _metricReference;
    final bounds = _getMetricRangeYBounds(data, reference);
    final minY = bounds.minY;
    final maxY = bounds.maxY;
    final barWidth = _sleepRadarRangeBarWidth(data.length);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: _sleepRadarRangeGroupsSpace(data.length),
        rangeAnnotations: _buildRangeAnnotations(reference, minY, maxY),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getHorizontalInterval(minY, maxY),
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Color(0xFFF0ECF8), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: _getBottomInterval(data.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    data[index].label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9891B8),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: _getHorizontalInterval(minY, maxY),
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatAxisValue(value, reference),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9891B8),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) =>
                const Color(0xFF2F266F).withValues(alpha: 0.9),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final index = group.x.clamp(0, data.length - 1);
              final point = data[index];
              final minValue = point.minValue ?? point.value;
              final maxValue = point.maxValue ?? point.value;
              final unitText = reference.unit.isEmpty
                  ? ''
                  : ' ${reference.unit}';
              return BarTooltipItem(
                '${_metricRangeTooltipTitle(point)}$unitText\n'
                '平均 ${_formatAxisValue(point.value, reference)}\n'
                '范围 ${_formatAxisValue(minValue, reference)}-'
                '${_formatAxisValue(maxValue, reference)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              );
            },
          ),
          touchCallback: (event, response) {
            if (response?.spot != null) {
              setState(() {
                _selectedPointIndex = response!.spot!.touchedBarGroup.x;
              });
            }
          },
        ),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;
          final minValue = point.minValue ?? point.value;
          final maxValue = point.maxValue ?? point.value;
          final visualBounds = _rangeBarVisualBounds(
            minValue: minValue,
            maxValue: maxValue,
            minY: minY,
            maxY: maxY,
          );
          final color = _rangeColor(reference, minValue, maxValue);
          final isSelected = index == _selectedPointIndex;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                fromY: visualBounds.min,
                toY: visualBounds.max,
                width: isSelected ? barWidth + 2 : barWidth,
                color: color.withValues(alpha: isSelected ? 0.95 : 0.7),
                borderRadius: BorderRadius.circular(barWidth / 2),
                borderSide: isSelected
                    ? BorderSide(color: color, width: 1.4)
                    : BorderSide.none,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSleepRadarStateChart(List<_ChartDataPoint> data) {
    final levels = _sleepRadarStateChartLevels();
    final maxCode = levels.map((level) => level.value).reduce(max).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        groupsSpace: 10,
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: levels.map((level) {
            return HorizontalRangeAnnotation(
              y1: level.value - 0.5,
              y2: level.value + 0.5,
              color: level.color.withValues(alpha: 0.12),
            );
          }).toList(),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Color(0xFFF0ECF8), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: _getBottomInterval(data.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    data[index].label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9891B8),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final code = value.round();
                _StateMetricLevel? level;
                for (final item in levels) {
                  if (item.value == code) {
                    level = item;
                    break;
                  }
                }
                if (level == null || (value - code).abs() > 0.01) {
                  return const SizedBox.shrink();
                }
                return Text(
                  level.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B6490),
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: -0.5,
        maxY: maxCode + 0.5,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) =>
                const Color(0xFF2F266F).withValues(alpha: 0.9),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final index = group.x.clamp(0, data.length - 1);
              final point = data[index];
              final label =
                  point.displayValue ?? _sleepRadarStateText(point.value);
              return BarTooltipItem(
                '${widget.metricName} $label\n${point.time}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
          touchCallback: (event, response) {
            if (response?.spot != null) {
              setState(() {
                _selectedPointIndex = response!.spot!.touchedBarGroup.x;
              });
            }
          },
        ),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final point = entry.value;
          final value = _sleepRadarStateVisualValue(point.value);
          final color = _sleepRadarStateColor(point.value);
          final isSelected = index == _selectedPointIndex;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                fromY: value - 0.36,
                toY: value + 0.36,
                width: isSelected ? 10 : 7,
                color: color.withValues(alpha: isSelected ? 0.95 : 0.82),
                borderRadius: BorderRadius.circular(6),
                borderSide: isSelected
                    ? BorderSide(color: color, width: 1.4)
                    : BorderSide.none,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricRangeChart(List<_ChartDataPoint> data) {
    final reference = _metricReference;
    final bounds = _getMetricRangeYBounds(data, reference);
    final minY = bounds.minY;
    final maxY = bounds.maxY;
    final rangeBars = _buildMetricRangeBars(data, reference);

    return LineChart(
      LineChartData(
        rangeAnnotations: _buildRangeAnnotations(reference, minY, maxY),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getHorizontalInterval(minY, maxY),
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Color(0xFFF0ECF8), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: _getBottomInterval(data.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[index].label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9891B8),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: _getHorizontalInterval(minY, maxY),
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatAxisValue(value, reference),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9891B8),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: _lineChartMaxX(data),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (barData, spotIndexes) {
            if (_isMetricNonInteractiveBar(barData)) {
              return spotIndexes
                  .map<TouchedSpotIndicatorData?>((_) => null)
                  .toList();
            }
            return defaultTouchedIndicators(barData, spotIndexes);
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) =>
                const Color(0xFF2F266F).withValues(alpha: 0.9),
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) {
              return _buildMetricRangeTooltipItems(
                spots,
                data,
                rangeBars.pointIndexes,
                reference,
              );
            },
          ),
          touchCallback: (event, response) {
            if (response?.lineBarSpots != null &&
                response!.lineBarSpots!.isNotEmpty) {
              final index = _metricTouchedIndex(
                response.lineBarSpots!.first,
                data.length,
                rangeBars.pointIndexes,
              );
              setState(() {
                _selectedPointIndex = index;
              });
            }
          },
        ),
        lineBarsData: [
          ...rangeBars.bars,
          _buildMetricAverageLineBar(data: data, reference: reference),
        ],
      ),
    );
  }

  List<LineTooltipItem?> _buildMetricRangeTooltipItems(
    List<LineBarSpot> spots,
    List<_ChartDataPoint> data,
    List<int> rangeBarPointIndexes,
    _MetricReference reference,
  ) {
    if (spots.isEmpty) return [];

    final index = _metricTouchedIndex(
      spots.first,
      data.length,
      rangeBarPointIndexes,
    );
    final point = data[index];
    final minValue = point.minValue ?? point.value;
    final maxValue = point.maxValue ?? point.value;
    final unitText = reference.unit.isEmpty ? '' : ' ${reference.unit}';
    var hasTooltip = false;

    return spots.map<LineTooltipItem?>((spot) {
      final spotIndex = _metricTouchedIndex(
        spot,
        data.length,
        rangeBarPointIndexes,
      );
      if (hasTooltip || spotIndex != index) return null;

      hasTooltip = true;
      return LineTooltipItem(
        '${_metricRangeTooltipTitle(point)}$unitText\n'
        '平均 ${_formatAxisValue(point.value, reference)}\n'
        '范围 ${_formatAxisValue(minValue, reference)}-'
        '${_formatAxisValue(maxValue, reference)}',
        const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      );
    }).toList();
  }

  String _metricRangeTooltipTitle(_ChartDataPoint point) {
    switch (_selectedRange) {
      case 'month':
        return '${_selectedDate.month}/${point.label}';
      default:
        return point.label;
    }
  }

  bool _isMetricNonInteractiveBar(LineChartBarData barData) {
    return !barData.dotData.show;
  }

  int _metricTouchedIndex(
    LineBarSpot spot,
    int dataLength,
    List<int> rangeBarPointIndexes,
  ) {
    if (spot.barIndex >= 0 && spot.barIndex < rangeBarPointIndexes.length) {
      return _clampDataIndex(rangeBarPointIndexes[spot.barIndex], dataLength);
    }
    return _clampDataIndex(spot.x.round(), dataLength);
  }

  Widget _buildBloodPressureChart(List<_ChartDataPoint> data) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBloodPressureLegendItem(
              label: '高压',
              color: _systolicBeige,
              isDashed: false,
              showRange: _usesBloodPressureRangeChart,
            ),
            const SizedBox(width: 18),
            _buildBloodPressureLegendItem(
              label: '低压',
              color: _lowBlue,
              isDashed: true,
              showRange: _usesBloodPressureRangeChart,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildBloodPressureLineChart(data)),
      ],
    );
  }

  Widget _buildBloodPressureLegendItem({
    required String label,
    required Color color,
    required bool isDashed,
    required bool showRange,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 8,
          child: CustomPaint(
            painter: _LegendLinePainter(
              color: color,
              isDashed: isDashed,
              showRange: showRange,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B6490),
          ),
        ),
      ],
    );
  }

  Widget _buildBloodPressureLineChart(List<_ChartDataPoint> data) {
    final bounds = _getBloodPressureYBounds(data);
    final minY = bounds.minY;
    final maxY = bounds.maxY;
    final usesRangeChart = _usesBloodPressureRangeChart;
    final rangeBars = usesRangeChart
        ? _buildBloodPressureRangeBars(data)
        : const _BloodPressureRangeBars();

    return LineChart(
      LineChartData(
        rangeAnnotations: _buildBloodPressureRangeAnnotations(minY, maxY),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getHorizontalInterval(minY, maxY),
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Color(0xFFF0ECF8), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: _getBottomInterval(data.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[index].label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9891B8),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: _getHorizontalInterval(minY, maxY),
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9891B8),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: _lineChartMaxX(data),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (barData, spotIndexes) {
            if (_isBloodPressureNonInteractiveBar(barData)) {
              return spotIndexes
                  .map<TouchedSpotIndicatorData?>((_) => null)
                  .toList();
            }
            return defaultTouchedIndicators(barData, spotIndexes);
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) =>
                const Color(0xFF2F266F).withValues(alpha: 0.9),
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) {
              if (usesRangeChart) {
                return _buildBloodPressureRangeTooltipItems(
                  spots,
                  data,
                  rangeBars.pointIndexes,
                );
              }

              return _buildBloodPressurePointTooltipItems(spots, data);
            },
          ),
          touchCallback: (event, response) {
            if (response?.lineBarSpots != null &&
                response!.lineBarSpots!.isNotEmpty) {
              final spot = response.lineBarSpots!.first;
              final index = _bloodPressureTouchedIndex(
                spot,
                data.length,
                rangeBars.pointIndexes,
              );
              setState(() {
                _selectedPointIndex = index;
              });
            }
          },
        ),
        lineBarsData: [
          if (usesRangeChart) ...[
            ...rangeBars.bars,
            _buildBloodPressureLineBar(
              data: data,
              valueOf: (point) => point.value,
              reference: _systolicReference,
              lineColor: _systolicBeige,
              normalDotColor: _systolicBeige,
            ),
            _buildBloodPressureLineBar(
              data: data,
              valueOf: (point) => point.secondaryValue ?? point.value,
              reference: _diastolicReference,
              lineColor: _lowBlue,
              normalDotColor: _lowBlue,
              dashArray: const [6, 4],
            ),
          ] else ...[
            ..._buildBloodPressureSegmentedLineBars(
              data: data,
              valueOf: (point) => point.value,
              reference: _systolicReference,
              normalLineColor: _systolicBeige,
            ),
            ..._buildBloodPressureSegmentedLineBars(
              data: data,
              valueOf: (point) => point.secondaryValue ?? point.value,
              reference: _diastolicReference,
              normalLineColor: _lowBlue,
              dashArray: const [6, 4],
            ),
            _buildBloodPressurePointLayer(
              data: data,
              valueOf: (point) => point.value,
              reference: _systolicReference,
              normalDotColor: _systolicBeige,
            ),
            _buildBloodPressurePointLayer(
              data: data,
              valueOf: (point) => point.secondaryValue ?? point.value,
              reference: _diastolicReference,
              normalDotColor: _lowBlue,
            ),
          ],
        ],
      ),
    );
  }

  List<LineTooltipItem?> _buildBloodPressurePointTooltipItems(
    List<LineBarSpot> spots,
    List<_ChartDataPoint> data,
  ) {
    if (spots.isEmpty) return [];

    final index = _clampDataIndex(spots.first.x.round(), data.length);
    final point = data[index];
    final diastolic = point.secondaryValue ?? point.value;
    var hasTooltip = false;

    return spots.map<LineTooltipItem?>((spot) {
      final spotIndex = _clampDataIndex(spot.x.round(), data.length);
      if (hasTooltip || spotIndex != index) return null;

      hasTooltip = true;
      return LineTooltipItem(
        '${point.label} mmHg\n'
        '高压 ${_formatAxisValue(point.value, _systolicReference)}\n'
        '低压 ${_formatAxisValue(diastolic, _diastolicReference)}',
        const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      );
    }).toList();
  }

  bool _isBloodPressureNonInteractiveBar(LineChartBarData barData) {
    return !barData.dotData.show;
  }

  List<LineTooltipItem?> _buildBloodPressureRangeTooltipItems(
    List<LineBarSpot> spots,
    List<_ChartDataPoint> data,
    List<int> rangeBarPointIndexes,
  ) {
    if (spots.isEmpty) return [];

    final index = _bloodPressureTouchedIndex(
      spots.first,
      data.length,
      rangeBarPointIndexes,
    );
    final point = data[index];
    final systolicMin = point.minValue ?? point.value;
    final systolicMax = point.maxValue ?? point.value;
    final diastolic = point.secondaryValue ?? point.value;
    final diastolicMin = point.secondaryMinValue ?? diastolic;
    final diastolicMax = point.secondaryMaxValue ?? diastolic;
    var hasTooltip = false;

    return spots.map<LineTooltipItem?>((spot) {
      final spotIndex = _bloodPressureTouchedIndex(
        spot,
        data.length,
        rangeBarPointIndexes,
      );
      if (hasTooltip || spotIndex != index) return null;

      hasTooltip = true;
      return LineTooltipItem(
        '${_bloodPressureRangeTooltipTitle(point)} mmHg\n'
        '高压 ${_formatAxisValue(point.value, _systolicReference)} '
        '(${_formatAxisValue(systolicMin, _systolicReference)}-'
        '${_formatAxisValue(systolicMax, _systolicReference)})\n'
        '低压 ${_formatAxisValue(diastolic, _diastolicReference)} '
        '(${_formatAxisValue(diastolicMin, _diastolicReference)}-'
        '${_formatAxisValue(diastolicMax, _diastolicReference)})',
        const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      );
    }).toList();
  }

  String _bloodPressureRangeTooltipTitle(_ChartDataPoint point) {
    switch (_selectedRange) {
      case 'month':
        return '${_selectedDate.month}/${point.label}';
      default:
        return point.label;
    }
  }

  int _bloodPressureTouchedIndex(
    LineBarSpot spot,
    int dataLength,
    List<int> rangeBarPointIndexes,
  ) {
    if (spot.barIndex >= 0 && spot.barIndex < rangeBarPointIndexes.length) {
      return _clampDataIndex(rangeBarPointIndexes[spot.barIndex], dataLength);
    }
    return _clampDataIndex(spot.x.round(), dataLength);
  }

  int _clampDataIndex(int index, int dataLength) {
    if (index < 0) return 0;
    if (index >= dataLength) return dataLength - 1;
    return index;
  }

  double _lineChartMaxX(List<_ChartDataPoint> data) {
    if (_usesRawDayChart && data.length == 1) return 1.0;
    return (data.length - 1).toDouble();
  }

  List<FlSpot> _lineSpotsForData(
    List<_ChartDataPoint> data,
    double Function(_ChartDataPoint point) valueOf,
  ) {
    if (_usesRawDayChart && data.length == 1) {
      final value = valueOf(data.first);
      return [FlSpot(0, value), FlSpot(1, value)];
    }

    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), valueOf(entry.value));
    }).toList();
  }

  List<LineChartBarData> _buildBloodPressureSegmentedLineBars({
    required List<_ChartDataPoint> data,
    required double Function(_ChartDataPoint point) valueOf,
    required _MetricReference reference,
    required Color normalLineColor,
    List<int>? dashArray,
  }) {
    if (_usesRawDayChart && data.length == 1) {
      final value = valueOf(data.first);
      return [
        _buildBloodPressureSegmentBar(
          start: FlSpot(0, value),
          end: FlSpot(1, value),
          color: _bloodPressureSegmentColor(reference, value, normalLineColor),
          dashArray: dashArray,
        ),
      ];
    }

    final bars = <LineChartBarData>[];
    for (var index = 0; index < data.length - 1; index++) {
      final start = FlSpot(index.toDouble(), valueOf(data[index]));
      final end = FlSpot((index + 1).toDouble(), valueOf(data[index + 1]));
      final spots = _splitSegmentByReference(start, end, reference);

      for (var splitIndex = 0; splitIndex < spots.length - 1; splitIndex++) {
        final segmentStart = spots[splitIndex];
        final segmentEnd = spots[splitIndex + 1];
        final midValue = (segmentStart.y + segmentEnd.y) / 2;
        bars.add(
          _buildBloodPressureSegmentBar(
            start: segmentStart,
            end: segmentEnd,
            color: _bloodPressureSegmentColor(
              reference,
              midValue,
              normalLineColor,
            ),
            dashArray: dashArray,
          ),
        );
      }
    }
    return bars;
  }

  List<FlSpot> _splitSegmentByReference(
    FlSpot start,
    FlSpot end,
    _MetricReference reference,
  ) {
    final splitSpots = <FlSpot>[start];
    final thresholds = <double>[
      if (reference.criticalLow != null) reference.criticalLow!,
      if (reference.safeLow != null) reference.safeLow!,
      if (reference.safeHigh != null) reference.safeHigh!,
    ]..sort();

    for (final threshold in thresholds) {
      final crossesThreshold = (start.y - threshold) * (end.y - threshold) < 0;
      if (!crossesThreshold || start.y == end.y) continue;

      final progress = (threshold - start.y) / (end.y - start.y);
      splitSpots.add(FlSpot(start.x + (end.x - start.x) * progress, threshold));
    }

    splitSpots.add(end);
    splitSpots.sort((left, right) {
      final xCompare = left.x.compareTo(right.x);
      if (xCompare != 0) return xCompare;
      return left.y.compareTo(right.y);
    });
    return splitSpots;
  }

  LineChartBarData _buildBloodPressureSegmentBar({
    required FlSpot start,
    required FlSpot end,
    required Color color,
    List<int>? dashArray,
  }) {
    return LineChartBarData(
      spots: [start, end],
      isCurved: false,
      color: color,
      barWidth: 2.6,
      isStrokeCapRound: true,
      dashArray: dashArray,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  LineChartBarData _buildBloodPressurePointLayer({
    required List<_ChartDataPoint> data,
    required double Function(_ChartDataPoint point) valueOf,
    required _MetricReference reference,
    required Color normalDotColor,
  }) {
    return LineChartBarData(
      spots: data.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), valueOf(entry.value));
      }).toList(),
      isCurved: false,
      color: Colors.transparent,
      barWidth: 0,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          if (_hidesTrendDots) {
            return FlDotCirclePainter(
              radius: 0,
              color: Colors.transparent,
              strokeWidth: 0,
              strokeColor: Colors.transparent,
            );
          }
          final value = valueOf(data[index]);
          final statusColor = _bloodPressureSegmentColor(
            reference,
            value,
            normalDotColor,
          );
          final isSelected = index == _selectedPointIndex;
          return FlDotCirclePainter(
            radius: isSelected ? 5 : 2.5,
            color: isSelected ? statusColor : Colors.white,
            strokeWidth: isSelected ? 2.5 : 1.5,
            strokeColor: statusColor,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  Color _bloodPressureSegmentColor(
    _MetricReference reference,
    double value,
    Color normalLineColor,
  ) {
    if (reference.safeHigh != null && value > reference.safeHigh!) {
      return reference.highColor;
    }
    if (reference.safeLow != null && value < reference.safeLow!) {
      return reference.lowColor;
    }
    return normalLineColor;
  }

  _BloodPressureRangeBars _buildBloodPressureRangeBars(
    List<_ChartDataPoint> data,
  ) {
    final bars = <LineChartBarData>[];
    final pointIndexes = <int>[];
    for (final entry in data.asMap().entries) {
      final index = entry.key;
      final point = entry.value;
      _addBloodPressureRangeBarSegments(
        bars: bars,
        pointIndexes: pointIndexes,
        pointIndex: index,
        x: index.toDouble(),
        minValue: point.minValue ?? point.value,
        maxValue: point.maxValue ?? point.value,
        reference: _systolicReference,
        normalBarColor: _systolicBeige,
      );
      _addBloodPressureRangeBarSegments(
        bars: bars,
        pointIndexes: pointIndexes,
        pointIndex: index,
        x: index.toDouble(),
        minValue:
            point.secondaryMinValue ?? point.secondaryValue ?? point.value,
        maxValue:
            point.secondaryMaxValue ?? point.secondaryValue ?? point.value,
        reference: _diastolicReference,
        normalBarColor: _lowBlue,
      );
    }
    return _BloodPressureRangeBars(bars: bars, pointIndexes: pointIndexes);
  }

  void _addBloodPressureRangeBarSegments({
    required List<LineChartBarData> bars,
    required List<int> pointIndexes,
    required int pointIndex,
    required double x,
    required double minValue,
    required double maxValue,
    required _MetricReference reference,
    required Color normalBarColor,
  }) {
    final spots = _splitSegmentByReference(
      FlSpot(x, minValue),
      FlSpot(x, maxValue),
      reference,
    );

    for (var index = 0; index < spots.length - 1; index++) {
      final start = spots[index];
      final end = spots[index + 1];
      if (end.y <= start.y) continue;
      final midValue = (start.y + end.y) / 2;
      bars.add(
        _buildBloodPressureRangeBar(
          start: start,
          end: end,
          color: _bloodPressureSegmentColor(
            reference,
            midValue,
            normalBarColor,
          ),
        ),
      );
      pointIndexes.add(pointIndex);
    }
  }

  LineChartBarData _buildBloodPressureRangeBar({
    required FlSpot start,
    required FlSpot end,
    required Color color,
  }) {
    return LineChartBarData(
      spots: [start, end],
      isCurved: false,
      color: color.withValues(alpha: 0.48),
      barWidth: 7,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  _MetricRangeBars _buildMetricRangeBars(
    List<_ChartDataPoint> data,
    _MetricReference reference,
  ) {
    final bars = <LineChartBarData>[];
    final pointIndexes = <int>[];
    for (final entry in data.asMap().entries) {
      final index = entry.key;
      final point = entry.value;
      _addMetricRangeBarSegments(
        bars: bars,
        pointIndexes: pointIndexes,
        pointIndex: index,
        x: index.toDouble(),
        minValue: point.minValue ?? point.value,
        maxValue: point.maxValue ?? point.value,
        reference: reference,
      );
    }
    return _MetricRangeBars(bars: bars, pointIndexes: pointIndexes);
  }

  void _addMetricRangeBarSegments({
    required List<LineChartBarData> bars,
    required List<int> pointIndexes,
    required int pointIndex,
    required double x,
    required double minValue,
    required double maxValue,
    required _MetricReference reference,
  }) {
    final lowerValue = min(minValue, maxValue);
    final upperValue = max(minValue, maxValue);
    final spots = _splitSegmentByReference(
      FlSpot(x, lowerValue),
      FlSpot(x, upperValue),
      reference,
    );

    for (var index = 0; index < spots.length - 1; index++) {
      final start = spots[index];
      final end = spots[index + 1];
      if (end.y <= start.y) continue;
      final midValue = (start.y + end.y) / 2;
      bars.add(
        _buildMetricRangeBar(
          start: start,
          end: end,
          color: reference.colorFor(midValue),
        ),
      );
      pointIndexes.add(pointIndex);
    }
  }

  LineChartBarData _buildMetricRangeBar({
    required FlSpot start,
    required FlSpot end,
    required Color color,
  }) {
    return LineChartBarData(
      spots: [start, end],
      isCurved: false,
      color: color.withValues(alpha: 0.48),
      barWidth: 7,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  LineChartBarData _buildMetricAverageLineBar({
    required List<_ChartDataPoint> data,
    required _MetricReference reference,
  }) {
    return LineChartBarData(
      spots: _lineSpotsForData(data, (point) => point.value),
      isCurved: true,
      curveSmoothness: 0.3,
      color: reference.normalColor,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          if (_hidesTrendDots) {
            return FlDotCirclePainter(
              radius: 0,
              color: Colors.transparent,
              strokeWidth: 0,
              strokeColor: Colors.transparent,
            );
          }
          final value = data[index].value;
          final statusColor = reference.colorFor(value);
          final isSelected = index == _selectedPointIndex;
          return FlDotCirclePainter(
            radius: isSelected ? 5 : 2.5,
            color: isSelected ? statusColor : Colors.white,
            strokeWidth: isSelected ? 2.5 : 1.5,
            strokeColor: statusColor,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  LineChartBarData _buildBloodPressureLineBar({
    required List<_ChartDataPoint> data,
    required double Function(_ChartDataPoint point) valueOf,
    required _MetricReference reference,
    required Color lineColor,
    required Color normalDotColor,
    List<int>? dashArray,
  }) {
    return LineChartBarData(
      spots: data.asMap().entries.map((entry) {
        return FlSpot(entry.key.toDouble(), valueOf(entry.value));
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: lineColor,
      barWidth: 2.6,
      isStrokeCapRound: true,
      dashArray: dashArray,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          if (_hidesTrendDots) {
            return FlDotCirclePainter(
              radius: 0,
              color: Colors.transparent,
              strokeWidth: 0,
              strokeColor: Colors.transparent,
            );
          }
          final value = valueOf(data[index]);
          final statusColor = _bloodPressureSegmentColor(
            reference,
            value,
            normalDotColor,
          );
          final isSelected = index == _selectedPointIndex;
          return FlDotCirclePainter(
            radius: isSelected ? 5 : 2.5,
            color: isSelected ? statusColor : Colors.white,
            strokeWidth: isSelected ? 2.5 : 1.5,
            strokeColor: statusColor,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildLineChart({
    required List<_ChartDataPoint> data,
    required double Function(_ChartDataPoint point) valueOf,
    required _MetricReference reference,
    required String seriesName,
    required bool showBottomTitles,
  }) {
    final values = data.map(valueOf).toList();
    final bounds = _getYBounds(values, reference);
    final minY = bounds.minY;
    final maxY = bounds.maxY;

    return LineChart(
      LineChartData(
        rangeAnnotations: _buildRangeAnnotations(reference, minY, maxY),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getHorizontalInterval(minY, maxY),
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Color(0xFFF0ECF8), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showBottomTitles,
              reservedSize: showBottomTitles ? 22 : 0,
              interval: _getBottomInterval(data.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      data[index].label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9891B8),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: _getHorizontalInterval(minY, maxY),
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatAxisValue(value, reference),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9891B8),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: _lineChartMaxX(data),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) =>
                const Color(0xFF2F266F).withValues(alpha: 0.9),
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final index = spot.x.toInt().clamp(0, data.length - 1);
                final point = data[index];
                final value = valueOf(point);
                return LineTooltipItem(
                  '$seriesName ${_formatValue(value, reference)}\n'
                  '${_lineTooltipTime(point)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
          touchCallback: (event, response) {
            if (response?.lineBarSpots != null &&
                response!.lineBarSpots!.isNotEmpty) {
              setState(() {
                _selectedPointIndex = _clampDataIndex(
                  response.lineBarSpots!.first.x.round(),
                  data.length,
                );
              });
            }
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _lineSpotsForData(data, valueOf),
            isCurved: true,
            curveSmoothness: 0.3,
            color: reference.normalColor,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                if (_hidesTrendDots) {
                  return FlDotCirclePainter(
                    radius: 0,
                    color: Colors.transparent,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                }
                final value = valueOf(data[index]);
                final statusColor = reference.colorFor(value);
                final isSelected = index == _selectedPointIndex;
                final isCarriedForward = data[index].isCarriedForward;
                return FlDotCirclePainter(
                  radius: isSelected ? 5 : (isCarriedForward ? 2 : 2.5),
                  color: isSelected ? statusColor : Colors.white,
                  strokeWidth: isSelected ? 2.5 : 1.5,
                  strokeColor: isCarriedForward
                      ? statusColor.withValues(alpha: 0.45)
                      : statusColor,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: reference.normalColor.withValues(
                alpha: reference.hasRange ? 0.06 : 0.12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  RangeAnnotations _buildRangeAnnotations(
    _MetricReference reference,
    double minY,
    double maxY,
  ) {
    if (!reference.hasRange) {
      return RangeAnnotations(
        horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(
            y1: minY,
            y2: maxY,
            color: reference.normalColor.withValues(alpha: 0.06),
          ),
        ],
      );
    }

    final annotations = <HorizontalRangeAnnotation>[];
    final criticalLow = reference.criticalLow;
    final safeLow = reference.safeLow;
    final safeHigh = reference.safeHigh;

    void addAnnotation(double start, double end, Color color, double alpha) {
      final y1 = max(minY, start);
      final y2 = min(maxY, end);
      if (y2 <= y1) return;
      annotations.add(
        HorizontalRangeAnnotation(
          y1: y1,
          y2: y2,
          color: color.withValues(alpha: alpha),
        ),
      );
    }

    if (safeLow != null && safeLow > minY) {
      if (criticalLow != null) {
        addAnnotation(minY, criticalLow, reference.criticalLowColor, 0.08);
        addAnnotation(criticalLow, safeLow, reference.lowColor, 0.08);
      } else {
        addAnnotation(minY, safeLow, reference.lowColor, 0.08);
      }
    }

    addAnnotation(
      safeLow ?? minY,
      safeHigh ?? maxY,
      reference.normalColor,
      0.09,
    );

    if (safeHigh != null && safeHigh < maxY) {
      addAnnotation(safeHigh, maxY, reference.highColor, 0.08);
    }

    return RangeAnnotations(horizontalRangeAnnotations: annotations);
  }

  RangeAnnotations _buildBloodPressureRangeAnnotations(
    double minY,
    double maxY,
  ) {
    final annotations = <HorizontalRangeAnnotation>[];

    void addRange(double start, double end, Color color, double alpha) {
      final y1 = max(minY, start);
      final y2 = min(maxY, end);
      if (y2 <= y1) return;
      annotations.add(
        HorizontalRangeAnnotation(
          y1: y1,
          y2: y2,
          color: color.withValues(alpha: alpha),
        ),
      );
    }

    addRange(minY, 60, _lowPurple, 0.035);
    addRange(60, 90, _diastolicAreaBlue, 0.45);
    addRange(90, 140, _systolicAreaBeige, 0.42);
    addRange(140, maxY, _highRed, 0.04);

    return RangeAnnotations(horizontalRangeAnnotations: annotations);
  }

  double _sleepRadarRangeBarWidth(int dataLength) {
    if (dataLength <= 7) return 14;
    if (dataLength <= 31) return 8;
    return 7;
  }

  double _sleepRadarRangeGroupsSpace(int dataLength) {
    if (dataLength <= 7) return 16;
    if (dataLength <= 31) return 6;
    return 4;
  }

  _RangeBarBounds _rangeBarVisualBounds({
    required double minValue,
    required double maxValue,
    required double minY,
    required double maxY,
  }) {
    final lowerValue = min(minValue, maxValue);
    final upperValue = max(minValue, maxValue);
    if (upperValue > lowerValue) {
      return _RangeBarBounds(min: lowerValue, max: upperValue);
    }

    final minVisibleHeight = max((maxY - minY) * 0.012, 0.4);
    return _RangeBarBounds(
      min: max(minY, lowerValue - minVisibleHeight),
      max: min(maxY, upperValue + minVisibleHeight),
    );
  }

  _YBounds _getYBounds(List<double> values, _MetricReference reference) {
    var minValue = values.reduce(min);
    var maxValue = values.reduce(max);

    if (reference.safeLow != null) {
      minValue = min(minValue, reference.safeLow!);
    }
    if (reference.safeHigh != null) {
      maxValue = max(maxValue, reference.safeHigh!);
    }

    final spread = maxValue - minValue;
    final padding = spread <= 3 ? 0.4 : max(3.0, spread * 0.15);
    final maxY = maxValue + padding;
    return _YBounds(
      minY: max(0.0, minValue - padding),
      maxY: reference.axisMax == null ? maxY : min(reference.axisMax!, maxY),
    );
  }

  _YBounds _getMetricRangeYBounds(
    List<_ChartDataPoint> data,
    _MetricReference reference,
  ) {
    final values = <double>[
      ...data.map((point) => point.value),
      ...data.map((point) => point.minValue ?? point.value),
      ...data.map((point) => point.maxValue ?? point.value),
    ];
    return _getYBounds(values, reference);
  }

  _YBounds _getBloodPressureYBounds(List<_ChartDataPoint> data) {
    final values = <double>[
      ...data.map((point) => point.value),
      ...data.map((point) => point.minValue ?? point.value),
      ...data.map((point) => point.maxValue ?? point.value),
      ...data.map((point) => point.secondaryValue ?? point.value),
      ...data.map(
        (point) =>
            point.secondaryMinValue ?? point.secondaryValue ?? point.value,
      ),
      ...data.map(
        (point) =>
            point.secondaryMaxValue ?? point.secondaryValue ?? point.value,
      ),
    ];
    var minValue = values.reduce(min);
    var maxValue = values.reduce(max);

    for (final reference in [_systolicReference, _diastolicReference]) {
      if (reference.safeLow != null) {
        minValue = min(minValue, reference.safeLow!);
      }
      if (reference.safeHigh != null) {
        maxValue = max(maxValue, reference.safeHigh!);
      }
    }

    final spread = maxValue - minValue;
    final padding = max(5.0, spread * 0.12);
    return _YBounds(
      minY: max(0.0, minValue - padding),
      maxY: maxValue + padding,
    );
  }

  double _getHorizontalInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 2) return 0.5;
    if (range <= 6) return 1;
    if (range <= 20) return 5;
    if (range <= 80) return 10;
    return (range / 4).ceilToDouble();
  }

  double _getBottomInterval(int dataLength) {
    switch (_selectedRange) {
      case 'day':
        if (_usesRawDayChart && dataLength > 24) {
          return max(1, (dataLength / 6).floor()).toDouble();
        }
        return 4.0;
      case 'week':
        return 1.0;
      case 'month':
        return max(1, (dataLength / 6).floor()).toDouble();
      case 'year':
        if (_usesSleepRadarRangeBarChart && dataLength > 31) {
          return max(1, (dataLength / 6).floor()).toDouble();
        }
        return 1.0;
      default:
        return 1.0;
    }
  }

  double _roundMetricValue(double value, _MetricReference reference) {
    return double.parse(value.toStringAsFixed(reference.fractionDigits));
  }

  Widget _buildDataDetail(_ChartDataPoint point) {
    if (_isBloodPressure) return _buildBloodPressureDetail(point);
    if (_isSleepRadarStateMetric) return _buildSleepRadarStateDetail(point);

    final reference = _metricReference;
    final usesRangeChart = _usesMetricRangeStats;
    final minValue = point.minValue ?? point.value;
    final maxValue = point.maxValue ?? point.value;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                point.time,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F266F),
                ),
              ),
              Text(
                _formatValue(point.value, reference),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: reference.colorFor(point.value),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFFF0ECF8)),
          const SizedBox(height: 10),
          _buildDataRow('指标名称', widget.metricName),
          _buildDataRow(
            usesRangeChart ? '平均值' : '当前值',
            _formatValue(point.value, reference),
          ),
          if (usesRangeChart)
            _buildDataRow(
              '范围',
              _formatRange(minValue, maxValue, reference),
              valueColor: _rangeColor(reference, minValue, maxValue),
            ),
          _buildDataRow(point.isCarriedForward ? '趋势时间' : '采集时间', point.time),
          if (point.isCarriedForward && point.sourceTime != null)
            _buildDataRow('采集时间', point.sourceTime!),
          _buildDataRow(
            '状态',
            usesRangeChart
                ? _metricRangeStatus(reference, minValue, maxValue)
                : reference.statusFor(point.value),
            valueColor: usesRangeChart
                ? _rangeColor(reference, minValue, maxValue)
                : reference.colorFor(point.value),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepRadarStateDetail(_ChartDataPoint point) {
    final label = point.displayValue ?? _sleepRadarStateText(point.value);
    final color = _sleepRadarStateColor(point.value);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                point.time,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F266F),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFFF0ECF8)),
          const SizedBox(height: 10),
          _buildDataRow('指标名称', widget.metricName),
          _buildDataRow('状态值', label, valueColor: color),
          _buildDataRow('状态编码', point.value.toInt().toString()),
          _buildDataRow('采集时间', point.time),
        ],
      ),
    );
  }

  List<_StateMetricLevel> _sleepRadarStateLevels() {
    switch (widget.metricName) {
      case '存在状态':
        return const [
          _StateMetricLevel(0, '无人', Color(0xFF94A3B8)),
          _StateMetricLevel(1, '有人', Color(0xFF22A06B)),
        ];
      case '运动状态':
        return const [
          _StateMetricLevel(0, '无', Color(0xFF94A3B8)),
          _StateMetricLevel(1, '静止', Color(0xFF3B82F6)),
          _StateMetricLevel(2, '活跃', Color(0xFF22A06B)),
        ];
      case '离床状态':
        return const [
          _StateMetricLevel(0, '离床', Color(0xFFE8453A)),
          _StateMetricLevel(1, '入床', Color(0xFF22A06B)),
          _StateMetricLevel(2, '无', Color(0xFF94A3B8)),
        ];
      case '睡眠状态':
        return const [
          _StateMetricLevel(0, '深睡', Color(0xFF4F46E5)),
          _StateMetricLevel(1, '浅睡', Color(0xFF8B5CF6)),
          _StateMetricLevel(2, '清醒', Color(0xFFF59E0B)),
          _StateMetricLevel(3, '无', Color(0xFF94A3B8)),
        ];
      default:
        return const [];
    }
  }

  List<_StateMetricLevel> _sleepRadarStateChartLevels() {
    switch (widget.metricName) {
      case '离床状态':
        return const [
          _StateMetricLevel(0, '无', Color(0xFF94A3B8)),
          _StateMetricLevel(1, '离床', Color(0xFFE8453A)),
          _StateMetricLevel(2, '入床', Color(0xFF22A06B)),
        ];
      case '睡眠状态':
        return const [
          _StateMetricLevel(0, '无', Color(0xFF94A3B8)),
          _StateMetricLevel(1, '深睡', Color(0xFF4F46E5)),
          _StateMetricLevel(2, '浅睡', Color(0xFF8B5CF6)),
          _StateMetricLevel(3, '清醒', Color(0xFFF59E0B)),
        ];
      default:
        return _sleepRadarStateLevels();
    }
  }

  double _sleepRadarStateVisualValue(double value) {
    final code = value.round();
    switch (widget.metricName) {
      case '离床状态':
        switch (code) {
          case 2:
            return 0;
          case 0:
            return 1;
          case 1:
            return 2;
        }
        break;
      case '睡眠状态':
        switch (code) {
          case 3:
            return 0;
          case 0:
            return 1;
          case 1:
            return 2;
          case 2:
            return 3;
        }
        break;
    }
    return code.toDouble();
  }

  _StateMetricLevel? _sleepRadarStateLevel(double value) {
    final code = value.round();
    for (final level in _sleepRadarStateLevels()) {
      if (level.value == code) return level;
    }
    return null;
  }

  String _sleepRadarStateText(double value) {
    return _sleepRadarStateLevel(value)?.label ?? value.toInt().toString();
  }

  Color _sleepRadarStateColor(double value) {
    return _sleepRadarStateLevel(value)?.color ?? widget.metricColor;
  }

  String? _sleepRadarStateRawText(Object? value) {
    if (value == null) return null;
    if (value is num) return null;
    final text = value.toString().trim();
    if (text.isEmpty || _asDouble(text) != null) return null;
    return text;
  }

  double? _sleepRadarStateCode(Object? value) {
    final numericValue = _asDouble(value);
    if (numericValue != null) return numericValue;

    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;

    for (final level in _sleepRadarStateLevels()) {
      if (level.label == text) return level.value.toDouble();
    }

    switch (widget.metricName) {
      case '离床状态':
        if (text == '在床') return 1;
        break;
      case '睡眠状态':
        if (text == '睡着') return 1;
        break;
      case '存在状态':
        if (text == '有') return 1;
        if (text == '无') return 0;
        break;
    }
    return null;
  }

  Widget _buildBloodPressureDetail(_ChartDataPoint point) {
    final systolic = point.value;
    final diastolic = point.secondaryValue ?? 0;
    final systolicMin = point.minValue ?? systolic;
    final systolicMax = point.maxValue ?? systolic;
    final diastolicMin = point.secondaryMinValue ?? diastolic;
    final diastolicMax = point.secondaryMaxValue ?? diastolic;
    final usesRangeChart = _usesBloodPressureRangeChart;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            point.time,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2F266F),
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFFF0ECF8)),
          const SizedBox(height: 10),
          _buildDataRow(
            usesRangeChart ? '高压平均' : '高压',
            _formatValue(systolic, _systolicReference),
            valueColor: _systolicReference.colorFor(systolic),
          ),
          if (usesRangeChart)
            _buildDataRow(
              '高压范围',
              _formatRange(systolicMin, systolicMax, _systolicReference),
              valueColor: _rangeColor(
                _systolicReference,
                systolicMin,
                systolicMax,
              ),
            ),
          _buildDataRow(
            usesRangeChart ? '低压平均' : '低压',
            _formatValue(diastolic, _diastolicReference),
            valueColor: _diastolicReference.colorFor(diastolic),
          ),
          if (usesRangeChart)
            _buildDataRow(
              '低压范围',
              _formatRange(diastolicMin, diastolicMax, _diastolicReference),
              valueColor: _rangeColor(
                _diastolicReference,
                diastolicMin,
                diastolicMax,
              ),
            ),
          _buildDataRow('采集时间', point.time),
          _buildDataRow(
            '状态',
            usesRangeChart
                ? _bloodPressureRangeStatus(
                    systolicMin,
                    systolicMax,
                    diastolicMin,
                    diastolicMax,
                  )
                : _bloodPressureStatus(systolic, diastolic),
            valueColor: usesRangeChart
                ? _bloodPressureRangeStatusColor(
                    systolicMin,
                    systolicMax,
                    diastolicMin,
                    diastolicMax,
                  )
                : _bloodPressureStatusColor(systolic, diastolic),
          ),
        ],
      ),
    );
  }

  String _bloodPressureStatus(double systolic, double diastolic) {
    if (systolic > _systolicReference.safeHigh! ||
        diastolic > _diastolicReference.safeHigh!) {
      return '偏高';
    }
    if (systolic < _systolicReference.safeLow! ||
        diastolic < _diastolicReference.safeLow!) {
      return '偏低';
    }
    return '正常';
  }

  Color _bloodPressureStatusColor(double systolic, double diastolic) {
    final status = _bloodPressureStatus(systolic, diastolic);
    if (status == '偏高') return _highRed;
    if (status == '偏低') return _lowPurple;
    return _normalGreen;
  }

  String _bloodPressureRangeStatus(
    double systolicMin,
    double systolicMax,
    double diastolicMin,
    double diastolicMax,
  ) {
    if (systolicMax > _systolicReference.safeHigh! ||
        diastolicMax > _diastolicReference.safeHigh!) {
      return '偏高';
    }
    if (systolicMin < _systolicReference.safeLow! ||
        diastolicMin < _diastolicReference.safeLow!) {
      return '偏低';
    }
    return '正常';
  }

  Color _bloodPressureRangeStatusColor(
    double systolicMin,
    double systolicMax,
    double diastolicMin,
    double diastolicMax,
  ) {
    final status = _bloodPressureRangeStatus(
      systolicMin,
      systolicMax,
      diastolicMin,
      diastolicMax,
    );
    if (status == '偏高') return _highRed;
    if (status == '偏低') return _lowPurple;
    return _normalGreen;
  }

  Widget _buildDataRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9891B8)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF2F266F),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double value, _MetricReference reference) {
    final text = value.toStringAsFixed(reference.fractionDigits);
    return reference.unit.isEmpty ? text : '$text${reference.unit}';
  }

  String _lineTooltipTime(_ChartDataPoint point) {
    if (point.isCarriedForward && point.sourceTime != null) {
      return '${point.time}\n沿用 ${point.sourceTime}';
    }
    return point.time;
  }

  String _formatRange(
    double minValue,
    double maxValue,
    _MetricReference reference,
  ) {
    final minText = minValue.toStringAsFixed(reference.fractionDigits);
    final maxText = maxValue.toStringAsFixed(reference.fractionDigits);
    return reference.unit.isEmpty
        ? '$minText - $maxText'
        : '$minText - $maxText${reference.unit}';
  }

  Color _rangeColor(
    _MetricReference reference,
    double minValue,
    double maxValue,
  ) {
    if (reference.safeHigh != null && maxValue > reference.safeHigh!) {
      return reference.highColor;
    }
    if (reference.criticalLow != null && minValue < reference.criticalLow!) {
      return reference.criticalLowColor;
    }
    if (reference.safeLow != null && minValue < reference.safeLow!) {
      return reference.lowColor;
    }
    return reference.normalColor;
  }

  String _metricRangeStatus(
    _MetricReference reference,
    double minValue,
    double maxValue,
  ) {
    if (!reference.hasRange) return '正常';
    if (reference.safeHigh != null && maxValue > reference.safeHigh!) {
      return '偏高';
    }
    if (reference.criticalLow != null && minValue < reference.criticalLow!) {
      return '偏低';
    }
    if (reference.safeLow != null && minValue < reference.safeLow!) {
      return '偏低';
    }
    return '正常';
  }

  String _formatAxisValue(double value, _MetricReference reference) {
    if (reference.unit == '步' && value.abs() >= 10000) {
      final text = (value / 10000).toStringAsFixed(
        value.abs() >= 100000 ? 0 : 1,
      );
      return '$text万';
    }
    return value.toStringAsFixed(reference.fractionDigits);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _addMonths(DateTime month, int offset) {
    return DateTime(month.year, month.month + offset);
  }

  List<DateTime> _monthGridDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month);
    final startDay = firstDay.subtract(Duration(days: firstDay.weekday % 7));
    return List.generate(
      42,
      (index) => DateTime(startDay.year, startDay.month, startDay.day + index),
    );
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  bool _isBeforeDate(DateTime left, DateTime right) {
    return _dateOnly(left).isBefore(_dateOnly(right));
  }

  bool _isAfterDate(DateTime left, DateTime right) {
    return _dateOnly(left).isAfter(_dateOnly(right));
  }

  bool _isDateInRange(DateTime date, DateTime start, DateTime end) {
    final normalizedDate = _dateOnly(date);
    return !normalizedDate.isBefore(_dateOnly(start)) &&
        !normalizedDate.isAfter(_dateOnly(end));
  }

  int _rangeDayCount(DateTimeRange range) {
    return _dateOnly(range.end).difference(_dateOnly(range.start)).inDays + 1;
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _formatMonthDay(DateTime date) {
    return '${date.month}月${date.day}日';
  }
}

class _ChartDataPoint {
  final String label;
  final double value;
  final double? minValue;
  final double? maxValue;
  final double? secondaryValue;
  final double? secondaryMinValue;
  final double? secondaryMaxValue;
  final String time;
  final String? displayValue;
  final String? sourceTime;
  final bool isCarriedForward;

  const _ChartDataPoint({
    required this.label,
    required this.value,
    this.minValue,
    this.maxValue,
    this.secondaryValue,
    this.secondaryMinValue,
    this.secondaryMaxValue,
    required this.time,
    this.displayValue,
    this.sourceTime,
    this.isCarriedForward = false,
  });
}

class _BloodPressureRangeBars {
  final List<LineChartBarData> bars;
  final List<int> pointIndexes;

  const _BloodPressureRangeBars({
    this.bars = const [],
    this.pointIndexes = const [],
  });
}

class _MetricRangeBars {
  final List<LineChartBarData> bars;
  final List<int> pointIndexes;

  const _MetricRangeBars({this.bars = const [], this.pointIndexes = const []});
}

class _StateMetricLevel {
  final int value;
  final String label;
  final Color color;

  const _StateMetricLevel(this.value, this.label, this.color);
}

class _MetricReference {
  final double? criticalLow;
  final double? safeLow;
  final double? safeHigh;
  final double? axisMax;
  final String unit;
  final int fractionDigits;
  final Color criticalLowColor;
  final Color lowColor;
  final Color normalColor;
  final Color highColor;

  const _MetricReference({
    this.criticalLow,
    this.safeLow,
    this.safeHigh,
    this.axisMax,
    required this.unit,
    this.fractionDigits = 0,
    this.criticalLowColor = const Color(0xFFE8453A),
    this.lowColor = const Color(0xFF3B82F6),
    this.normalColor = const Color(0xFF22A06B),
    this.highColor = const Color(0xFFE8453A),
  });

  bool get hasRange =>
      criticalLow != null || safeLow != null || safeHigh != null;

  Color colorFor(double value) {
    if (!hasRange) return normalColor;
    if (criticalLow != null && value < criticalLow!) {
      return criticalLowColor;
    }
    if (safeLow != null && value < safeLow!) return lowColor;
    if (safeHigh != null && value > safeHigh!) return highColor;
    return normalColor;
  }

  String statusFor(double value) {
    if (!hasRange) return '正常';
    if (criticalLow != null && value < criticalLow!) return '偏低';
    if (safeLow != null && value < safeLow!) return '偏低';
    if (safeHigh != null && value > safeHigh!) return '偏高';
    return '正常';
  }
}

class _YBounds {
  final double minY;
  final double maxY;

  const _YBounds({required this.minY, required this.maxY});
}

class _RangeBarBounds {
  final double min;
  final double max;

  const _RangeBarBounds({required this.min, required this.max});
}

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool isDashed;
  final bool showRange;

  const _LegendLinePainter({
    required this.color,
    required this.isDashed,
    required this.showRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showRange) {
      final rangePaint = Paint()
        ..color = color.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;
      final rangeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 5,
          height: size.height,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rangeRect, rangePaint);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;

    if (!isDashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    var startX = 0.0;
    while (startX < size.width) {
      final endX = min(startX + dashWidth, size.width);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isDashed != isDashed ||
        oldDelegate.showRange != showRange;
  }
}
