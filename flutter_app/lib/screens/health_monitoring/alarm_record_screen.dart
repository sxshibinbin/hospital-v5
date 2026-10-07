import 'package:flutter/material.dart';
import 'iot_api_client.dart';

enum AlarmRecordType { alarm, eventReport }

class AlarmRecordScreen extends StatefulWidget {
  final String? deviceImei;
  final AlarmRecordType recordType;

  const AlarmRecordScreen({
    super.key,
    this.deviceImei,
    this.recordType = AlarmRecordType.alarm,
  });

  @override
  State<AlarmRecordScreen> createState() => _AlarmRecordScreenState();
}

class _AlarmRecordScreenState extends State<AlarmRecordScreen> {
  DateTimeRange? _selectedDateRange;
  bool _isFilterExpanded = false;

  List<AlarmRecord> _alarmRecords = [];
  bool _isLoading = false;

  bool get _isEventReportMode =>
      widget.recordType == AlarmRecordType.eventReport;

  String get _pageTitle => _isEventReportMode ? '事件上报记录' : '报警记录';

  String get _emptyText => _isEventReportMode ? '暂无相关事件上报记录' : '暂无相关报警记录';

  static const Map<String, AlarmTypeStyle> _alarmTypeStyles = {
    '报警': AlarmTypeStyle(
      color: Color(0xFFE8453A),
      bgColor: Color(0xFFFDECEA),
      borderColor: Color(0x2EE8453A),
    ),
    '演练': AlarmTypeStyle(
      color: Color(0xFFE88D0C),
      bgColor: Color(0xFFFFF4E0),
      borderColor: Color(0x2EE88D0C),
    ),
    '测试': AlarmTypeStyle(
      color: Color(0xFF3B82F6),
      bgColor: Color(0xFFEBF2FF),
      borderColor: Color(0x2E3B82F6),
    ),
    '其他': AlarmTypeStyle(
      color: Color(0xFF8B86A0),
      bgColor: Color(0xFFF2F1F5),
      borderColor: Color(0x2E8B86A0),
    ),
    '事件上报': AlarmTypeStyle(
      color: Color(0xFF3B82F6),
      bgColor: Color(0xFFEBF2FF),
      borderColor: Color(0x2E3B82F6),
    ),
  };

  static const Map<int, String> _levelLabels = {
    1: '1级(紧急)',
    2: '2级(重要)',
    3: '3级(一般)',
  };

  @override
  void initState() {
    super.initState();
    _selectedDateRange = DateTimeRange(
      start: DateTime.now(),
      end: DateTime.now(),
    );
    _loadAlarmRecords();
  }

