import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'iot_api_client.dart';

const _healthPageBackgroundColor = Color(0xFFF2F6F8);
const _healthCardBackgroundColor = Colors.white;
const _healthCardBorderColor = Color(0xFFEFF3F6);
const _healthCardGap = 10.0;
const _healthMetricIconSize = 45.0;
const _healthMetricIconAlpha = 0.28;

// ============================================
// Mock Data Models
// ============================================
class DeviceData {
  final int id;
  final String type;
  final String address;
  final String status; // 在线/离线/故障
  final String model;
  final String imei;
  final String manufacturer;
  final String installDate;
  final String lastCheck;
  final String firmwareVersion;
  final String latestTime;
  final Map<String, dynamic>? health;
  final String healthTime;
  final Map<String, dynamic> info;
  final Map<String, dynamic> params;

  DeviceData({
    required this.id,
    required this.type,
    required this.address,
    required this.status,
    required this.model,
    required this.imei,
    required this.manufacturer,
    required this.installDate,
    required this.lastCheck,
    required this.firmwareVersion,
    required this.latestTime,
    this.health,
    required this.healthTime,
    required this.info,
    required this.params,
  });

  bool get isWearable => type == '智能手表' || type == '智能手环';
  bool get isRadar => type == '跌倒雷达' || type == '睡眠雷达';
}

class HealthMetric {
  final String name;
  final String value;
  final String unit;
  final Color color;
  final IconData? iconData;
  final bool showRange;
  final bool wide;
  final double? low;
  final double? safeLow;
  final double? safeHigh;
  final double? high;

  HealthMetric({
    required this.name,
    required this.value,
    required this.unit,
    required this.color,
    this.iconData,
    this.showRange = false,
    this.wide = false,
    this.low,
    this.safeLow,
    this.safeHigh,
    this.high,
  });
}

// ============================================
// Device List Screen (title: 健康监测)
// ============================================
class HealthMonitoringScreen extends StatefulWidget {
  const HealthMonitoringScreen({super.key});

  @override
  State<HealthMonitoringScreen> createState() => _HealthMonitoringScreenState();
}

class _HealthMonitoringScreenState extends State<HealthMonitoringScreen> {
  List<DeviceData> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      var userId = authProvider.currentUser?.id;
      if (userId == null) {
        await authProvider.refreshCurrentUser();
        if (!mounted) {
          return;
        }
        userId = authProvider.currentUser?.id;
      }

      if (userId == null) {
        setState(() {
          _devices = [];
          _isLoading = false;
        });
        return;
      }

      final data = await iotPostJson(
        context,
        '/api/iot/device/report',
        body: {'userId': userId},
        operation: 'load health monitoring devices',
      );

      if (!mounted) {
        return;
      }