  Future<void> _loadAlarmRecords() async {
    if (widget.deviceImei == null || widget.deviceImei!.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 使用用户选择的日期范围，默认为当天
      final start = _selectedDateRange?.start ?? DateTime.now();
      final end = _selectedDateRange?.end ?? DateTime.now();
      final startDateStr =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      final endDateStr =
          '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

      final Map<String, dynamic> body = {
        'deviceImei': widget.deviceImei,
        'eventStartDate': startDateStr,
        'eventEndDate': endDateStr,
      };
      if (_isEventReportMode) {
        body['handlerStatus'] = 0;
      }

      final endpoint = _isEventReportMode
          ? '/api/iot/devices/events'
          : '/api/iot/devices/alarm';
      final data = await iotPostJson(
        context,
        endpoint,
        body: body,
        operation: _isEventReportMode
            ? 'load IoT event records'
            : 'load IoT alarm records',
      );

      if (!mounted) {
        return;
      }

      if (data['success'] == true && data['message'] != null) {
        final responseData = data['message']['data'];
        setState(() {
          _alarmRecords = _isEventReportMode
              ? _parseEventRecords(responseData)
              : _parseAlarmRecords(responseData);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } on IotApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFE88D0C),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _asDeviceData(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData;
    }
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    if (responseData is List && responseData.isNotEmpty) {
      final first = responseData.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) {
      return value > 0 ? value : null;
    }

    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  List<AlarmRecord> _parseAlarmRecords(dynamic responseData) {
    final deviceData = _asDeviceData(responseData);
    if (deviceData == null) {
      return [];
    }

    final records = <AlarmRecord>[];
    int idCounter = 1;

    final deviceImei = deviceData['deviceImei'] ?? '';
    final deviceType = deviceData['deviceType'] ?? '';
    final roomName = deviceData['roomName'] ?? '';

    final events = deviceData['events'] as List<dynamic>? ?? [];
    for (var event in events) {
      final handlerStatus = event['handlerStatus'] ?? 0;
      final handlerTime = event['handlerTime'] ?? '';
      final reportDate = event['reportDate'] ?? '';
      final eventName = event['eventName'] ?? '';
      final alarmReason = event['alarmReason'] ?? '';
      final dataType = _asInt(event['data_type']);

      // 确定类型
      String type = '其他';
      if (eventName.contains('报警') || dataType == 1) {
        type = '报警';
      } else if (eventName.contains('演练') || dataType == 2) {
        type = '演练';
      } else if (eventName.contains('测试') || dataType == 3) {
        type = '测试';
      }

      records.add(
        AlarmRecord(
          id: idCounter++,
          status: handlerStatus == 1 ? 'confirmed' : 'unconfirmed',
          address: roomName.isEmpty ? deviceImei : roomName,
          alarmTime: reportDate,
          type: type,
          alarmReason: alarmReason.isEmpty ? eventName : alarmReason,
          confirmTime: handlerStatus == 1 && handlerTime.isNotEmpty
              ? handlerTime
              : '--',
          confirmPerson: handlerStatus == 1 ? '系统' : '--',
          alarmLevel: 2,
          eventLevel: 'B',
          deviceType: deviceType,
          installLocation: roomName.isEmpty ? deviceImei : roomName,
          receiver: '--',
          imei: deviceImei,
          remark: '',
          recentAlarm: null,
          deviceStatus: '在线',
        ),
      );
    }

    return records;
  }

  List<AlarmRecord> _parseEventRecords(dynamic responseData) {
    final deviceDataList = <Map<String, dynamic>>[];
    if (responseData is List) {
      for (final item in responseData) {
        if (item is Map<String, dynamic>) {
          deviceDataList.add(item);
        } else if (item is Map) {
          deviceDataList.add(Map<String, dynamic>.from(item));
        }
      }
    } else {
      final deviceData = _asDeviceData(responseData);
      if (deviceData != null) {
        deviceDataList.add(deviceData);
      }
    }

    final records = <AlarmRecord>[];
    int idCounter = 1;

    for (final deviceData in deviceDataList) {
      final deviceImei = deviceData['deviceImei']?.toString() ?? '';
      final deviceType = deviceData['deviceType']?.toString() ?? '';
      final roomName = deviceData['roomName']?.toString() ?? '';
      final events = deviceData['events'] as List<dynamic>? ?? [];

      for (final event in events) {
        if (event is! Map) {
          continue;
        }

        final eventName = event['eventName']?.toString() ?? '';
        final handlerStatus = _asInt(event['handlerStatus']);
        final handlerTime = event['handlerTime']?.toString() ?? '';
        final deviceState = _asInt(event['deviceState']);
        final eventCount = _asInt(event['eventCount'], fallback: 1);
        final groupedEvents =
            (event['eventDetails'] ?? event['events']) as List<dynamic>?;

        if (groupedEvents != null) {
          for (final groupedEvent in groupedEvents) {
            if (groupedEvent is! Map) {
              continue;
            }

            final reportDate =
                groupedEvent['reportDate']?.toString() ??
                event['reportDate']?.toString() ??
                '';
            final eventId = _asNullableInt(groupedEvent['eventId']);
            final dataType = _asInt(
              groupedEvent['data_type'],
              fallback: _asInt(event['data_type']),
            );

            records.add(
              AlarmRecord(
                eventId: eventId,
                id: idCounter++,
                status: handlerStatus == 1 ? 'confirmed' : 'unconfirmed',
                address: roomName.isEmpty ? deviceImei : roomName,
                alarmTime: reportDate,
                type: '事件上报',
                alarmReason: eventName.isEmpty ? '事件上报' : eventName,
                confirmTime: handlerStatus == 1 && handlerTime.isNotEmpty
                    ? handlerTime
                    : '--',
                confirmPerson: handlerStatus == 1 ? '系统' : '--',
                alarmLevel: dataType,
                eventLevel: deviceState.toString(),
                deviceType: deviceType,
                installLocation: roomName.isEmpty ? deviceImei : roomName,
                receiver: '--',
                imei: deviceImei,
                remark: '',
                recentAlarm: null,
                deviceStatus: _deviceStateLabel(deviceState),
              ),
            );
          }
          continue;
        }

        final reportDate = event['reportDate']?.toString() ?? '';
        final eventId = _asNullableInt(event['eventId']);

        records.add(
          AlarmRecord(
            eventId: eventId,
            eventCount: eventCount <= 0 ? 1 : eventCount,
            id: idCounter++,
            status: handlerStatus == 1 ? 'confirmed' : 'unconfirmed',
            address: roomName.isEmpty ? deviceImei : roomName,
            alarmTime: reportDate,
            type: '事件上报',
            alarmReason: eventName.isEmpty ? '事件上报' : eventName,
            confirmTime: handlerStatus == 1 && handlerTime.isNotEmpty
                ? handlerTime
                : '--',
            confirmPerson: handlerStatus == 1 ? '系统' : '--',
            alarmLevel: _asInt(event['data_type']),
            eventLevel: deviceState.toString(),
            deviceType: deviceType,
            installLocation: roomName.isEmpty ? deviceImei : roomName,
            receiver: '--',
            imei: deviceImei,
            remark: '',
            recentAlarm: null,
            deviceStatus: _deviceStateLabel(deviceState),
          ),
        );
      }
    }

    return records;
  }

  String _deviceStateLabel(int deviceState) {
    switch (deviceState) {
      case 0:
        return '正常';
      case 1:
        return '故障';
      case 2:
        return '报警';
      case 4:
        return '离线';
      case 8:
        return '隐患';
      default:
        return '未知';
    }
  }

  @override
  Widget build(BuildContext context) {
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
          _pageTitle,
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
          _buildFilterSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildRecordsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2F266F).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setState(() => _isFilterExpanded = !_isFilterExpanded),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.tune,
                          size: 18,
                          color: Color(0xFF5B57F7),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '筛选条件',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B6490),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _isFilterExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: const Color(0xFF9891B8),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // 日期范围
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '日期范围',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9891B8),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    _selectDate(context, isStart: true),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F6FF),
                                    border: Border.all(
                                      color: const Color(0xFFE7E3F5),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedDateRange?.start
                                                .toIso8601String()
                                                .split('T')[0] ??
                                            '2026-07-24',
                                        style: const TextStyle(
                                          color: Color(0xFF2F266F),
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Color(0xFF9891B8),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '至',
                                style: TextStyle(
                                  color: Color(0xFF9891B8),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    _selectDate(context, isStart: false),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F6FF),
                                    border: Border.all(
                                      color: const Color(0xFFE7E3F5),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedDateRange?.end
                                                .toIso8601String()
                                                .split('T')[0] ??
                                            '2026-07-24',
                                        style: const TextStyle(
                                          color: Color(0xFF2F266F),
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Color(0xFF9891B8),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _resetFilters,
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F6FF),
                                border: Border.all(
                                  color: const Color(0xFFE7E3F5),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: Text(
                                  '重置',
                                  style: TextStyle(
                                    color: Color(0xFF6B6490),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _applyFilters,
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5B57F7),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF5B57F7,
                                    ).withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '应用',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState: _isFilterExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsList() {
    final records = _getFilteredRecords();

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 56,
              color: const Color(0xFFE7E3F5),
            ),
            const SizedBox(height: 16),
            Text(
              _emptyText,
              style: const TextStyle(fontSize: 14, color: Color(0xFF9891B8)),
            ),
          ],
        ),
      );
    }

    if (_isEventReportMode) {
      return _buildEventReportGroupList(records);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 50),
      itemCount: records.length,
      itemBuilder: (context, index) {
        return _buildAlarmCard(context, records[index], index);
      },
    );
  }

  List<EventReportGroup> _buildEventReportGroups(List<AlarmRecord> records) {
    final groupedRecords = <String, List<AlarmRecord>>{};
    for (final record in records) {
      final eventName = record.alarmReason.trim().isEmpty
          ? '事件上报'
          : record.alarmReason.trim();
      groupedRecords.putIfAbsent(eventName, () => []).add(record);
    }

    final groups =
        groupedRecords.entries.map((entry) {
          final eventRecords = [...entry.value]
            ..sort((left, right) => right.alarmTime.compareTo(left.alarmTime));
          return EventReportGroup(eventName: entry.key, records: eventRecords);
        }).toList()..sort(
          (left, right) =>
              right.latestReportTime.compareTo(left.latestReportTime),
        );

    return groups;
  }

  Widget _buildEventReportGroupList(List<AlarmRecord> records) {
    final groups = _buildEventReportGroups(records);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 50),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        return _buildEventReportGroupCard(context, groups[index]);
      },
    );
  }

  Widget _buildEventReportGroupCard(
    BuildContext context,
    EventReportGroup group,
  ) {
    final typeStyle = _alarmTypeStyles['事件上报'] ?? _alarmTypeStyles['其他']!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openEventReportGroupDetail(context, group),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0ECF8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2F266F).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 3,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              decoration: BoxDecoration(
                color: typeStyle.color,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          group.installLocation,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2F266F),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: typeStyle.bgColor,
                          border: Border.all(
                            color: typeStyle.borderColor,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '上报 ${group.reportCount} 次',
                          style: TextStyle(
                            color: typeStyle.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    group.eventName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2F266F),
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF9891B8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '最新上报 ${group.latestReportTime}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9891B8),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFF9891B8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEventReportGroupDetail(
    BuildContext context,
    EventReportGroup group,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EventReportGroupDetailScreen(group: group),
      ),
    );
  }

  Widget _buildAlarmCard(BuildContext context, AlarmRecord record, int index) {
    final typeStyle = _alarmTypeStyles[record.type] ?? _alarmTypeStyles['其他']!;

    return GestureDetector(
      onTap: () => _showAlarmDetail(context, record),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0ECF8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2F266F).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top accent bar
            Container(
              height: 3,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              decoration: BoxDecoration(
                color: typeStyle.color,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address + type badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          record.address,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2F266F),
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: typeStyle.bgColor,
                          border: Border.all(
                            color: typeStyle.borderColor,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          record.type,
                          style: TextStyle(
                            color: typeStyle.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Time
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF9891B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        record.alarmTime,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9891B8),
                          fontFamily: 'monospace',
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Reason
                  Text(
                    record.alarmReason,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6490),
                      height: 1.55,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Confirmation row
                  if (record.status == 'confirmed' &&
                      record.confirmTime != '--') ...[
                    Container(
                      padding: const EdgeInsets.only(top: 8),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFF0ECF8), width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Color(0xFF22A06B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                record.confirmTime,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9891B8),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '处理人 ${record.confirmPerson}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B6490),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlarmDetail(BuildContext context, AlarmRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AlarmDetailSheet(
        record: record,
        isEventReportMode: _isEventReportMode,
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context, {
    required bool isStart,
  }) async {
    final initialDate = isStart
        ? (_selectedDateRange?.start ?? DateTime(2026, 7, 24))
        : (_selectedDateRange?.end ?? DateTime(2026, 7, 24));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2027, 12, 31),
    );
    if (picked != null) {
      setState(() {
        final start = isStart ? picked : (_selectedDateRange?.start ?? picked);
        final end = isStart ? (_selectedDateRange?.end ?? picked) : picked;
        _selectedDateRange = DateTimeRange(
          start: start.isAfter(end) ? end : start,
          end: end.isBefore(start) ? start : end,
        );
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedDateRange = DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now(),
      );
    });
    _loadAlarmRecords();
  }

  void _applyFilters() {
    setState(() {
      _isFilterExpanded = false;
    });
    _loadAlarmRecords();
  }

  List<AlarmRecord> _getFilteredRecords() {
    return _alarmRecords;
  }
}