      if (data['success'] == true && data['message'] != null) {
        final List<dynamic> deviceList = data['message']['data'] ?? [];
        setState(() {
          final parsedDevices = deviceList
              .map((item) => _parseDeviceData(item))
              .toList();
          _devices = _sortDevicesByDisplayOrder(parsedDevices);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } on IotApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFE88D0C),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  DeviceData _parseDeviceData(Map<String, dynamic> item) {
    final deviceId = item['deviceId'] ?? 0;
    final rawDeviceType = item['deviceType']?.toString() ?? '';
    final deviceImei = item['deviceImei'] ?? '';
    final deviceVersion = item['deviceVersion']?.toString() ?? '';
    final deviceType = _normalizeDeviceTypeByModel(
      rawDeviceType,
      deviceVersion,
    );
    final state = item['state'] ?? '';
    final roomName = item['roomName'] ?? '';
    final reportDate = item['reportDate'] ?? '';

    // 解析健康指标
    Map<String, dynamic>? health;
    String healthTime = '';
    final sleepRadarMetricPriorities = <String, int>{};

    if (item['items'] != null) {
      health = {};
      final items = item['items'] as List<dynamic>;
      for (var i in items) {
        final itemName = i['itemName']?.toString() ?? '';
        final itemValue = i['itemValue']?.toString() ?? '';
        final reportTime = i['reportDate']?.toString() ?? '';

        if (deviceType == '睡眠雷达') {
          _applySleepRadarMetric(
            health,
            sleepRadarMetricPriorities,
            itemName,
            itemValue,
          );
        }

        if (itemName == '心率') {
          health['heartRate'] = {'value': itemValue, 'unit': 'bpm'};
        } else if (itemName == '体温' || itemName == '温度') {
          // 从itemValue中提取温度数值
          String tempValue = itemValue;
          final match = RegExp(r'(\d+\.?\d*)').firstMatch(itemValue);
          if (match != null) {
            tempValue = match.group(1) ?? itemValue;
          }
          health['temperature'] = {
            'value': tempValue,
            'unit': '°C',
            'low': 35.0,
            'safeLow': 36.0,
            'safeHigh': 37.5,
            'high': 42.0,
          };
        } else if (itemName == '血压') {
          // 血压格式为 "120/80"
          health['bloodPressure'] = {'value': itemValue, 'unit': 'mmHg'};
        } else if (itemName == '收缩压') {
          health['systolic'] = itemValue;
        } else if (itemName == '舒张压') {
          health['diastolic'] = itemValue;
        } else if (itemName == '血氧') {
          health['spo2'] = {
            'value': itemValue,
            'unit': '%',
            'low': 80.0,
            'safeLow': 90.0,
            'safeHigh': 95.0,
            'high': 100.0,
          };
        } else if (itemName == '计步') {
          health['steps'] = {'value': itemValue, 'unit': '步'};
        }

        if (reportTime.isNotEmpty) {
          healthTime = reportTime;
        }
      }
    }

    // 雷达设备的报警次数和事件上报次数
    if (item['alarmCount'] != null) {
      health ??= {};
      health['alarmCount'] = item['alarmCount'].toString();
      health['eventCount'] =
          (item['eventCount'] ?? item['eventReportCount'] ?? 0).toString();

      final radarItems = item['radarItems'];
      if (radarItems is List) {
        for (final radarItem in radarItems) {
          if (radarItem is! Map) {
            continue;
          }
          final itemName = radarItem['itemName']?.toString() ?? '';
          final itemValue = radarItem['itemValue']?.toString() ?? '';
          final reportTime = radarItem['reportDate']?.toString() ?? '';

          _applySleepRadarMetric(
            health,
            sleepRadarMetricPriorities,
            itemName,
            itemValue,
          );

          if (reportTime.isNotEmpty) {
            healthTime = reportTime;
          }
        }
      }
    }

    // 确保 health 不为 null
    health ??= {};

    // 格式化健康时间
    if (healthTime.isNotEmpty) {
      final parts = healthTime.split(' ');
      if (parts.length >= 2) {
        final dateParts = parts[0].split('-');
        if (dateParts.length >= 3) {
          healthTime = '${int.parse(dateParts[1])}/${int.parse(dateParts[2])}';
        }
      }
    }

    // 格式化最新时间
    String latestTime = '';
    if (reportDate.isNotEmpty) {
      latestTime = reportDate;
    }

    // 状态：直接显示接口返回的state值
    final status = state.isNotEmpty ? state : '离线';

    return DeviceData(
      id: deviceId is int ? deviceId : int.tryParse(deviceId.toString()) ?? 0,
      type: deviceType,
      address: roomName,
      status: status,
      model: deviceVersion,
      imei: deviceImei,
      manufacturer: '',
      installDate: '',
      lastCheck: '',
      firmwareVersion: '',
      latestTime: latestTime,
      health: health,
      healthTime: healthTime,
      info: {},
      params: {},
    );
  }

  void _applySleepRadarMetric(
    Map<String, dynamic> health,
    Map<String, int> priorities,
    String itemName,
    String itemValue,
  ) {
    final name = itemName.replaceAll(RegExp(r'\s+'), '');
    if (name.isEmpty) {
      return;
    }

    final value = itemValue.isNotEmpty ? itemValue : '--';

    if (name.contains('心率')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarHeartRate',
        value,
        'bpm',
        3,
      );
    } else if (name.contains('心跳')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarHeartRate',
        value,
        'bpm',
        2,
      );
    }

    if (name.contains('呼吸次数') || name.contains('呼吸率')) {
      _setSleepRadarMetric(health, priorities, 'radarBreath', value, '次/分', 3);
    } else if (name.contains('呼吸')) {
      _setSleepRadarMetric(health, priorities, 'radarBreath', value, '次/分', 2);
    }

    if (name.contains('睡眠状态') || name.contains('睡眠综合状态')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarSleepStatus',
        value,
        '',
        4,
      );
    } else if (name.contains('睡眠评级') || name.contains('睡眠评分')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarSleepStatus',
        value,
        '',
        2,
      );
    }

    if (name.contains('离床状态')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarOutOfBedStatus',
        value,
        '',
        4,
      );
    } else if (name.contains('离床')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarOutOfBedStatus',
        value,
        '',
        2,
      );
    }

    if (name.contains('运动状态')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarMotionStatus',
        value,
        '',
        4,
      );
    } else if (name.contains('运动')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarMotionStatus',
        value,
        '',
        2,
      );
    }

    if (name.contains('存在状态')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarPresenceStatus',
        value,
        '',
        4,
      );
    } else if (name.contains('存在')) {
      _setSleepRadarMetric(
        health,
        priorities,
        'radarPresenceStatus',
        value,
        '',
        2,
      );
    }

    if (name.contains('体动')) {
      _setSleepRadarMetric(health, priorities, 'radarBodyMotion', value, '', 4);
    } else if (name.contains('翻身')) {
      _setSleepRadarMetric(health, priorities, 'radarBodyMotion', value, '', 2);
    }
  }

  void _setSleepRadarMetric(
    Map<String, dynamic> health,
    Map<String, int> priorities,
    String key,
    String value,
    String unit,
    int priority,
  ) {
    final currentPriority = priorities[key] ?? -1;
    if (priority < currentPriority) {
      return;
    }
    priorities[key] = priority;
    health[key] = {'value': value, 'unit': unit};
  }

  List<DeviceData> _sortDevicesByDisplayOrder(List<DeviceData> devices) {
    final indexedDevices = devices.asMap().entries.toList();
    indexedDevices.sort((left, right) {
      final rankCompare = _deviceDisplayRank(
        left.value,
      ).compareTo(_deviceDisplayRank(right.value));
      if (rankCompare != 0) return rankCompare;
      return left.key.compareTo(right.key);
    });
    return indexedDevices.map((entry) => entry.value).toList();
  }

  int _deviceDisplayRank(DeviceData device) {
    final type = device.type;
    final model = _normalizeDeviceModel(device.model);

    if (model.contains('GK8')) return 0;
    if (model.contains('GS17')) return 1;
    if (model.contains('RTC03')) return 3;
    if (model.contains('SMC03')) return 2;
    if (type.contains('智能手表')) return 10;
    if (type.contains('智能手环')) return 11;
    if (type.contains('睡眠雷达')) return 12;
    if (type.contains('跌倒雷达')) return 13;
    return 99;
  }

  String _normalizeDeviceTypeByModel(String deviceType, String deviceVersion) {
    final model = _normalizeDeviceModel(deviceVersion);
    if (model.contains('GK8')) return '智能手表';
    if (model.contains('GS17')) return '智能手环';
    if (model.contains('RTC03')) return '跌倒雷达';
    if (model.contains('SMC03')) return '睡眠雷达';
    return deviceType;
  }

  String _normalizeDeviceModel(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _healthPageBackgroundColor,
      appBar: AppBar(
        backgroundColor: _healthPageBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2F266F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '健康监测',
          style: TextStyle(
            color: Color(0xFF2F266F),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () async {
                final result = await context.push(
                  '/health-monitoring/add-device',
                );
                if (result == true) {
                  _loadDevices();
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF5B57F7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? const Center(
              child: Text(
                '暂无设备数据',
                style: TextStyle(fontSize: 14, color: Color(0xFF9891B8)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 50),
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                return _DeviceCard(
                  device: _devices[index],
                  animationDelay: (index + 1) * 40,
                );
              },
            ),
    );
  }
}

// ============================================
// Device Card Widget
// ============================================
class _DeviceCard extends StatelessWidget {
  final DeviceData device;
  final int animationDelay;

  const _DeviceCard({required this.device, required this.animationDelay});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push('/health-monitoring/device-detail', extra: device),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: _healthCardBackgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _healthCardBorderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: type + status + settings
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        device.type,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2F266F),
                        ),
                      ),
                      if (device.model.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          device.model,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9891B8),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _StatusBadge(
                        status: device.status,
                        deviceImei: device.imei,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push(
                    '/health-monitoring/device-detail',
                    extra: device,
                  ),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FB),
                      border: Border.all(
                        color: _healthCardBorderColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.settings,
                      size: 16,
                      color: Color(0xFF9891B8),
                    ),
                  ),
                ),
              ],
            ),

            // Health metrics for wearable devices
            if (device.isWearable && device.health != null) ...[
              const SizedBox(height: _healthCardGap),
              _HealthMetricsGrid(device: device),
            ],

            // Alarm count for radar devices
            if (device.isRadar && device.health != null) ...[
              const SizedBox(height: _healthCardGap),
              _RadarAlarmCount(
                health: device.health!,
                deviceId: device.id,
                deviceImei: device.imei,
                healthTime: device.healthTime,
                showEventReport: device.type != '跌倒雷达',
                showSleepRadarMetrics: device.type == '睡眠雷达',
              ),
            ],

            // Footer: latest time + address
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: _healthCardBorderColor, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '最新 ${device.latestTime}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9891B8),
                    ),
                  ),
                  Text(
                    device.address,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9891B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Status Badge
// ============================================
class _StatusBadge extends StatelessWidget {
  final String status;
  final String deviceImei;

  const _StatusBadge({required this.status, required this.deviceImei});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Color dotColor;

    switch (status) {
      case '正常':
        bgColor = const Color(0xFFE6F7EF);
        textColor = const Color(0xFF22A06B);
        dotColor = const Color(0xFF22A06B);
        break;
      case '故障':
        bgColor = const Color(0xFFFFF4E0);
        textColor = const Color(0xFFE88D0C);
        dotColor = const Color(0xFFE88D0C);
        break;
      case '报警':
        bgColor = const Color(0xFFFDECEA);
        textColor = const Color(0xFFE8453A);
        dotColor = const Color(0xFFE8453A);
        break;
      case '隐患':
        bgColor = const Color(0xFFFFF0F5);
        textColor = const Color(0xFFFF69B4);
        dotColor = const Color(0xFFFF69B4);
        break;
      case '离线':
      default:
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF999999);
        dotColor = const Color(0xFF999999);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.push('/alarm-record', extra: deviceImei);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Health Metrics Grid (for wearable devices)
// ============================================
class _HealthMetricsGrid extends StatelessWidget {
  final DeviceData device;

  const _HealthMetricsGrid({required this.device});

  @override
  Widget build(BuildContext context) {
    final health = device.health!;

    // 血压：合并收缩压和舒张压
    String bpValue = '--';
    if (health['bloodPressure'] != null) {
      bpValue = health['bloodPressure']['value'] ?? '--';
    } else if (health['systolic'] != null && health['diastolic'] != null) {
      bpValue = '${health['systolic']}/${health['diastolic']}';
    }

    final metrics = <HealthMetric>[
      _buildMetric(
        '心率',
        health['heartRate'],
        const Color(0xFFEF4444),
        iconData: Icons.favorite,
      ),
      _buildMetric(
        '体温',
        health['temperature'],
        const Color(0xFFF59E0B),
        iconData: Icons.thermostat,
        showRange: true,
      ),
      HealthMetric(
        name: '血压',
        value: bpValue,
        unit: 'mmHg',
        color: const Color(0xFF3B82F6),
        iconData: Icons.speed,
      ),
      _buildMetric(
        '血氧饱和度',
        health['spo2'],
        const Color(0xFF10B981),
        iconData: Icons.opacity,
        showRange: true,
      ),
    ];

    return Column(
      children: [
        // Row 1: 心率 + 体温
        Row(
          children: [
            Expanded(
              child: _HealthMetricCard(
                metric: metrics[0],
                deviceId: device.id,
                deviceImei: device.imei,
                healthTime: device.healthTime,
                deviceType: device.type,
              ),
            ),
            const SizedBox(width: _healthCardGap),
            Expanded(
              child: _HealthMetricCard(
                metric: metrics[1],
                deviceId: device.id,
                deviceImei: device.imei,
                healthTime: device.healthTime,
                deviceType: device.type,
              ),
            ),
          ],
        ),
        const SizedBox(height: _healthCardGap),
        // Row 2: 血压 + 血氧饱和度
        Row(
          children: [
            Expanded(
              child: _HealthMetricCard(
                metric: metrics[2],
                deviceId: device.id,
                deviceImei: device.imei,
                healthTime: device.healthTime,
                deviceType: device.type,
              ),
            ),
            const SizedBox(width: _healthCardGap),
            Expanded(
              child: _HealthMetricCard(
                metric: metrics[3],
                deviceId: device.id,
                deviceImei: device.imei,
                healthTime: device.healthTime,
                deviceType: device.type,
              ),
            ),
          ],
        ),
        const SizedBox(height: _healthCardGap),
        // Wide steps card (始终显示给可穿戴设备)
        if (device.isWearable)
          _HealthMetricCard(
            metric: _buildMetric(
              '步数',
              health['steps'],
              const Color(0xFF8B5CF6),
              iconData: Icons.directions_walk,
            ),
            deviceId: device.id,
            deviceImei: device.imei,
            healthTime: device.healthTime,
            deviceType: device.type,
            wide: true,
          ),
      ],
    );
  }

  HealthMetric _buildMetric(
    String name,
    Map<String, dynamic>? data,
    Color color, {
    IconData? iconData,
    bool showRange = false,
  }) {
    return HealthMetric(
      name: name,
      value: data?['value'] ?? '--',
      unit: data?['unit'] ?? '',
      color: color,
      iconData: iconData,
      showRange: showRange,
      low: (data?['low'] as num?)?.toDouble(),
      safeLow: (data?['safeLow'] as num?)?.toDouble(),
      safeHigh: (data?['safeHigh'] as num?)?.toDouble(),
      high: (data?['high'] as num?)?.toDouble(),
    );
  }
}

// ============================================
// Health Metric Card
// ============================================
class _HealthMetricCard extends StatelessWidget {
  final HealthMetric metric;
  final int deviceId;
  final String deviceImei;
  final String healthTime;
  final String? deviceType;
  final bool wide;

  const _HealthMetricCard({
    required this.metric,
    required this.deviceId,
    required this.deviceImei,
    required this.healthTime,
    this.deviceType,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
      decoration: BoxDecoration(
        color: _healthCardBackgroundColor,
        border: Border.all(color: _healthCardBorderColor, width: 1),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (metric.iconData != null)
            Positioned(
              left: 0,
              top: 0,
              child: Icon(
                metric.iconData,
                size: _healthMetricIconSize,
                color: metric.color.withValues(alpha: _healthMetricIconAlpha),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    metric.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B6490),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: (metric.name == '心率' || metric.name == '血压') ? 13 : 2,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric.value,
                    style: TextStyle(
                      fontSize: (metric.name == '心率' || metric.name == '血压')
                          ? 20
                          : 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2F266F),
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    metric.unit,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9891B8),
                    ),
                  ),
                ],
              ),
              if (metric.showRange &&
                  metric.high != null &&
                  metric.low != null) ...[
                const SizedBox(height: 4),
                _RangeBar(
                  value: double.tryParse(metric.value) ?? 0,
                  low: metric.low!,
                  safeLow: metric.safeLow ?? metric.low!,
                  safeHigh: metric.safeHigh ?? metric.high!,
                  high: metric.high!,
                  leftRatio: metric.name == '体温' ? 0.3 : 0.2,
                  midRatio: metric.name == '体温' ? 0.4 : 0.5,
                  rightRatio: metric.name == '体温' ? 0.3 : 0.3,
                  leftColor: metric.name == '体温'
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444),
                  midColor: metric.name == '体温'
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFF59E0B),
                  rightColor: metric.name == '体温'
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF22C55E),
                ),
                const SizedBox(height: 12),
              ],
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  healthTime,
                  style: const TextStyle(fontSize: 9, color: Color(0xFFB8B0D0)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        context.push(
          '/health-monitoring/metric-detail',
          extra: {
            'deviceId': deviceId,
            'deviceImei': deviceImei,
            'metricName': metric.name,
            'metricColor': metric.color,
            'deviceType': deviceType,
          },
        );
      },
      child: wide
          ? SizedBox(width: double.infinity, height: 72, child: content)
          : SizedBox(height: 110, child: content),
    );
  }
}