// ============================================
// Data Models
// ============================================
class AlarmRecord {
  final int? eventId;
  final int eventCount;
  final int id;
  final String status; // unconfirmed / confirmed
  final String address;
  final String alarmTime;
  final String type;
  final String alarmReason;
  final String confirmTime;
  final String confirmPerson;
  final int alarmLevel;
  final String eventLevel;
  final String deviceType;
  final String installLocation;
  final String receiver;
  final String imei;
  final String remark;
  final RecentAlarm? recentAlarm;
  final String deviceStatus;

  AlarmRecord({
    this.eventId,
    this.eventCount = 1,
    required this.id,
    required this.status,
    required this.address,
    required this.alarmTime,
    required this.type,
    required this.alarmReason,
    required this.confirmTime,
    required this.confirmPerson,
    required this.alarmLevel,
    required this.eventLevel,
    required this.deviceType,
    required this.installLocation,
    required this.receiver,
    required this.imei,
    required this.remark,
    this.recentAlarm,
    required this.deviceStatus,
  });
}

class RecentAlarm {
  final String type;
  final String time;
  final String reason;

  RecentAlarm({required this.type, required this.time, required this.reason});
}

class EventReportGroup {
  final String eventName;
  final List<AlarmRecord> records;

  EventReportGroup({required this.eventName, required this.records});

  AlarmRecord get latestRecord => records.first;

  String get installLocation => latestRecord.installLocation;

  String get deviceType => latestRecord.deviceType;

  String get imei => latestRecord.imei;

  String get latestReportTime => latestRecord.alarmTime;

  int get reportCount {
    final total = records.fold<int>(
      0,
      (sum, record) => sum + record.eventCount,
    );
    return total > 0 ? total : records.length;
  }
}

class AlarmTypeStyle {
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const AlarmTypeStyle({
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });
}

class EventReportItem {
  final String attrName;
  final String attrValue;

  const EventReportItem({required this.attrName, required this.attrValue});
}

class _EventReportGroupDetailScreen extends StatefulWidget {
  final EventReportGroup group;

  const _EventReportGroupDetailScreen({required this.group});

  @override
  State<_EventReportGroupDetailScreen> createState() =>
      _EventReportGroupDetailScreenState();
}

class _EventReportGroupDetailScreenState
    extends State<_EventReportGroupDetailScreen> {
  final Map<int, List<EventReportItem>> _itemsByEventId = {};
  final Map<int, String> _errorsByEventId = {};
  final Set<int> _loadingEventIds = {};
  final Set<int> _requestedEventIds = {};
  String? _expandedRecordKey;

  String get _pageTitle {
    final eventName = widget.group.eventName.trim();
    final title = eventName.isEmpty ? '事件上报' : eventName;
    return title.endsWith('详情') ? title : '$title详情';
  }

  @override
  void initState() {
    super.initState();
    if (widget.group.records.isEmpty) {
      return;
    }

    final firstRecord = widget.group.records.first;
    _expandedRecordKey = _recordKey(firstRecord);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadEventItems(firstRecord);
      }
    });
  }

  String _recordKey(AlarmRecord record) {
    return record.eventId?.toString() ?? 'record-${record.id}';
  }

  Future<void> _loadEventItems(AlarmRecord record) async {
    final eventId = record.eventId;
    if (eventId == null ||
        _itemsByEventId.containsKey(eventId) ||
        _loadingEventIds.contains(eventId) ||
        _requestedEventIds.contains(eventId)) {
      return;
    }

    setState(() {
      _requestedEventIds.add(eventId);
      _loadingEventIds.add(eventId);
      _errorsByEventId.remove(eventId);
    });

    try {
      final data = await iotPostJson(
        context,
        '/api/iot/devices/event/infos',
        body: {'eventId': eventId},
        operation: 'load IoT event detail',
      );

      if (!mounted) {
        return;
      }

      final responseData = data['message']?['data'];
      final detailData = _asDetailData(responseData);
      final rawItems = detailData?['items'] as List<dynamic>? ?? [];
      final items = rawItems.whereType<Map>().map((item) {
        return EventReportItem(
          attrName: item['attr_name']?.toString() ?? '',
          attrValue: item['attr_value']?.toString() ?? '',
        );
      }).toList();

      setState(() {
        _itemsByEventId[eventId] = items;
        _loadingEventIds.remove(eventId);
      });
    } on IotApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorsByEventId[eventId] = e.message;
        _loadingEventIds.remove(eventId);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorsByEventId[eventId] = '明细加载失败';
        _loadingEventIds.remove(eventId);
      });
    }
  }

  Map<String, dynamic>? _asDetailData(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData;
    }
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    if (responseData is List && responseData.isNotEmpty) {
      final first = responseData.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
          _pageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF2F266F),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 34),
        children: widget.group.records.map(_buildReportTimePanel).toList(),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0ECF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F266F).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.group.eventName,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2F266F),
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(Icons.place, widget.group.installLocation),
          const SizedBox(height: 8),
          _buildSummaryRow(
            Icons.access_time,
            '最新上报 ${widget.group.latestReportTime}',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            Icons.receipt_long,
            '上报次数 ${widget.group.reportCount}次',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF9891B8)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B6490),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportTimePanel(AlarmRecord record) {
    final eventId = record.eventId;
    final isLoading = eventId != null && _loadingEventIds.contains(eventId);
    final error = eventId == null ? '缺少事件ID' : _errorsByEventId[eventId];
    final items = eventId == null ? null : _itemsByEventId[eventId];
    final recordKey = _recordKey(record);
    final isExpanded = _expandedRecordKey == recordKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0ECF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F266F).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() => _expandedRecordKey = recordKey);
              _loadEventItems(record);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      record.alarmTime,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2F266F),
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF9891B8),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildReportTimeContent(
                isLoading: isLoading,
                error: error,
                items: items,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportTimeContent({
    required bool isLoading,
    required String? error,
    required List<EventReportItem>? items,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return _buildInlineMessage(error);
    }

    if (items == null) {
      return _buildInlineMessage('点击展开查看本次上报内容');
    }

    if (items.isEmpty) {
      return _buildInlineMessage('暂无本次上报内容');
    }

    return _buildItemsTable(items);
  }

  Widget _buildInlineMessage(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF9891B8)),
        ),
      ),
    );
  }

  Widget _buildItemsTable(List<EventReportItem> items) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.35)},
        border: TableBorder.all(color: const Color(0xFFEDE8FF), width: 1),
        children: [
          _buildTableRow('属性名称', '属性值', isHeader: true),
          ...items.map((item) {
            return _buildTableRow(
              item.attrName.isEmpty ? '--' : item.attrName,
              item.attrValue.isEmpty ? '--' : item.attrValue,
            );
          }),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String name, String value, {bool isHeader = false}) {
    final background = isHeader ? const Color(0xFFF8F6FF) : Colors.white;
    final textStyle = TextStyle(
      fontSize: isHeader ? 12 : 13,
      color: isHeader ? const Color(0xFF6B6490) : const Color(0xFF2F266F),
      fontWeight: isHeader ? FontWeight.w800 : FontWeight.w600,
      height: 1.45,
    );

    return TableRow(
      decoration: BoxDecoration(color: background),
      children: [
        _buildTableCell(name, textStyle),
        _buildTableCell(value, textStyle),
      ],
    );
  }

  Widget _buildTableCell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(text, style: style),
    );
  }
}