// ============================================
// Sleep Radar Metrics Grid
// ============================================
HealthMetric _buildSleepRadarMetric(
  String name,
  Map<String, dynamic>? data,
  Color color,
  IconData iconData,
) {
  return HealthMetric(
    name: name,
    value: data?['value'] ?? '--',
    unit: data?['unit'] ?? '',
    color: color,
    iconData: iconData,
  );
}

class _SleepRadarMetricsGrid extends StatelessWidget {
  final Map<String, dynamic> health;
  final String healthTime;
  final int deviceId;
  final String deviceImei;

  const _SleepRadarMetricsGrid({
    required this.health,
    required this.healthTime,
    required this.deviceId,
    required this.deviceImei,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = <HealthMetric>[
      _buildSleepRadarMetric(
        '心率',
        health['radarHeartRate'],
        const Color(0xFFEF4444),
        Icons.favorite,
      ),
      _buildSleepRadarMetric(
        '呼吸',
        health['radarBreath'],
        const Color(0xFF0EA5E9),
        Icons.air,
      ),
      _buildSleepRadarMetric(
        '睡眠状态',
        health['radarSleepStatus'],
        const Color(0xFF8B5CF6),
        Icons.bedtime,
      ),
      _buildSleepRadarMetric(
        '离床状态',
        health['radarOutOfBedStatus'],
        const Color(0xFFF59E0B),
        Icons.hotel,
      ),
      _buildSleepRadarMetric(
        '运动状态',
        health['radarMotionStatus'],
        const Color(0xFF10B981),
        Icons.directions_walk,
      ),
      _buildSleepRadarMetric(
        '存在状态',
        health['radarPresenceStatus'],
        const Color(0xFF5B57F7),
        Icons.person,
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SleepRadarMetricCard(
                metric: metrics[0],
                deviceId: deviceId,
                deviceImei: deviceImei,
                healthTime: healthTime,
              ),
            ),
            const SizedBox(width: _healthCardGap),
            Expanded(
              child: _SleepRadarMetricCard(
                metric: metrics[1],
                deviceId: deviceId,
                deviceImei: deviceImei,
                healthTime: healthTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: _healthCardGap),
        Row(
          children: [
            Expanded(
              child: _SleepRadarMetricCard(
                metric: metrics[2],
                deviceId: deviceId,
                deviceImei: deviceImei,
                healthTime: healthTime,
              ),
            ),
            const SizedBox(width: _healthCardGap),
            Expanded(
              child: _SleepRadarMetricCard(
                metric: metrics[3],
                deviceId: deviceId,
                deviceImei: deviceImei,
                healthTime: healthTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: _healthCardGap),
        Row(
          children: [
            Expanded(
              child: _SleepRadarMetricCard(
                metric: metrics[4],
                deviceId: deviceId,
                deviceImei: deviceImei,
                healthTime: healthTime,
              ),
            ),
            const SizedBox(width: _healthCardGap),
            Expanded(
              child: _SleepRadarMetricCard(
                metric: metrics[5],
                deviceId: deviceId,
                deviceImei: deviceImei,
                healthTime: healthTime,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SleepRadarMetricCard extends StatelessWidget {
  final HealthMetric metric;
  final int deviceId;
  final String deviceImei;
  final String healthTime;

  const _SleepRadarMetricCard({
    required this.metric,
    required this.deviceId,
    required this.deviceImei,
    required this.healthTime,
  });

  @override
  Widget build(BuildContext context) {
    final isNumericMetric = metric.name == '心率' || metric.name == '呼吸';
    final content = Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
      decoration: BoxDecoration(
        color: _healthCardBackgroundColor,
        border: Border.all(color: _healthCardBorderColor, width: 1),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (metric.iconData != null)
            Positioned(
              left: 0,
              top: 0,
              child: Icon(
                metric.iconData,
                size: _healthMetricIconSize,
                color: metric.color.withValues(alpha: _healthMetricIconAlpha),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    metric.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B6490),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isNumericMetric ? 13 : 8),
              SizedBox(
                height: 28,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          metric.value,
                          style: TextStyle(
                            fontSize: isNumericMetric ? 22 : 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2F266F),
                            fontFamily: isNumericMetric ? 'monospace' : null,
                          ),
                        ),
                        Text(
                          metric.unit,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9891B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  healthTime,
                  style: const TextStyle(fontSize: 9, color: Color(0xFFB8B0D0)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.push(
          '/health-monitoring/metric-detail',
          extra: {
            'deviceId': deviceId,
            'deviceImei': deviceImei,
            'metricName': metric.name,
            'metricColor': metric.color,
            'deviceType': '睡眠雷达',
          },
        );
      },
      child: SizedBox(height: 92, child: content),
    );
  }
}

// ============================================
// Range Bar (safety range indicator)
// ============================================
class _RangeBar extends StatelessWidget {
  final double value;
  final double low;
  final double safeLow;
  final double safeHigh;
  final double high;
  final double leftRatio;
  final double midRatio;
  final double rightRatio;
  final Color leftColor;
  final Color midColor;
  final Color rightColor;

  const _RangeBar({
    required this.value,
    required this.low,
    required this.safeLow,
    required this.safeHigh,
    required this.high,
    this.leftRatio = 0.2,
    this.midRatio = 0.5,
    this.rightRatio = 0.3,
    this.leftColor = const Color(0xFFEF4444),
    this.midColor = const Color(0xFFF59E0B),
    this.rightColor = const Color(0xFF22C55E),
  });

  @override
  Widget build(BuildContext context) {
    final totalRange = high - low;
    final indicatorPos = totalRange > 0
        ? ((value - low) / totalRange).clamp(0.0, 1.0)
        : 0.5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = 2.0;
        final totalGap = gap * 2;
        final barWidth = width - totalGap;
        const barHeight = 10.0;
        const barRadius = 5.0;
        const shadowBlur = 16.0;
        const shadowOffset = Offset(0, 8);

        Widget buildSegment({
          required double width,
          required Color color,
          BorderRadiusGeometry? borderRadius,
        }) {
          return Container(
            width: width,
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: shadowBlur,
                  offset: shadowOffset,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicator triangle above the bar
            Padding(
              padding: EdgeInsets.only(left: (width * indicatorPos) - 6),
              child: CustomPaint(
                size: const Size(12, 8),
                painter: _TrianglePainter(),
              ),
            ),
            const SizedBox(height: 2),
            // Three-segment bar with configurable ratios and colors
            SizedBox(
              height: barHeight,
              child: Row(
                children: [
                  // Left segment
                  buildSegment(
                    width: barWidth * leftRatio,
                    color: leftColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(barRadius),
                    ),
                  ),
                  SizedBox(width: gap),
                  // Middle segment
                  buildSegment(width: barWidth * midRatio, color: midColor),
                  SizedBox(width: gap),
                  // Right segment
                  buildSegment(
                    width: barWidth * rightRatio,
                    color: rightColor,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(barRadius),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x99646478)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================
// Radar Alarm Count
// ============================================
class _RadarAlarmCount extends StatelessWidget {
  final Map<String, dynamic> health;
  final int deviceId;
  final String deviceImei;
  final String healthTime;
  final bool showEventReport;
  final bool showSleepRadarMetrics;

  const _RadarAlarmCount({
    required this.health,
    required this.deviceId,
    required this.deviceImei,
    required this.healthTime,
    required this.showEventReport,
    required this.showSleepRadarMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final alarmCount =
        int.tryParse(health['alarmCount']?.toString() ?? '0') ?? 0;
    final eventCount =
        int.tryParse(
          (health['eventCount'] ?? health['eventReportCount'])?.toString() ??
              '0',
        ) ??
        0;
    final alarmColor = alarmCount > 0
        ? const Color(0xFFE88D0C)
        : const Color(0xFF22A06B);
    const areaGap = _healthCardGap;

    final alarmSection = _RadarSection(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/alarm-record', extra: deviceImei),
        child: _RadarStatRow(
          label: '报警次数',
          value: '$alarmCount 次',
          valueColor: alarmColor,
        ),
      ),
    );
    final eventSection = _RadarSection(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(
          '/alarm-record',
          extra: {'deviceImei': deviceImei, 'recordType': 'eventReport'},
        ),
        child: _RadarStatRow(
          label: '事件上报',
          value: '$eventCount 次',
          valueColor: const Color(0xFF5B57F7),
        ),
      ),
    );

    if (showSleepRadarMetrics && showEventReport) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    alarmSection,
                    const SizedBox(height: areaGap),
                    eventSection,
                  ],
                ),
              ),
              const SizedBox(width: _healthCardGap),
              Expanded(
                child: _SleepRadarMetricCard(
                  metric: _buildSleepRadarMetric(
                    '体动',
                    health['radarBodyMotion'],
                    const Color(0xFFEC4899),
                    Icons.accessibility,
                  ),
                  deviceId: deviceId,
                  deviceImei: deviceImei,
                  healthTime: healthTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: areaGap),
          _SleepRadarMetricsGrid(
            health: health,
            healthTime: healthTime,
            deviceId: deviceId,
            deviceImei: deviceImei,
          ),
        ],
      );
    }

    return Column(
      children: [
        alarmSection,
        if (showEventReport) ...[const SizedBox(height: areaGap), eventSection],
      ],
    );
  }
}

class _RadarSection extends StatelessWidget {
  final Widget child;

  const _RadarSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _healthCardBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _healthCardBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RadarStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _RadarStatRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF9891B8)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