// ============================================
// Detail Bottom Sheet
// ============================================
class _AlarmDetailSheet extends StatelessWidget {
  final AlarmRecord record;
  final bool isEventReportMode;

  const _AlarmDetailSheet({
    required this.record,
    required this.isEventReportMode,
  });

  @override
  Widget build(BuildContext context) {
    final typeStyle =
        _AlarmRecordScreenState._alarmTypeStyles[record.type] ??
        _AlarmRecordScreenState._alarmTypeStyles['其他']!;
    final infoSectionTitle = isEventReportMode ? '事件信息' : '报警信息';
    final infoRows = isEventReportMode
        ? [
            _DetailRow('事件内容', record.alarmReason),
            _DetailRow('上报时间', record.alarmTime, mono: true),
            _DetailRow(
              '设备状态',
              record.deviceStatus,
              statusColor: record.deviceStatus == '正常'
                  ? const Color(0xFF22A06B)
                  : const Color(0xFFE8453A),
            ),
          ]
        : [
            _DetailRow('接警人员', record.receiver),
            _DetailRow('报警原因', record.alarmReason),
            _DetailRow(
              '报警等级',
              _AlarmRecordScreenState._levelLabels[record.alarmLevel] ??
                  '${record.alarmLevel}级',
            ),
            _DetailRow('事件等级', '${record.eventLevel}级'),
            _DetailRow('确认时间', record.confirmTime, mono: true),
            _DetailRow('确认人', record.confirmPerson),
          ];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F5FD),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E3F5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF0EAFF), Color(0xFFF8F5FD)],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: typeStyle.bgColor,
                              border: Border.all(
                                color: typeStyle.borderColor,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              record.type,
                              style: TextStyle(
                                color: typeStyle.color,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Time
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Color(0xFF9891B8),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                record.alarmTime,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9891B8),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFE7E3F5),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF6B6490),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 34),
                  children: [
                    // 位置信息
                    _buildSection(context, '位置信息', [
                      _DetailRow('安装位置', record.installLocation),
                      _DetailRow('详细地址', record.address),
                    ]),
                    const SizedBox(height: 16),

                    // 报警/事件信息
                    _buildSection(context, infoSectionTitle, infoRows),
                    const SizedBox(height: 16),

                    // 设备信息
                    _buildSection(context, '设备信息', [
                      _DetailRow('IMEI', record.imei, mono: true),
                      _DetailRow('设备类型', record.deviceType),
                      _DetailRow(
                        '设备状态',
                        record.deviceStatus,
                        statusColor: record.deviceStatus == '在线'
                            ? const Color(0xFF22A06B)
                            : const Color(0xFFE8453A),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // 备注
                    _buildSection(context, '备注', [
                      _DetailRow(
                        '备注',
                        record.remark.isEmpty ? '无' : record.remark,
                      ),
                    ]),
                    if (!isEventReportMode) ...[
                      const SizedBox(height: 16),
                      // 最近报警
                      _buildRecentAlarmSection(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<_DetailRow> rows,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title with left bar
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF5B57F7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2F266F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        // Info card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0ECF8), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F266F).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: rows.asMap().entries.map((entry) {
              final isLast = entry.key == rows.length - 1;
              return _buildInfoRow(entry.value, showBorder: !isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(_DetailRow row, {bool showBorder = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(
                bottom: BorderSide(color: Color(0xFFF0ECF8), width: 1),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              row.label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9891B8),
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              style: TextStyle(
                fontSize: 14,
                color: row.statusColor ?? const Color(0xFF2F266F),
                fontWeight: FontWeight.w600,
                fontFamily: row.mono ? 'monospace' : null,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlarmSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF5B57F7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '最近报警',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2F266F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (record.recentAlarm != null)
          _buildRecentAlarmCard()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0ECF8), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2F266F).withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '暂无历史记录',
                style: TextStyle(fontSize: 13, color: Color(0xFF9891B8)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentAlarmCard() {
    final recent = record.recentAlarm!;
    final typeStyle =
        _AlarmRecordScreenState._alarmTypeStyles[recent.type] ??
        _AlarmRecordScreenState._alarmTypeStyles['其他']!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0ECF8), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F266F).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                recent.type,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: typeStyle.color,
                ),
              ),
              Text(
                recent.time,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9891B8),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            recent.reason,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B6490),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;
  final bool mono;
  final Color? statusColor;

  _DetailRow(this.label, this.value, {this.mono = false, this.statusColor});
}
